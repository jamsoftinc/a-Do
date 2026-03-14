import Foundation
import SwiftData
import os
import Observation
import CoreLocation
import SwiftUI
import AVFoundation

struct QuickCaptureDraft: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var details: String
    var dueDate: Date?
    var priority: Priority
}

@MainActor
@Observable
final class ReminderHomeViewModel {
    var quickTitle: String = ""
    var quickDueDate: Date?
    var showingQuickDatePicker: Bool = false
    var isPreparingQuickCapture: Bool = false
    var showingQuickCaptureReview: Bool = false
    var pendingQuickCaptureDrafts: [QuickCaptureDraft] = []
    var showQuickCaptureUndo: Bool = false
    var lastQuickCaptureCreatedCount: Int = 0
    @ObservationIgnored
    private var lastCreatedReminderIDs: [PersistentIdentifier] = []
    @ObservationIgnored
    private var undoDismissTask: Task<Void, Never>?

    deinit {
        undoDismissTask?.cancel()
    }

    func addQuickReminder(context: ModelContext) {
        let safeTitle = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeTitle.isEmpty else { return }
        guard !isPreparingQuickCapture else { return }

        Task {
            await prepareQuickCapture(from: safeTitle, context: context)
        }
    }
    
    func clearQuickDueDate() {
        quickDueDate = nil
    }
    
    func setQuickDueDateToToday() {
        quickDueDate = Calendar.current.startOfDay(for: Date())
    }
    
    func setQuickDueDateToTomorrow() {
        quickDueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
    }

    func commitQuickCapture(context: ModelContext) async {
        guard !pendingQuickCaptureDrafts.isEmpty else { return }

        let requests = pendingQuickCaptureDrafts.map { draft in
            ReminderCreationService.Request(
                title: draft.title,
                details: draft.details.isEmpty ? nil : draft.details,
                dueDate: draft.dueDate,
                priority: draft.priority,
                useNaturalLanguageParsing: false
            )
        }

        do {
            let reminders = try await ReminderCreationService.shared.createReminders(requests: requests, in: context)
            finishQuickCapture(with: reminders)
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Quick capture commit failed: \(error.localizedDescription)")
        }
    }

    func cancelQuickCaptureReview() {
        showingQuickCaptureReview = false
        pendingQuickCaptureDrafts = []
    }

    func undoLastQuickCapture(context: ModelContext) {
        guard !lastCreatedReminderIDs.isEmpty else {
            showQuickCaptureUndo = false
            return
        }

        let deletedReminders = lastCreatedReminderIDs.compactMap { identifier in
            context.model(for: identifier) as? Reminder
        }

        for reminder in deletedReminders {
            NotificationManager.shared.cancelNotifications(for: reminder)
            context.delete(reminder)
        }

        do {
            try context.save()
            Task {
                for reminder in deletedReminders {
                    await AdvancedSearchManager.shared.removeReminderIndex(for: reminder, context: context)
                }
            }
            WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Undo quick capture failed: \(String(describing: error))")
        }

        undoDismissTask?.cancel()
        showQuickCaptureUndo = false
        lastQuickCaptureCreatedCount = 0
        lastCreatedReminderIDs = []
    }
    
    // MARK: - Reminder Completion
    
    func markReminderComplete(_ reminder: Reminder, context: ModelContext) {
        reminder.isCompleted = true
        reminder.completedAt = Date()

        NotificationManager.shared.cancelNotifications(for: reminder)
        
        // Stop location monitoring if this reminder has location triggers
        // if let locationTrigger = reminder.locationTrigger {
        //     LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
        // }
        
        do {
            try context.save()
            Task {
                await AdvancedSearchManager.shared.upsertReminderIndex(for: reminder, context: context)
            }
            WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
            Logger(subsystem: "a-do", category: "Reminders").info("Reminder marked complete: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to mark reminder complete: \(String(describing: error))")
        }
    }
    
    func markReminderIncomplete(_ reminder: Reminder, context: ModelContext) {
        reminder.isCompleted = false
        reminder.completedAt = nil
        
        do {
            try context.save()
            Task {
                await AdvancedSearchManager.shared.upsertReminderIndex(for: reminder, context: context)
            }
            WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
            Logger(subsystem: "a-do", category: "Reminders").info("Reminder marked incomplete: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to mark reminder incomplete: \(String(describing: error))")
        }
    }

