import Foundation
import SwiftData
import os
import Observation
import CoreLocation
import SwiftUI
import AVFoundation

@MainActor
@Observable
final class ReminderHomeViewModel {
    var quickTitle: String = ""
    var quickDueDate: Date?
    var showingQuickDatePicker: Bool = false

    func addQuickReminder(context: ModelContext) {
        let safeTitle = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeTitle.isEmpty else { return }
        let reminder = Reminder(title: safeTitle, dueDate: quickDueDate)
        context.insert(reminder)
        do { 
            try context.save() 
            Logger(subsystem: "a-do", category: "Reminders").info("Quick reminder saved: '\(safeTitle)' with ID: \(String(describing: reminder.id)), due: \(self.quickDueDate?.description ?? "none")")
            
            // Sync to Apple Reminders (only if enabled)
            Task {
                let settings = SettingsManager.shared.getSettings(context: context)
                if settings.appleRemindersEnabled {
                    await AppleRemindersSyncManager.shared.performFullSync(context: context)
                }
            }
        } catch { 
            Logger(subsystem: "a-do", category: "Reminders").error("Quick add failed: \(String(describing: error))") 
        }
        quickTitle = ""
        quickDueDate = nil
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
    
    // MARK: - Reminder Completion
    
    func markReminderComplete(_ reminder: Reminder, context: ModelContext) {
        reminder.isCompleted = true
        reminder.completedAt = Date()
        
        // Cancel any pending notifications for this reminder
        NotificationManager.shared.cancelNotifications(for: reminder.id)
        
        // Stop location monitoring if this reminder has location triggers
        if let locationTrigger = reminder.locationTrigger {
            LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
        }
        
        do {
            try context.save()
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
            Logger(subsystem: "a-do", category: "Reminders").info("Reminder marked incomplete: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to mark reminder incomplete: \(String(describing: error))")
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
    
    // Apple Note attachment
    var attachedNote: AppleNoteAttachment?
    var showNotePicker: Bool = false
    
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
    
    // Computed property to check if coordinates are valid
    var hasValidCoordinates: Bool {
        return self.locationLatitude >= -90 && self.locationLatitude <= 90 &&
               self.locationLongitude >= -180 && self.locationLongitude <= 180
    }
    
    // Computed property to get attendee emails
    var attendeeEmails: [String] {
        return calendarAttendees
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @discardableResult
    func save(context: ModelContext, existing: Reminder? = nil) -> Reminder {
        let target = existing ?? Reminder(title: title)
        target.title = title
        target.details = details.isEmpty ? nil : details
        target.dueDate = dueDate
        target.priority = priority
        target.tags = selectedTags.isEmpty ? nil : Array(selectedTags)
        target.notifications = leadTimes.isEmpty ? nil : leadTimes.map { ReminderNotification(leadTimeSeconds: $0) }
        if !locationLabel.isEmpty && hasValidCoordinates {
            target.locationTrigger = LocationTrigger(label: locationLabel, latitude: self.locationLatitude, longitude: self.locationLongitude, radius: locationRadius, type: locationType)
        } else if !locationLabel.isEmpty && !hasValidCoordinates {
            // Log invalid coordinates but don't create location trigger
            Logger(subsystem: "a-do", category: "Location").error("Invalid coordinates provided: lat=\(self.locationLatitude), lon=\(self.locationLongitude)")
        }
        target.autoTextTaggedContacts = autoTextTaggedContacts
        target.autoTextMe = autoTextMe
        target.appleNote = attachedNote
        target.voiceReminder = voiceReminder
        if existing == nil { context.insert(target) }
        do { 
            try context.save() 
            
            // Sync to Apple Reminders (only if enabled)
            Task {
                let settings = SettingsManager.shared.getSettings(context: context)
                if settings.appleRemindersEnabled {
                    await AppleRemindersSyncManager.shared.performFullSync(context: context)
                }
            }
        } catch { 
            Logger(subsystem: "a-do", category: "Reminders").error("Save failed: \(String(describing: error))") 
        }
        return target
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
        
        // Monitor recording state
        while AudioManager.shared.isRecording {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
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
        
        // Request authorization if needed
        if LocationManager.shared.authorizationStatus == .notDetermined {
            LocationManager.shared.requestAuthorization()
        }
        
        // Wait a moment for authorization to be processed
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if LocationManager.shared.authorizationStatus == .denied || LocationManager.shared.authorizationStatus == .restricted {
            locationDetectionError = "Location access denied. Please enable location access in Settings."
            isDetectingLocation = false
            return
        }
        
        // Get current location
        if let location = await LocationManager.shared.getCurrentLocation() {
            locationLatitude = location.coordinate.latitude
            locationLongitude = location.coordinate.longitude
            
            // Generate a default label based on location
            if locationLabel.isEmpty {
                if let address = LocationManager.shared.currentAddress {
                    locationLabel = address
                } else {
                    locationLabel = "Current Location"
                }
            }
        } else {
            locationDetectionError = "Unable to detect current location. Please check your location settings."
        }
        
        isDetectingLocation = false
    }
    
    func prefillWithCurrentLocation() async {
        if let location = await LocationManager.shared.getCurrentLocation() {
            locationLatitude = location.coordinate.latitude
            locationLongitude = location.coordinate.longitude
            if locationLabel.isEmpty {
                if let address = LocationManager.shared.currentAddress {
                    locationLabel = address
                } else {
                    locationLabel = "Current Location"
                }
            }
        }
    }
}

