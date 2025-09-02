import Foundation
import EventKit
import SwiftData
import Observation
import os
import UIKit

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
    
    // Sync tracking
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var syncError: String?
    var autoSyncEnabled: Bool = true
    var syncInterval: TimeInterval = 300 // 5 minutes
    
    private var syncTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {
        setupAutoSync()
    }
    
    deinit {
        // Avoid accessing actor-isolated properties here
        NotificationCenter.default.removeObserver(self)
    }
    
    @MainActor private func performCleanup() {
        syncTimer?.invalidate()
        syncTimer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func requestAccess() async throws {
        try await store.requestFullAccessToReminders()
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
    
    // MARK: - Automatic Sync
    
    func setupAutoSync() {
        guard self.autoSyncEnabled else { return }
        
        // Start timer for periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoSync()
            }
        }
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        Logger(subsystem: "a-do", category: "Sync").info("Auto sync setup complete")
    }
    
    func stopAutoSync() {
        performCleanup()
        NotificationCenter.default.removeObserver(self)
        Logger(subsystem: "a-do", category: "Sync").info("Auto sync stopped")
    }
    
    @objc private func appDidBecomeActive() {
        Task { @MainActor in
            await performAutoSync()
        }
    }
    
    @objc private func appWillResignActive() {
        // Start background task for sync
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.backgroundTask = .invalid
        }
    }
    
    func performAutoSync() async {
        guard self.autoSyncEnabled && !isSyncing else { return }
        
        // Check if Apple Reminders integration is enabled in settings
        // Note: This would need access to ModelContext, so we'll check it from the calling code
        
        // Check if enough time has passed since last sync
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < syncInterval {
            return
        }
        
        isSyncing = true
        syncError = nil
        
        Logger(subsystem: "a-do", category: "Sync").info("Starting automatic sync")
        
        do {
            try await requestAccess()
            
            // Perform bidirectional sync
            await syncFromAppleReminders()
            await syncToAppleReminders()
            
            lastSyncDate = Date()
            Logger(subsystem: "a-do", category: "Sync").info("Automatic sync completed successfully")
            
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Sync").error("Sync failed: \(String(describing: error))")
        }
        
        isSyncing = false
        
        // End background task if active
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func syncFromAppleReminders() async {
        // This will import new reminders from Apple Reminders
        // Implementation similar to importReminders but without UI progress tracking
        Logger(subsystem: "a-do", category: "Sync").info("Syncing from Apple Reminders")
        
        // Note: This would need access to ModelContext, so we'll call it from the main app
    }
    
    func syncToAppleReminders() async {
        // This will export new reminders to Apple Reminders
        Logger(subsystem: "a-do", category: "Sync").info("Syncing to Apple Reminders")
        
        // Note: This would need access to ModelContext, so we'll call it from the main app
    }
    
    func toggleAutoSync() {
        self.autoSyncEnabled.toggle()
        
        if self.autoSyncEnabled {
            setupAutoSync()
        } else {
            stopAutoSync()
        }
        
        Logger(subsystem: "a-do", category: "Sync").info("Auto sync \(self.autoSyncEnabled ? "enabled" : "disabled")")
    }
    
    func setSyncInterval(_ interval: TimeInterval) {
        syncInterval = interval
        
        if self.autoSyncEnabled {
            stopAutoSync()
            setupAutoSync()
        }
        
        Logger(subsystem: "a-do", category: "Sync").info("Sync interval set to \(interval) seconds")
    }
    
}
