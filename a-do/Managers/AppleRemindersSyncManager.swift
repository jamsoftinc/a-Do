import Foundation
import EventKit
import SwiftData
import os

@MainActor
final class AppleRemindersSyncManager {
    static let shared = AppleRemindersSyncManager()
    private let store = EKEventStore()
    
    // Sync state
    private var lastSyncDate: Date?
    private var isSyncing = false
    private var syncError: String?
    
    private init() {}
    
    // MARK: - Main Sync Methods
    
    func performFullSync(context: ModelContext) async {
        guard !isSyncing else {
            Logger(subsystem: "a-do", category: "Sync").info("Sync already in progress, skipping")
            return
        }
        
        // Check if Apple Reminders integration is enabled
        let settings = SettingsManager.shared.getSettings(context: context)
        guard settings.appleRemindersEnabled else {
            Logger(subsystem: "a-do", category: "Sync").info("Apple Reminders integration is disabled, skipping sync")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        Logger(subsystem: "a-do", category: "Sync").info("Starting full sync with Apple Reminders")
        
        do {
            try await requestAccess()
            
            // Perform bidirectional sync
            await syncFromAppleReminders(context: context)
            await syncToAppleReminders(context: context)
            
            lastSyncDate = Date()
            Logger(subsystem: "a-do", category: "Sync").info("Full sync completed successfully")
            
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Sync").error("Sync failed: \(String(describing: error))")
        }
        
        isSyncing = false
    }
    
    // MARK: - Sync from Apple Reminders
    
    private func syncFromAppleReminders(context: ModelContext) async {
        Logger(subsystem: "a-do", category: "Sync").info("Syncing from Apple Reminders")
        
        await withCheckedContinuation { continuation in
            let predicate = self.store.predicateForReminders(in: nil)
            self.store.fetchReminders(matching: predicate) { reminders in
                Task { @MainActor in
                    guard let reminders = reminders else {
                        Logger(subsystem: "a-do", category: "Sync").error("Failed to fetch Apple Reminders")
                        continuation.resume()
                        return
                    }
                    
                    let importedCount = await self.importNewReminders(reminders, into: context)
                    Logger(subsystem: "a-do", category: "Sync").info("Imported \(importedCount) new reminders from Apple Reminders")
                    continuation.resume()
                }
            }
        }
    }
    
    private func importNewReminders(_ ekReminders: [EKReminder], into context: ModelContext) async -> Int {
        var importedCount = 0
        
        // Get existing reminders to avoid duplicates
        let existingReminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let existingTitles = Set(existingReminders.map { $0.title })
        
        for ekReminder in ekReminders {
            guard let title = ekReminder.title, !title.isEmpty else { continue }
            
            // Skip if already exists
            if existingTitles.contains(title) { continue }
            
            let dueDate = ekReminder.dueDateComponents?.date
            let priority = convertPriority(from: ekReminder.priority)
            let isCompleted = ekReminder.isCompleted
            
            let reminder = Reminder(
                title: title,
                details: ekReminder.notes,
                dueDate: dueDate,
                isCompleted: isCompleted,
                priority: priority
            )
            
            context.insert(reminder)
            importedCount += 1
        }
        
        // Save changes
        do {
            try context.save()
        } catch {
            Logger(subsystem: "a-do", category: "Sync").error("Failed to save imported reminders: \(String(describing: error))")
        }
        
        return importedCount
    }
    
    // MARK: - Sync to Apple Reminders
    
    private func syncToAppleReminders(context: ModelContext) async {
        Logger(subsystem: "a-do", category: "Sync").info("Syncing to Apple Reminders")
        
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        var exportedCount = 0
        
        for reminder in reminders {
            // Check if this reminder has already been exported
            if reminder.appleReminderID != nil { continue }
            
            do {
                let ekReminder = EKReminder(eventStore: self.store)
                ekReminder.title = reminder.title
                ekReminder.notes = reminder.details
                
                if let dueDate = reminder.dueDate {
                    ekReminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                }
                
                ekReminder.priority = convertToEKPriority(reminder.priority)
                ekReminder.isCompleted = reminder.isCompleted
                ekReminder.calendar = self.store.defaultCalendarForNewReminders()
                
                try self.store.save(ekReminder, commit: true)
                
                // Store the Apple Reminder ID for future reference
                reminder.appleReminderID = ekReminder.calendarItemIdentifier
                exportedCount += 1
                
            } catch {
                Logger(subsystem: "a-do", category: "Sync").error("Failed to export reminder '\(reminder.title)': \(String(describing: error))")
            }
        }
        
        // Save the Apple Reminder IDs
        do {
            try context.save()
        } catch {
            Logger(subsystem: "a-do", category: "Sync").error("Failed to save Apple Reminder IDs: \(String(describing: error))")
        }
        
        Logger(subsystem: "a-do", category: "Sync").info("Exported \(exportedCount) reminders to Apple Reminders")
    }
    
    // MARK: - Update Existing Reminders
    
    func updateAppleReminder(for reminder: Reminder) async {
        guard let appleReminderID = reminder.appleReminderID else { return }
        
        do {
            try await requestAccess()
            
            // Find the existing Apple Reminder
            let predicate = self.store.predicateForReminders(in: nil)
            await withCheckedContinuation { continuation in
                self.store.fetchReminders(matching: predicate) { reminders in
                    Task { @MainActor in
                        guard let reminders = reminders else {
                            continuation.resume()
                            return
                        }
                        
                        if let ekReminder = reminders.first(where: { $0.calendarItemIdentifier == appleReminderID }) {
                            // Update the Apple Reminder
                            ekReminder.title = reminder.title
                            ekReminder.notes = reminder.details
                            
                            if let dueDate = reminder.dueDate {
                                ekReminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                            } else {
                                ekReminder.dueDateComponents = nil
                            }
                            
                            ekReminder.priority = self.convertToEKPriority(reminder.priority)
                            ekReminder.isCompleted = reminder.isCompleted
                            
                            do {
                                try self.store.save(ekReminder, commit: true)
                                Logger(subsystem: "a-do", category: "Sync").info("Updated Apple Reminder: \(reminder.title)")
                            } catch {
                                Logger(subsystem: "a-do", category: "Sync").error("Failed to update Apple Reminder: \(String(describing: error))")
                            }
                        }
                        
                        continuation.resume()
                    }
                }
            }
        } catch {
            Logger(subsystem: "a-do", category: "Sync").error("Failed to update Apple Reminder: \(String(describing: error))")
        }
    }
    
    func deleteAppleReminder(for reminder: Reminder) async {
        guard let appleReminderID = reminder.appleReminderID else { return }
        
        do {
            try await requestAccess()
            
            let predicate = self.store.predicateForReminders(in: nil)
            await withCheckedContinuation { continuation in
                self.store.fetchReminders(matching: predicate) { reminders in
                    Task { @MainActor in
                        guard let reminders = reminders else {
                            continuation.resume()
                            return
                        }
                        
                        if let ekReminder = reminders.first(where: { $0.calendarItemIdentifier == appleReminderID }) {
                            do {
                                try self.store.remove(ekReminder, commit: true)
                                Logger(subsystem: "a-do", category: "Sync").info("Deleted Apple Reminder: \(reminder.title)")
                            } catch {
                                Logger(subsystem: "a-do", category: "Sync").error("Failed to delete Apple Reminder: \(String(describing: error))")
                            }
                        }
                        
                        continuation.resume()
                    }
                }
            }
        } catch {
            Logger(subsystem: "a-do", category: "Sync").error("Failed to delete Apple Reminder: \(String(describing: error))")
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestAccess() async throws {
        try await self.store.requestFullAccessToReminders()
    }
    
    private func convertPriority(from ekPriority: Int) -> Priority {
        switch ekPriority {
        case 1...3: return .high
        case 4...6: return .medium
        case 7...9: return .low
        default: return .none
        }
    }
    
    private func convertToEKPriority(_ priority: Priority) -> Int {
        switch priority {
        case .high: return 1
        case .medium: return 5
        case .low: return 9
        case .none: return 0
        }
    }
    
    // MARK: - Public Interface
    
    var isCurrentlySyncing: Bool {
        return isSyncing
    }
    
    var lastSync: Date? {
        return lastSyncDate
    }
    
    var currentSyncError: String? {
        return syncError
    }
}