    private func prepareQuickCapture(from input: String, context: ModelContext) async {
        isPreparingQuickCapture = true
        defer { isPreparingQuickCapture = false }

        let requests = await AIManager.shared.buildCaptureRequests(
            from: input,
            fallbackDueDate: quickDueDate
        ).map { request in
            var normalizedRequest = request
            if normalizedRequest.dueDate == nil {
                normalizedRequest.dueDate = quickDueDate
            }
            return normalizedRequest
        }

        guard !requests.isEmpty else { return }

        if shouldReviewQuickCapture(originalInput: input, requests: requests) {
            pendingQuickCaptureDrafts = requests.map {
                QuickCaptureDraft(
                    title: $0.title,
                    details: $0.details ?? "",
                    dueDate: $0.dueDate,
                    priority: $0.priority
                )
            }
            showingQuickCaptureReview = true
            return
        }

        do {
            let reminders = try await ReminderCreationService.shared.createReminders(requests: requests, in: context)
            finishQuickCapture(with: reminders)
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Quick add failed: \(error.localizedDescription)")
        }
    }

    private func shouldReviewQuickCapture(
        originalInput: String,
        requests: [ReminderCreationService.Request]
    ) -> Bool {
        guard let request = requests.first else { return false }
        if requests.count > 1 { return true }

        let normalizedOriginal = originalInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedTitle = request.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if normalizedTitle != normalizedOriginal {
            return true
        }

        if !(request.details?.isEmpty ?? true) || request.priority != .none {
            return true
        }

        switch (request.dueDate, quickDueDate) {
        case (nil, nil):
            return false
        case let (lhs?, rhs?):
            return abs(lhs.timeIntervalSince(rhs)) > 1
        default:
            return true
        }
    }

    func shouldReviewQuickCaptureForTesting(
        originalInput: String,
        requests: [ReminderCreationService.Request]
    ) -> Bool {
        shouldReviewQuickCapture(originalInput: originalInput, requests: requests)
    }

    private func finishQuickCapture(with reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }

        quickTitle = ""
        quickDueDate = nil
        pendingQuickCaptureDrafts = []
        showingQuickCaptureReview = false

        lastCreatedReminderIDs = reminders.map(\.persistentModelID)
        lastQuickCaptureCreatedCount = reminders.count
        showQuickCaptureUndo = true
        scheduleUndoDismissal()
    }

    private func scheduleUndoDismissal() {
        undoDismissTask?.cancel()
        undoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self?.showQuickCaptureUndo = false
        }
    }
}

@MainActor
@Observable
final class ReminderFormViewModel {
    var title: String = ""
    var details: String = ""
    var dueDate: Date? = nil
    var priority: Priority = .none
    var energyLevel: EnergyLevel = .medium
    var selectedTags: [Tag] = []
    var leadTimes: [TimeInterval] = []
    var locationLabel: String = ""
    var locationLatitude: Double = 0 {
        didSet {
            // Validate latitude bounds (-90 to 90)
            if locationLatitude < -90 || locationLatitude > 90 {
                locationLatitude = oldValue
            }
        }
    }
    var locationLongitude: Double = 0 {
        didSet {
            // Validate longitude bounds (-180 to 180)
            if locationLongitude < -180 || locationLongitude > 180 {
                locationLongitude = oldValue
            }
        }
    }
    var locationRadius: Double = 150
    var locationType: LocationTriggerType = .onArrival
    // Messaging settings
    var autoTextTaggedContacts: Bool = false
    var autoTextMe: Bool = false
    
    var list: ReminderList? = nil
    
    // Apple Note attachment
    var attachedNote: AppleNoteAttachment?
    var showNotePicker: Bool = false
    
    // ...
    // Voice reminder
    var voiceReminder: VoiceReminder?
    var isRecordingVoice: Bool = false
    var voiceRecordingError: String?
    
    // Calendar invite settings
    var createCalendarInvite: Bool = false
    var calendarDuration: TimeInterval = 30 * 60 // 30 minutes default
    var calendarLocation: String = ""
    var calendarAttendees: String = "" // Comma-separated email addresses
    var calendarInviteCreated: Bool = false
    var calendarInviteError: String?
    
    // Location detection
    var isDetectingLocation: Bool = false
    var locationDetectionError: String?
    
