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

    private init() {
        setupAutoSync()
    }
    
    deinit {
        // Avoid accessing actor-isolated properties here
        NotificationCenter.default.removeObserver(self)
    }
    
    @MainActor private func performCleanup() {
        // Lifecycle observers are removed in stopAutoSync/deinit.
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
                        
                        // Filter out reminders that already exist or can be linked by Apple ID/title.
                        var descriptor = FetchDescriptor<Reminder>()
                        descriptor.fetchLimit = 1000
                        let existingReminders = (try? context.fetch(descriptor)) ?? []
                        let newReminders = reminders.filter { reminder in
                            !self.matchesExistingReminder(reminder, existingReminders: existingReminders)
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
                        
                        // Filter out reminders that already exist or can be linked by Apple ID/title.
                        var descriptor = FetchDescriptor<Reminder>()
                        descriptor.fetchLimit = 1000
                        let existingReminders = (try? context.fetch(descriptor)) ?? []
                        let unseenReminders = reminders.filter { reminder in
                            !self.matchesExistingReminder(reminder, existingReminders: existingReminders)
                        }

                        self.availableRemindersCount = unseenReminders.count
                        Logger(subsystem: "a-do", category: "Import").info("Importing \(unseenReminders.count) new reminders (skipping \(reminders.count - unseenReminders.count) duplicates)")

                        let total = Double(max(1, reminders.count))
                        
                        for (index, ekReminder) in reminders.enumerated() {
                            guard let title = ekReminder.title, !title.isEmpty else { continue }

                            if existingReminders.contains(where: { $0.appleReminderID == ekReminder.calendarItemIdentifier }) {
                                self.importProgress = Double(index + 1) / total
                                continue
                            }

                            if let existingReminder = self.findLinkableReminder(for: ekReminder, in: existingReminders) {
                                existingReminder.appleReminderID = ekReminder.calendarItemIdentifier
                                self.importProgress = Double(index + 1) / total
                                continue
                            }
                            
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
                            reminder.appleReminderID = ekReminder.calendarItemIdentifier
                            
                            context.insert(reminder)
                            self.importedCount += 1
                            self.importProgress = Double(index + 1) / total
                        }
                        
                        do {
                            try context.save()
                            AdvancedSearchManager.shared.markIndexDirty()
                            WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
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

    private func matchesExistingReminder(_ reminder: EKReminder, existingReminders: [Reminder]) -> Bool {
        guard reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return true
        }

        if existingReminders.contains(where: { $0.appleReminderID == reminder.calendarItemIdentifier }) {
            return true
        }

        return findLinkableReminder(for: reminder, in: existingReminders) != nil
    }

    private func findLinkableReminder(for reminder: EKReminder, in reminders: [Reminder]) -> Reminder? {
        guard let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let reminderDueDate = reminder.dueDateComponents?.date
        let normalizedTitle = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return reminders.first { existing in
            guard existing.appleReminderID == nil else { return false }

            let existingTitle = existing.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard existingTitle == normalizedTitle else { return false }

            switch (existing.dueDate, reminderDueDate) {
            case (nil, nil):
                return true
            case let (lhs?, rhs?):
                return abs(lhs.timeIntervalSince(rhs)) < 60
            default:
                return false
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
    
    // MARK: - Automatic Sync
    
    func setupAutoSync() {
        guard self.autoSyncEnabled else {
            stopAutoSync()
            return
        }
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
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
    
    @objc private func appWillResignActive() {}
    
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

        let context = ModelContext(AppContainer.shared.getContainer())
        await AppleRemindersSyncManager.shared.performLifecycleSyncIfNeeded(context: context, reason: "autoSync")
        lastSyncDate = Date()
        Logger(subsystem: "a-do", category: "Sync").info("Automatic sync completed successfully")
        
        isSyncing = false
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

    // MARK: - Snooze Functionality

    /// Snooze options with smart suggestions
    enum SnoozeOption: CaseIterable {
        case fifteenMinutes
        case oneHour
        case threeHours
        case tomorrow
        case nextWeek
        case laterToday
        case thisEvening
        case custom(Date)

        static var allCases: [SnoozeOption] {
            [.fifteenMinutes, .oneHour, .threeHours, .tomorrow, .nextWeek, .laterToday, .thisEvening]
        }

        var displayName: String {
            switch self {
            case .fifteenMinutes: return "15 minutes"
            case .oneHour: return "1 hour"
            case .threeHours: return "3 hours"
            case .tomorrow: return "Tomorrow"
            case .nextWeek: return "Next week"
            case .laterToday: return "Later today"
            case .thisEvening: return "This evening"
            case .custom: return "Custom time"
            }
        }

        var icon: String {
            switch self {
            case .fifteenMinutes: return "clock.badge.questionmark"
            case .oneHour: return "clock"
            case .threeHours: return "clock.fill"
            case .tomorrow: return "sun.max"
            case .nextWeek: return "calendar"
            case .laterToday: return "clock.arrow.circlepath"
            case .thisEvening: return "moon"
            case .custom: return "calendar.badge.clock"
            }
        }

        func snoozeDate(from now: Date = Date()) -> Date {
            let calendar = Calendar.current

            switch self {
            case .fifteenMinutes:
                return now.addingTimeInterval(15 * 60)
            case .oneHour:
                return now.addingTimeInterval(60 * 60)
            case .threeHours:
                return now.addingTimeInterval(3 * 60 * 60)
            case .tomorrow:
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            case .nextWeek:
                let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) ?? nextWeek
            case .laterToday:
                // 3 hours from now, but not past 6 PM
                let later = now.addingTimeInterval(3 * 60 * 60)
                let sixPM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
                return min(later, sixPM)
            case .thisEvening:
                return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            case .custom(let date):
                return date
            }
        }
    }

    /// Snooze a reminder
    func snoozeReminder(_ reminder: Reminder, option: SnoozeOption, context: ModelContext) {
        let newDueDate = option.snoozeDate()
        reminder.dueDate = newDueDate
        reminder.snoozeCount = (reminder.snoozeCount ?? 0) + 1
        reminder.lastSnoozedAt = Date()

        do {
            try context.save()

            // Reschedule notification
            Task {
                await NotificationManager.shared.scheduleNotification(for: reminder, at: newDueDate)
            }

            Logger(subsystem: "a-do", category: "Reminders").info("Snoozed reminder '\(reminder.title)' until \(newDueDate)")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to snooze reminder: \(error.localizedDescription)")
        }
    }

    /// Get smart snooze suggestions based on context
    func getSmartSnoozeSuggestions(for reminder: Reminder) -> [SnoozeOption] {
        var suggestions: [SnoozeOption] = []
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Quick options always available
        suggestions.append(.fifteenMinutes)
        suggestions.append(.oneHour)

        // Time-based suggestions
        if hour < 12 {
            // Morning: suggest later today, this afternoon
            suggestions.append(.laterToday)
        } else if hour < 17 {
            // Afternoon: suggest this evening
            suggestions.append(.thisEvening)
        }

        // Always offer tomorrow and next week for less urgent items
        if reminder.priority != .high {
            suggestions.append(.tomorrow)
            suggestions.append(.nextWeek)
        } else {
            // High priority: shorter snooze times
            suggestions.append(.threeHours)
        }

        return suggestions
    }

    // MARK: - Batch Operations

    /// Complete multiple reminders at once
    func completeReminders(_ reminders: [Reminder], context: ModelContext) {
        let now = Date()

        for reminder in reminders {
            reminder.isCompleted = true
            reminder.completedAt = now
        }

        do {
            try context.save()

            // Cancel notifications for completed reminders
            for reminder in reminders {
                NotificationManager.shared.cancelNotification(for: reminder)
            }

            Task {
                for reminder in reminders {
                    await AdvancedSearchManager.shared.upsertReminderIndex(for: reminder, context: context)
                }
            }

            Logger(subsystem: "a-do", category: "Reminders").info("Batch completed \(reminders.count) reminders")

            // Post notification for UI updates
            NotificationCenter.default.post(name: NSNotification.Name("RemindersCompleted"), object: nil)

        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch complete reminders: \(error.localizedDescription)")
        }
    }

    /// Delete multiple reminders at once
    func deleteReminders(_ reminders: [Reminder], context: ModelContext) {
        for reminder in reminders {
            // Cancel notifications
            NotificationManager.shared.cancelNotification(for: reminder)

            // Delete the reminder
            context.delete(reminder)
        }

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Batch deleted \(reminders.count) reminders")

            // Post notification for UI updates
            NotificationCenter.default.post(name: NSNotification.Name("RemindersDeleted"), object: nil)

        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch delete reminders: \(error.localizedDescription)")
        }
    }

    /// Move multiple reminders to a different list
    func moveReminders(_ reminders: [Reminder], to list: ReminderList, context: ModelContext) {
        for reminder in reminders {
            reminder.list = list
        }

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Batch moved \(reminders.count) reminders to '\(list.name)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch move reminders: \(error.localizedDescription)")
        }
    }

    /// Reschedule multiple reminders
    func rescheduleReminders(_ reminders: [Reminder], to newDate: Date, context: ModelContext) {
        for reminder in reminders {
            reminder.dueDate = newDate

            // Reschedule notification
            Task {
                await NotificationManager.shared.scheduleNotification(for: reminder, at: newDate)
            }
        }

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Batch rescheduled \(reminders.count) reminders to \(newDate)")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch reschedule reminders: \(error.localizedDescription)")
        }
    }

    /// Set priority for multiple reminders
    func setPriority(_ priority: Priority, for reminders: [Reminder], context: ModelContext) {
        for reminder in reminders {
            reminder.priority = priority
        }

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Batch set priority \(priority.title) for \(reminders.count) reminders")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch set priority: \(error.localizedDescription)")
        }
    }

    /// Add tags to multiple reminders
    func addTags(_ tags: [Tag], to reminders: [Reminder], context: ModelContext) {
        for reminder in reminders {
            for tag in tags {
                if !(reminder.tags?.contains(where: { $0.id == tag.id }) ?? false) {
                    reminder.tags?.append(tag)
                }
            }
        }

        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Batch added \(tags.count) tags to \(reminders.count) reminders")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to batch add tags: \(error.localizedDescription)")
        }
    }
}
