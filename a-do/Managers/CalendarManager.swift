import Foundation
import EventKit
import os
import Observation
import UIKit
import SwiftData

@MainActor
final class CalendarManager {
    static let shared = CalendarManager()

    private let store = EKEventStore()
    var accessGranted: Bool = false
    var todayEvents: [EKEvent] = []
    var upcomingEvents: [EKEvent] = []

    private init() {}

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
            if let tags = reminder.tags, !tags.isEmpty {
                let tagNames = tags.map { $0.name }.joined(separator: ", ")
                notes += "\nTags: \(tagNames)"
            }
        }
        
        if !notes.isEmpty {
            event.notes = notes
        }
        
        // Add attendees from the provided list
        var allAttendees = attendees
        
        // Add attendees from tagged contacts if reminder is provided
        if let reminder = reminder, let taggedContacts = reminder.taggedContacts {
            for contact in taggedContacts {
                // Try to get email from contacts manager
                if let email = await ContactsManager.shared.getEmailForContact(identifier: contact.identifier) {
                    allAttendees.append(email)
                }
            }
        }
        
        // Remove duplicates and add to event
        let uniqueAttendees = Array(Set(allAttendees)).filter { !$0.isEmpty }
        
        // Add attendees to the event notes for now
        // This ensures compatibility across all iOS versions
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
}
