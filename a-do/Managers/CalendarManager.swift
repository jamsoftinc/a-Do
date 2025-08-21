import Foundation
import EventKit
import os
import Observation
import UIKit

@MainActor
@Observable
final class CalendarManager {
    static let shared = CalendarManager()

    private let store = EKEventStore()
    var accessGranted: Bool = false
    var todayEvents: [EKEvent] = []
    var upcomingEvents: [EKEvent] = []

    private init() {}

    func requestAccess() async {
        await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, error in
                Task { @MainActor in
                    if let error { Logger(subsystem: "a-do", category: "Calendar").error("Access error: \(String(describing: error))") }
                    self.accessGranted = granted
                    continuation.resume()
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
    
    func openEventInCalendar(_ event: EKEvent) {
        // Try to open the specific event using EventKit's URL scheme
        if let eventURL = event.eventIdentifier.isEmpty ? nil : URL(string: "calshow://event/\(event.eventIdentifier)") {
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

