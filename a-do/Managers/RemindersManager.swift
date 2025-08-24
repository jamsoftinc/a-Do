import Foundation
import EventKit
import SwiftData
import Observation
import os

@MainActor
@Observable
final class RemindersManager {
    static let shared = RemindersManager()
    private let store = EKEventStore()
    
    // Import progress tracking
    var isImporting: Bool = false
    var importProgress: Double = 0.0
    var importedCount: Int = 0
    var lastImportError: String?
    var availableRemindersCount: Int = 0

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

    func checkAvailableReminders(into context: ModelContext) async {
        do {
            try await requestAccess()
            
            await withCheckedContinuation { continuation in
                let predicate = store.predicateForReminders(in: nil)
                store.fetchReminders(matching: predicate) { [weak self] reminders in
                    Task { @MainActor in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        guard let reminders = reminders else {
                            self.availableRemindersCount = 0
                            continuation.resume()
                            return
                        }
                        
                        // Filter out reminders that already exist
                        let existingReminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
                        let existingTitles = Set(existingReminders.map { $0.title })
                        let newReminders = reminders.filter { reminder in
                            guard let title = reminder.title, !title.isEmpty else { return false }
                            return !existingTitles.contains(title)
                        }
                        
                        self.availableRemindersCount = newReminders.count
                        continuation.resume()
                    }
                }
            }
        } catch {
            self.availableRemindersCount = 0
        }
    }
    
    func importReminders(into context: ModelContext) async {
        guard !isImporting else { 
            Logger(subsystem: "a-do", category: "Import").warning("Import already in progress")
            return 
        }
        
        isImporting = true
        importProgress = 0.0
        importedCount = 0
        lastImportError = nil
        
        Logger(subsystem: "a-do", category: "Import").info("Starting Apple Reminders import")
        
        do {
            try await requestAccess()
            
            await withCheckedContinuation { continuation in
                let predicate = store.predicateForReminders(in: nil)
                store.fetchReminders(matching: predicate) { [weak self] reminders in
                    Task { @MainActor in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        guard let reminders = reminders else {
                            self.lastImportError = "Failed to fetch reminders from Apple Reminders"
                            self.isImporting = false
                            Logger(subsystem: "a-do", category: "Import").error("Failed to fetch reminders")
                            continuation.resume()
                            return
                        }
                        
                        Logger(subsystem: "a-do", category: "Import").info("Found \(reminders.count) reminders to import")
                        
                        // Filter out reminders that already exist
                        let existingReminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
                        let existingTitles = Set(existingReminders.map { $0.title })
                        let newReminders = reminders.filter { reminder in
                            guard let title = reminder.title, !title.isEmpty else { return false }
                            return !existingTitles.contains(title)
                        }
                        
                        self.availableRemindersCount = newReminders.count
                        Logger(subsystem: "a-do", category: "Import").info("Importing \(newReminders.count) new reminders (skipping \(reminders.count - newReminders.count) duplicates)")
                        
                        let total = Double(newReminders.count)
                        
                        for (index, ekReminder) in newReminders.enumerated() {
                            guard let title = ekReminder.title, !title.isEmpty else { continue }
                            
                            let dueDate = ekReminder.dueDateComponents?.date
                            let priority = self.convertPriority(from: ekReminder.priority)
                            let isCompleted = ekReminder.isCompleted
                            
                            let reminder = Reminder(
                                title: title,
                                details: ekReminder.notes,
                                dueDate: dueDate,
                                isCompleted: isCompleted,
                                priority: priority
                            )
                            
                            context.insert(reminder)
                            self.importedCount += 1
                            self.importProgress = Double(index + 1) / total
                        }
                        
                        do {
                            try context.save()
                            Logger(subsystem: "a-do", category: "Import").info("Successfully imported \(self.importedCount) reminders")
                        } catch {
                            self.lastImportError = "Failed to save imported reminders: \(error.localizedDescription)"
                            Logger(subsystem: "a-do", category: "Import").error("Save failed: \(String(describing: error))")
                        }
                        
                        self.isImporting = false
                        continuation.resume()
                    }
                }
            }
        } catch {
            lastImportError = "Failed to access Apple Reminders: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Import").error("Access failed: \(String(describing: error))")
            isImporting = false
        }
    }
    
    private func convertPriority(from ekPriority: Int) -> Priority {
        switch ekPriority {
        case 1...3: return .high
        case 4...6: return .medium
        case 7...9: return .low
        default: return .none
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


