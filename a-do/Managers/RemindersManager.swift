import Foundation
import EventKit
import SwiftData
import Observation

@MainActor
@Observable
final class RemindersManager {
    static let shared = RemindersManager()
    private let store = EKEventStore()

    private init() {}

    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            try await store.requestFullAccessToReminders()
        } else {
            // Fallback for iOS 16 and earlier
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAccess(to: .reminder) { _, error in
                    if let error { 
                        continuation.resume(throwing: error) 
                    } else { 
                        continuation.resume(returning: ()) 
                    }
                }
            }
        }
    }

    func importReminders(into context: ModelContext) async {
        let predicate = store.predicateForReminders(in: nil)
        store.fetchReminders(matching: predicate) { reminders in
            guard let reminders else { return }
            Task { @MainActor in
                for ekr in reminders {
                    guard let title = ekr.title, !title.isEmpty else { continue }
                    let due = ekr.dueDateComponents?.date
                    let reminder = Reminder(title: title, dueDate: due)
                    context.insert(reminder)
                }
                try? context.save()
            }
        }
    }

    func export(reminder: Reminder) throws {
        let ekReminder = EKReminder(eventStore: store)
        ekReminder.title = reminder.title
        ekReminder.notes = reminder.details
        if let due = reminder.dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: due)
        }
        ekReminder.calendar = store.defaultCalendarForNewReminders()
        try store.save(ekReminder, commit: true)
    }
}