    // Computed property to check if coordinates are valid and usable
    var hasValidCoordinates: Bool {
        let isValid = self.locationLatitude >= -90 && self.locationLatitude <= 90 &&
               self.locationLongitude >= -180 && self.locationLongitude <= 180
        
        // Additional validation to ensure coordinates are initialized and practical
        if isValid {
            // Check if coordinates are not zero (which may indicate uninitialized data)
            let isNotZero = self.locationLatitude != 0 || self.locationLongitude != 0
            
            // Reject near-origin coordinates that commonly represent invalid data.
            let isNotOrigin = !(abs(self.locationLatitude) < 0.001 && abs(self.locationLongitude) < 0.001)
            
            // Check if coordinates are within reasonable bounds for real-world locations.
            let isReasonable = self.locationLatitude != 0 && self.locationLongitude != 0
            
            let isReal = isNotZero && isNotOrigin && isReasonable
            
            if !isReal {
                Logger(subsystem: "a-do", category: "Location").warning("Coordinates appear invalid: lat=\(self.locationLatitude), lon=\(self.locationLongitude)")
            }
            
            return isReal
        }
        
        return false
    }
    
    // Computed property to get attendee emails
    var attendeeEmails: [String] {
        return calendarAttendees
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @discardableResult
    func save(context: ModelContext, existing: Reminder? = nil) async throws -> Reminder {
        let request = ReminderCreationService.Request(
            title: title,
            details: details.isEmpty ? nil : details,
            dueDate: dueDate,
            priority: priority,
            energyLevel: energyLevel,
            selectedTags: selectedTags,
            leadTimes: leadTimes,
            list: list,
            locationLabel: locationLabel.isEmpty ? nil : locationLabel,
            locationLatitude: hasValidCoordinates ? locationLatitude : nil,
            locationLongitude: hasValidCoordinates ? locationLongitude : nil,
            locationRadius: locationRadius,
            locationType: locationType,
            attachedNote: attachedNote,
            voiceReminder: voiceReminder,
            autoTextTaggedContacts: autoTextTaggedContacts,
            autoTextMe: autoTextMe
        )

        if let existing {
            return try await ReminderCreationService.shared.updateReminder(existing, with: request, in: context)
        } else {
            return try await ReminderCreationService.shared.createReminder(request: request, in: context)
        }
    }
    
    // Create calendar invite from reminder
    func createCalendarInviteFromReminder(context: ModelContext) async {
        guard createCalendarInvite else { return }
        
        calendarInviteError = nil
        calendarInviteCreated = false
        
        do {
            // Request calendar access if needed
            if !CalendarManager.shared.accessGranted {
                await CalendarManager.shared.requestAccess()
            }
            
            guard CalendarManager.shared.accessGranted else {
                calendarInviteError = "Calendar access denied. Please enable calendar access in Settings."
                return
            }
            
            // Create the calendar invite
            let event = try await CalendarManager.shared.createCalendarInvite(
                title: title,
                details: details.isEmpty ? nil : details,
                dueDate: dueDate,
                duration: calendarDuration,
                location: calendarLocation.isEmpty ? nil : calendarLocation,
                attendees: attendeeEmails,
                reminder: nil, // We'll pass the actual reminder after it's saved
                context: context
            )
            
            if event != nil {
                calendarInviteCreated = true
                Logger(subsystem: "a-do", category: "Calendar").info("Calendar invite created successfully")
            } else {
                calendarInviteError = "Failed to create calendar invite"
            }
            
        } catch {
            calendarInviteError = "Error creating calendar invite: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Calendar").error("Calendar invite creation failed: \(String(describing: error))")
        }
    }
    
    // MARK: - Voice Reminder Methods
    
    func startVoiceRecording() async {
        isRecordingVoice = true
        voiceRecordingError = nil

        // Start recording - this method handles errors internally and doesn't throw
        await AudioManager.shared.startRecording()
        let _ = await AudioManager.shared.awaitCaptureCompletion()

        isRecordingVoice = false
        
        // Check for errors
        if let error = AudioManager.shared.recordingError {
            voiceRecordingError = error
        } else if !AudioManager.shared.transcribedText.isEmpty {
            // Create voice reminder from transcribed text
            if let audioFileURL = AudioManager.shared.getAudioFileURL() {
                let fileName = audioFileURL.lastPathComponent
                voiceReminder = VoiceReminder(
                    audioFileName: fileName,
                    transcribedText: AudioManager.shared.transcribedText,
                    recordingDuration: AudioManager.shared.recordingDuration
                )
                
                // Pre-fill title with transcribed text if title is empty
                if title.isEmpty {
                    title = AudioManager.shared.transcribedText
                }
                
                Logger(subsystem: "a-do", category: "Voice").info("Voice reminder created: \(fileName)")
            }
        }
    }
    
