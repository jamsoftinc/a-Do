import Foundation
import SwiftData
import os
import Observation
import CoreLocation

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
    
    // Location detection
    var isDetectingLocation: Bool = false
    var locationDetectionError: String?
    
    // Computed property to check if coordinates are valid
    var hasValidCoordinates: Bool {
        return self.locationLatitude >= -90 && self.locationLatitude <= 90 &&
               self.locationLongitude >= -180 && self.locationLongitude <= 180
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
        if existing == nil { context.insert(target) }
        do { try context.save() } catch { Logger(subsystem: "a-do", category: "Reminders").error("Save failed: \(String(describing: error))") }
        return target
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

