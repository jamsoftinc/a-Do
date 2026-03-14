import Foundation
import EventKit
import os
import Observation
import UIKit
import SwiftData

@MainActor
@Observable
final class CalendarManager {
    static let shared = CalendarManager()

    private let store = EKEventStore()
    var accessGranted: Bool = false
    var todayEvents: [EKEvent] = []
    var upcomingEvents: [EKEvent] = []

    private init() {}

    func refreshAuthorizationStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            accessGranted = true
        default:
            accessGranted = false
        }
    }

    func requestAccess() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.requestFullAccessToEvents { granted, error in
                Task { @MainActor in
                    if let error = error {
                        Logger(subsystem: "a-do", category: "Calendar").error("Calendar access error: \(error.localizedDescription)")
                    } else if granted {
                        Logger(subsystem: "a-do", category: "Calendar").info("Calendar access granted successfully")
                    } else {
                        Logger(subsystem: "a-do", category: "Calendar").warning("Calendar access denied by user")
                    }
                    self.accessGranted = granted
                    continuation.resume(returning: ())
                }
            }
        }
        await loadEvents()
    }

    func loadEvents() async {
        guard accessGranted else { return }
        let calendars = store.calendars(for: .event)
        let now = Date()
        let endToday = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let fiveDays = Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now

        let todayPredicate = store.predicateForEvents(withStart: now, end: endToday, calendars: calendars)
        let upcomingPredicate = store.predicateForEvents(withStart: now, end: fiveDays, calendars: calendars)

        let allToday = store.events(matching: todayPredicate).sorted { $0.startDate < $1.startDate }
        let allUpcoming = store.events(matching: upcomingPredicate)
            .filter { $0.startDate > endToday }
            .sorted { $0.startDate < $1.startDate }

        self.todayEvents = allToday
        self.upcomingEvents = allUpcoming
    }

    func createEvent(from reminderTitle: String, dueDate: Date?) async throws {
        guard accessGranted else { return }
        let event = EKEvent(eventStore: store)
        event.title = reminderTitle
        if let dueDate = dueDate {
            event.startDate = dueDate
            event.endDate = dueDate.addingTimeInterval(60 * 30)
        } else {
            event.startDate = Date()
            event.endDate = Date().addingTimeInterval(60 * 30)
        }
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent, commit: true)
        await loadEvents()
    }
    
    // Enhanced calendar invite creation with attendees and location
    func createCalendarInvite(
        title: String,
        details: String?,
        dueDate: Date?,
        duration: TimeInterval = 30 * 60, // 30 minutes default
        location: String? = nil,
        attendees: [String] = [], // Array of email addresses
        reminder: Reminder? = nil,
        context: ModelContext? = nil
    ) async throws -> EKEvent? {
        // Check if Apple Calendar integration is enabled
        if let context = context {
            let settings = SettingsManager.shared.getSettings(context: context)
            guard settings.appleCalendarEnabled else {
                Logger(subsystem: "a-do", category: "Calendar").info("Apple Calendar integration is disabled")
                return nil
            }
        }
        
        guard accessGranted else { 
            Logger(subsystem: "a-do", category: "Calendar").error("Calendar access not granted")
            return nil 
        }
        
        let event = EKEvent(eventStore: store)
        event.title = title
        
        // Set start and end dates
        if let dueDate = dueDate {
            event.startDate = dueDate
            event.endDate = dueDate.addingTimeInterval(duration)
        } else {
            let now = Date()
            event.startDate = now
            event.endDate = now.addingTimeInterval(duration)
        }
        
        // Set location if provided
        if let location = location, !location.isEmpty {
            event.location = location
        }
        
        // Set notes/description
        var notes = ""
        if let details = details, !details.isEmpty {
            notes += details
        }
        
        // Add reminder context if available
        if let reminder = reminder {
            if !notes.isEmpty { notes += "\n\n" }
            notes += "Created from Remember reminder"
            // Temporarily disabled - tags relationship commented out
            // if let tags = reminder.tags, !tags.isEmpty {
            //     let tagNames = tags.map { $0.name }.joined(separator: ", ")
            //     notes += "\nTags: \(tagNames)"
            // }
        }
        
        if !notes.isEmpty {
            event.notes = notes
        }
        
        // Add attendees from the provided list
        var allAttendees = attendees
        
        // Add attendees from tagged contacts if reminder is provided
        // Temporarily disabled - taggedContacts relationship commented out
        // if let reminder = reminder, let taggedContacts = reminder.taggedContacts {
        //     for contact in taggedContacts {
        //         // Try to get email from contacts manager
        //         if let email = await ContactsManager.shared.getEmailForContact(identifier: contact.identifier) {
        //             allAttendees.append(email)
        //         }
        //     }
        // }
        
        // Remove duplicates and add to event
        let uniqueAttendees = Array(Set(allAttendees)).filter { !$0.isEmpty }
        
        // Add attendees to event notes for broad iOS compatibility.
        if !uniqueAttendees.isEmpty {
            var attendeeNote = "\n\nAttendees:"
            for email in uniqueAttendees {
                attendeeNote += "\n- \(email)"
            }
            event.notes = (event.notes ?? "") + attendeeNote
        }
        
        // Set calendar
        event.calendar = store.defaultCalendarForNewEvents
        
        // Save the event
        try store.save(event, span: .thisEvent, commit: true)
        
        // Mark the reminder as having a calendar invite created
        if let reminder = reminder {
            reminder.calendarInviteCreated = true
        }
        
        Logger(subsystem: "a-do", category: "Calendar").info("Calendar invite created: '\(title)' with \(uniqueAttendees.count) attendees")
        
        await loadEvents()
        return event
    }
    
    func openEventInCalendar(_ event: EKEvent) {
        // Try to open the specific event using EventKit's URL scheme
        if let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty, let eventURL = URL(string: "calshow://event/\(eventIdentifier)") {
            Task {
                await UIApplication.shared.open(eventURL)
            }
            return
        }

        // Fallback: Open Calendar app at the event's date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: event.startDate)

        if let calendarURL = URL(string: "calshow://\(dateString)") {
            Task {
                await UIApplication.shared.open(calendarURL)
            }
            return
        }

        // Final fallback: Open Calendar app
        if let calendarURL = URL(string: "calshow://") {
            Task {
                await UIApplication.shared.open(calendarURL)
            }
        }
    }

    // MARK: - Calendar Blocking

    /// Create a time block on calendar for a reminder
    @discardableResult
    func createTimeBlock(
        for reminder: Reminder,
        startDate: Date,
        duration: TimeInterval,
        context: ModelContext
    ) async throws -> String? {
        guard accessGranted else {
            Logger(subsystem: "a-do", category: "Calendar").error("Calendar access not granted for time blocking")
            return nil
        }

        let event = EKEvent(eventStore: store)
        event.title = "⏰ \(reminder.title)"
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = store.defaultCalendarForNewEvents

        // Mark as busy time
        event.availability = .busy

        // Add notes
        var notes = "Time blocked for: \(reminder.title)"
        if let details = reminder.details, !details.isEmpty {
            notes += "\n\n\(details)"
        }
        notes += "\n\nCreated by a-do"
        event.notes = notes

        // Add alarm 5 minutes before
        let alarm = EKAlarm(relativeOffset: -5 * 60)
        event.addAlarm(alarm)

        try store.save(event, span: .thisEvent, commit: true)

        // Save the event ID to the reminder
        reminder.calendarEventID = event.eventIdentifier
        reminder.calendarInviteCreated = true

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Calendar").info("Created time block for '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Calendar").error("Failed to save reminder with event ID: \(error.localizedDescription)")
        }

        await loadEvents()
        return event.eventIdentifier
    }

    /// Update an existing time block
    func updateTimeBlock(
        for reminder: Reminder,
        newStartDate: Date,
        newDuration: TimeInterval,
        context: ModelContext
    ) async throws {
        guard accessGranted else { return }

        guard let eventID = reminder.calendarEventID,
              let event = store.event(withIdentifier: eventID) else {
            // No existing event, create new one
            try await createTimeBlock(for: reminder, startDate: newStartDate, duration: newDuration, context: context)
            return
        }

        event.startDate = newStartDate
        event.endDate = newStartDate.addingTimeInterval(newDuration)
        event.title = "⏰ \(reminder.title)"

        try store.save(event, span: .thisEvent, commit: true)

        Logger(subsystem: "a-do", category: "Calendar").info("Updated time block for '\(reminder.title)'")
        await loadEvents()
    }

    /// Delete a time block
    func deleteTimeBlock(for reminder: Reminder, context: ModelContext) async throws {
        guard accessGranted else { return }

        guard let eventID = reminder.calendarEventID,
              let event = store.event(withIdentifier: eventID) else {
            Logger(subsystem: "a-do", category: "Calendar").warning("No time block found for reminder")
            return
        }

        try store.remove(event, span: .thisEvent, commit: true)

        // Clear the event ID from reminder
        reminder.calendarEventID = nil

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Calendar").info("Deleted time block for '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Calendar").error("Failed to clear event ID: \(error.localizedDescription)")
        }

        await loadEvents()
    }

    /// Check for conflicts with existing calendar events
    func checkForConflicts(startDate: Date, duration: TimeInterval) -> [EKEvent] {
        guard accessGranted else { return [] }

        let endDate = startDate.addingTimeInterval(duration)
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)

        return store.events(matching: predicate)
    }

    /// Find available time slots for a task
    func findAvailableSlots(
        duration: TimeInterval,
        preferredStartHour: Int = 9,
        preferredEndHour: Int = 17,
        daysAhead: Int = 7
    ) -> [Date] {
        guard accessGranted else { return [] }

        var availableSlots: [Date] = []
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<daysAhead {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            // Set the working hours for this day
            guard let workStart = calendar.date(bySettingHour: preferredStartHour, minute: 0, second: 0, of: dayStart),
                  let workEnd = calendar.date(bySettingHour: preferredEndHour, minute: 0, second: 0, of: dayStart) else { continue }

            // Get existing events for this day
            let calendars = store.calendars(for: .event)
            let predicate = store.predicateForEvents(withStart: workStart, end: workEnd, calendars: calendars)
            let existingEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

            var currentSlotStart = workStart

            // Skip if this time is in the past
            if currentSlotStart < now {
                currentSlotStart = now
                // Round up to next 30-minute slot
                let minute = calendar.component(.minute, from: currentSlotStart)
                if minute > 0 && minute <= 30 {
                    currentSlotStart = calendar.date(bySettingHour: calendar.component(.hour, from: currentSlotStart), minute: 30, second: 0, of: currentSlotStart) ?? currentSlotStart
                } else if minute > 30 {
                    currentSlotStart = calendar.date(byAdding: .hour, value: 1, to: currentSlotStart) ?? currentSlotStart
                    currentSlotStart = calendar.date(bySettingHour: calendar.component(.hour, from: currentSlotStart), minute: 0, second: 0, of: currentSlotStart) ?? currentSlotStart
                }
            }

            for event in existingEvents {
                // Check if there's a slot before this event
                let slotEnd = currentSlotStart.addingTimeInterval(duration)
                if slotEnd <= event.startDate {
                    availableSlots.append(currentSlotStart)
                }

                // Move to after this event
                if event.endDate > currentSlotStart {
                    currentSlotStart = event.endDate
                }
            }

            // Check if there's time after the last event
            let finalSlotEnd = currentSlotStart.addingTimeInterval(duration)
            if finalSlotEnd <= workEnd && currentSlotStart >= (dayOffset == 0 ? now : workStart) {
                availableSlots.append(currentSlotStart)
            }
        }

        return availableSlots
    }

    /// Suggest best time for a reminder based on priority and existing schedule
    func suggestTimeForReminder(_ reminder: Reminder, duration: TimeInterval = 30 * 60) -> Date? {
        let availableSlots = findAvailableSlots(duration: duration)

        guard !availableSlots.isEmpty else { return nil }

        // For high priority, suggest earliest slot
        if reminder.priority == .high {
            return availableSlots.first
        }

        // For medium priority, suggest mid-morning or early afternoon
        let calendar = Calendar.current
        for slot in availableSlots {
            let hour = calendar.component(.hour, from: slot)
            if hour >= 10 && hour <= 14 {
                return slot
            }
        }

        // Default to first available
        return availableSlots.first
    }
}