    func stopVoiceRecording() {
        AudioManager.shared.stopRecording()
        isRecordingVoice = false
    }
    
    func cancelVoiceRecording() {
        AudioManager.shared.cancelRecording()
        isRecordingVoice = false
        voiceRecordingError = nil
    }
    
    func playVoiceRecording() async {
        if let voiceReminder = voiceReminder, let audioFileURL = voiceReminder.audioFileURL {
            do {
                let player = try AVAudioPlayer(contentsOf: audioFileURL)
                player.play()
                Logger(subsystem: "a-do", category: "Voice").info("Playing voice recording: \(voiceReminder.audioFileName)")
            } catch {
                Logger(subsystem: "a-do", category: "Voice").error("Failed to play voice recording: \(String(describing: error))")
            }
        }
    }
    
    func deleteVoiceRecording() {
        AudioManager.shared.deleteAudioFile()
        voiceReminder = nil
    }
    
    func detectCurrentLocation() async {
        isDetectingLocation = true
        locationDetectionError = nil
        
        Logger(subsystem: "a-do", category: "Location").info("Starting location detection...")
        
        if LocationManager.shared.authorizationStatus == .notDetermined {
            Logger(subsystem: "a-do", category: "Location").info("Requesting location authorization...")
            _ = await LocationManager.shared.awaitAuthorization()
        }
        
        // Check authorization status
        if LocationManager.shared.authorizationStatus == .denied || LocationManager.shared.authorizationStatus == .restricted {
            locationDetectionError = "Location access denied. Please enable location access in Settings > Privacy & Security > Location Services > a-do"
            Logger(subsystem: "a-do", category: "Location").error("Location access denied: \(LocationManager.shared.authorizationStatus.rawValue)")
            isDetectingLocation = false
            return
        }
        
        // Get current location with timeout
        Logger(subsystem: "a-do", category: "Location").info("Getting current location...")
        if let location = await LocationManager.shared.getCurrentLocation() {
            // Validate the location accuracy
            if location.horizontalAccuracy <= 100 { // Within 100 meters accuracy
                locationLatitude = location.coordinate.latitude
                locationLongitude = location.coordinate.longitude
                
                Logger(subsystem: "a-do", category: "Location").info("Location detected: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
                
                // Generate a default label based on location
                if locationLabel.isEmpty {
                    if let address = LocationManager.shared.currentAddress {
                        locationLabel = address
                        Logger(subsystem: "a-do", category: "Location").info("Using resolved address: \(address)")
                    } else {
                        locationLabel = "Current Location"
                        Logger(subsystem: "a-do", category: "Location").info("Using default label: Current Location")
                    }
                }
            } else {
                locationDetectionError = "Location accuracy too low (\(Int(location.horizontalAccuracy))m). Please try again or move to an area with better GPS signal."
                Logger(subsystem: "a-do", category: "Location").error("Location accuracy too low: \(location.horizontalAccuracy)m")
            }
        } else {
            // Check if there's a specific error from the location manager
            if let error = LocationManager.shared.lastLocationError {
                locationDetectionError = "Location detection failed: \(error)"
            } else {
                locationDetectionError = "Unable to detect current location. Please check your location settings and try again."
            }
            Logger(subsystem: "a-do", category: "Location").error("Location detection failed")
        }
        
        isDetectingLocation = false
    }
    
    func prefillWithCurrentLocation() async {
        Logger(subsystem: "a-do", category: "Location").info("Prefilling with current location...")
        
        if let location = await LocationManager.shared.getCurrentLocation() {
            // Only use location if it's reasonably accurate
            if location.horizontalAccuracy <= 100 {
                locationLatitude = location.coordinate.latitude
                locationLongitude = location.coordinate.longitude
                
                Logger(subsystem: "a-do", category: "Location").info("Prefilled location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                if locationLabel.isEmpty {
                    if let address = LocationManager.shared.currentAddress {
                        locationLabel = address
                    } else {
                        locationLabel = "Current Location"
                    }
                }
            } else {
                Logger(subsystem: "a-do", category: "Location").warning("Location accuracy too low for prefill: \(location.horizontalAccuracy)m")
            }
        } else {
            Logger(subsystem: "a-do", category: "Location").warning("Could not prefill location")
        }
    }
}
