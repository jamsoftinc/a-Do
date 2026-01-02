//
//  AdvancedSmartListManager.swift
//  a-do
//
//  Manager for advanced smart lists and filtering
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class AdvancedSmartListManager {
    static let shared = AdvancedSmartListManager()
    
    private let logger = Logger(subsystem: "a-do", category: "AdvancedSmartLists")
    
    // Processing state
    var isProcessing: Bool = false
    var lastRefreshDate: Date?
    
    // Cache for performance
    private var cachedResults: [UUID: [Reminder]] = [:]
    private var cacheTimestamps: [UUID: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Smart List Management
    
    func createSmartList(
        name: String,
        description: String = "",
        icon: String = "list.bullet",
        colorHex: String = "#007AFF",
        context: ModelContext
    ) -> EnhancedSmartList {
        let smartList = EnhancedSmartList(name: name, description: description)
        smartList.icon = icon
        smartList.colorHex = colorHex
        
        context.insert(smartList)
        
        do {
            try context.save()
            logger.info("Created smart list: \(name)")
        } catch {
            logger.error("Failed to create smart list: \(error.localizedDescription)")
        }
        
        return smartList
    }
    
    func duplicateSmartList(_ smartList: EnhancedSmartList, newName: String, context: ModelContext) -> EnhancedSmartList {
        let duplicate = EnhancedSmartList(name: newName, description: smartList.listDescription)
        duplicate.icon = smartList.icon
        duplicate.colorHex = smartList.colorHex
        duplicate.logicOperator = smartList.logicOperator
        duplicate.sortBy = smartList.sortBy
        duplicate.sortOrder = smartList.sortOrder
        duplicate.maxResults = smartList.maxResults
        duplicate.showCompletedItems = smartList.showCompletedItems
        duplicate.groupBy = smartList.groupBy
        duplicate.showSubtasks = smartList.showSubtasks
        duplicate.autoRefresh = smartList.autoRefresh
        duplicate.refreshInterval = smartList.refreshInterval

        // Initialize rules array if nil
        if duplicate.rules == nil {
            duplicate.rules = []
        }

        // Duplicate rules
        for rule in smartList.rules ?? [] {
            let duplicateRule = EnhancedSmartListRule(
                condition: rule.condition,
                operator: rule.listOperator,
                value: rule.value
            )
            duplicateRule.isEnabled = rule.isEnabled
            duplicateRule.order = rule.order
            duplicateRule.caseSensitive = rule.caseSensitive
            duplicateRule.useRegex = rule.useRegex
            duplicateRule.invertCondition = rule.invertCondition
            duplicateRule.smartList = duplicate

            duplicate.rules?.append(duplicateRule)
        }
        
        context.insert(duplicate)
        
        do {
            try context.save()
            logger.info("Duplicated smart list: \(smartList.name) -> \(newName)")
        } catch {
            logger.error("Failed to duplicate smart list: \(error.localizedDescription)")
        }
        
        return duplicate
    }
    
    func deleteSmartList(_ smartList: EnhancedSmartList, context: ModelContext) {
        // Clear cache
        cachedResults.removeValue(forKey: smartList.id)
        cacheTimestamps.removeValue(forKey: smartList.id)
        
        context.delete(smartList)
        
        do {
            try context.save()
            logger.info("Deleted smart list: \(smartList.name)")
        } catch {
            logger.error("Failed to delete smart list: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Rule Management
    
    func addRule(
        to smartList: EnhancedSmartList,
        condition: SmartListCondition,
        operator: SmartListOperator = .equals,
        value: String = "",
        context: ModelContext
    ) {
        smartList.addRule(condition: condition, operator: `operator`, value: value)
        
        // Clear cache for this smart list
        cachedResults.removeValue(forKey: smartList.id)
        cacheTimestamps.removeValue(forKey: smartList.id)
        
        do {
            try context.save()
            logger.info("Added rule to smart list: \(smartList.name)")
        } catch {
            logger.error("Failed to add rule: \(error.localizedDescription)")
        }
    }
    
    func updateRule(
        _ rule: EnhancedSmartListRule,
        condition: SmartListCondition? = nil,
        operator: SmartListOperator? = nil,
        value: String? = nil,
        isEnabled: Bool? = nil,
        context: ModelContext
    ) {
        if let condition = condition { rule.condition = condition }
        if let `operator` = `operator` { rule.listOperator = `operator` }
        if let value = value { rule.value = value }
        if let isEnabled = isEnabled { rule.isEnabled = isEnabled }
        
        // Clear cache for the smart list
        if let smartListId = rule.smartList?.id {
            cachedResults.removeValue(forKey: smartListId)
            cacheTimestamps.removeValue(forKey: smartListId)
        }
        
        do {
            try context.save()
            logger.info("Updated smart list rule")
        } catch {
            logger.error("Failed to update rule: \(error.localizedDescription)")
        }
    }
    
    func removeRule(_ rule: EnhancedSmartListRule, from smartList: EnhancedSmartList, context: ModelContext) {
        smartList.removeRule(rule)
        
        // Clear cache
        cachedResults.removeValue(forKey: smartList.id)
        cacheTimestamps.removeValue(forKey: smartList.id)
        
        do {
            try context.save()
            logger.info("Removed rule from smart list: \(smartList.name)")
        } catch {
            logger.error("Failed to remove rule: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Smart List Evaluation
    
    func evaluateSmartList(
        _ smartList: EnhancedSmartList,
        context: ModelContext,
        useCache: Bool = true
    ) async -> [Reminder] {
        // Check cache first
        if useCache,
           let cached = cachedResults[smartList.id],
           let timestamp = cacheTimestamps[smartList.id],
           Date().timeIntervalSince(timestamp) < cacheTimeout {
            return cached
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Capture ID to fetch in background
        let smartListID = smartList.persistentModelID
        
        // Perform heavy database operations on background thread
        let resultIDs = await Task.detached {
            // Create background context for database operations
            let backgroundContext = ModelContext(context.container)
            
            // Fetch the smart list in the background context
            guard let backgroundSmartList = backgroundContext.model(for: smartListID) as? EnhancedSmartList else {
                return [PersistentIdentifier]()
            }
            
            // Use memory-safe data loading with smaller limits
            let reminderIDs = await MemorySafeDataLoader.loadReminders(
                context: backgroundContext,
                limit: 500 // Reduced from 1000
            )
            
            let timeEntryIDs = await MemorySafeDataLoader.loadTimeEntries(
                context: backgroundContext,
                limit: 500 // Reduced from 1000
            )
            
            let sharedReminderIDs = await MemorySafeDataLoader.loadSharedReminders(
                context: backgroundContext,
                limit: 200 // New limit for shared reminders
            )
            
            // Fetch actual objects on background context
            let allReminders = reminderIDs.compactMap { backgroundContext.model(for: $0) as? Reminder }
            let timeEntries = timeEntryIDs.compactMap { backgroundContext.model(for: $0) as? TimeEntry }
            let sharedReminders = sharedReminderIDs.compactMap { backgroundContext.model(for: $0) as? SharedReminder }
            
            // Evaluate the smart list
            let results = backgroundSmartList.evaluate(
                reminders: allReminders,
                timeEntries: timeEntries,
                sharedReminders: sharedReminders
            )
            
            return results.map { $0.persistentModelID }
        }.value
        
        // Fetch result objects on main context
        let results = resultIDs.compactMap { context.model(for: $0) as? Reminder }
        
        // Update cache and state on main actor
        self.cachedResults[smartList.id] = results
        self.cacheTimestamps[smartList.id] = Date()
        self.lastRefreshDate = Date()
        self.logger.info("Evaluated smart list '\(smartList.name)': \(results.count) results")
        
        return results
    }
    
    func refreshAllSmartLists(context: ModelContext) async {
        let descriptor = FetchDescriptor<EnhancedSmartList>(
            predicate: #Predicate { $0.isActive && $0.autoRefresh }
        )
        
        let smartLists = (try? context.fetch(descriptor)) ?? []
        
        for smartList in smartLists {
            // Check if refresh is needed based on interval
            if let lastUsed = smartList.lastUsed,
               Date().timeIntervalSince(lastUsed) < smartList.refreshInterval {
                continue
            }
            
            let _ = await evaluateSmartList(smartList, context: context, useCache: false)
        }
        
        logger.info("Refreshed \(smartLists.count) smart lists")
    }
    
    // MARK: - Predefined Smart Lists
    
    func createDefaultSmartLists(context: ModelContext) {
        let existingLists = getSmartLists(context: context)
        
        // Don't create defaults if any smart lists already exist
        guard existingLists.isEmpty else { return }
        
        let defaultLists = [
            createFocusSmartList(),
            createProductivitySmartList(),
            createOverdueSmartList(),
            createRecentlyCompletedSmartList(),
            createHighPrioritySmartList(),
            createLongRunningSmartList(),
            createCollaborativeSmartList(),
            createTimeTrackedSmartList()
        ]
        
        for smartList in defaultLists {
            context.insert(smartList)
        }
        
        do {
            try context.save()
            logger.info("Created \(defaultLists.count) default smart lists")
        } catch {
            logger.error("Failed to create default smart lists: \(error.localizedDescription)")
        }
    }
    
    private func createFocusSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Focus Today",
            description: "High priority tasks due today or overdue"
        )
        smartList.icon = "target"
        smartList.colorHex = "#FF3B30"
        smartList.logicOperator = .or
        
        // High priority AND due today
        let highPriorityRule = EnhancedSmartListRule(condition: .highPriorityOverdue)
        highPriorityRule.order = 0
        smartList.rules?.append(highPriorityRule)
        
        // Due today
        let dueTodayRule = EnhancedSmartListRule(condition: .dueInNextWeek)
        dueTodayRule.order = 1
        smartList.rules?.append(dueTodayRule)
        
        return smartList
    }
    
    private func createProductivitySmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Productivity Insights",
            description: "Tasks with time tracking and completion data"
        )
        smartList.icon = "chart.bar"
        smartList.colorHex = "#007AFF"
        smartList.showCompletedItems = true
        
        let timeTrackingRule = EnhancedSmartListRule(condition: .hasTimeTracking)
        smartList.rules?.append(timeTrackingRule)
        
        return smartList
    }
    
    private func createOverdueSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Overdue Tasks",
            description: "Tasks that are past their due date"
        )
        smartList.icon = "exclamationmark.triangle"
        smartList.colorHex = "#FF9500"
        smartList.sortBy = .dueDate
        
        let overdueRule = EnhancedSmartListRule(condition: .overdueBeyondWeek)
        smartList.rules?.append(overdueRule)
        
        return smartList
    }
    
    private func createRecentlyCompletedSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Recently Completed",
            description: "Tasks completed in the last week"
        )
        smartList.icon = "checkmark.circle"
        smartList.colorHex = "#34C759"
        smartList.showCompletedItems = true
        smartList.sortBy = .completedAt
        smartList.sortOrder = .descending
        
        let completedRule = EnhancedSmartListRule(condition: .completedThisWeek)
        smartList.rules?.append(completedRule)
        
        return smartList
    }
    
    private func createHighPrioritySmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "High Priority",
            description: "All high priority tasks"
        )
        smartList.icon = "exclamationmark.3"
        smartList.colorHex = "#FF2D92"
        smartList.sortBy = .dueDate
        
        let highPriorityRule = EnhancedSmartListRule(condition: .highPriorityOverdue)
        smartList.rules?.append(highPriorityRule)
        
        return smartList
    }
    
    private func createLongRunningSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Long Running",
            description: "Tasks that have been open for more than a month"
        )
        smartList.icon = "hourglass"
        smartList.colorHex = "#8E8E93"
        smartList.sortBy = .createdAt
        
        let longRunningRule = EnhancedSmartListRule(condition: .longRunningTasks)
        smartList.rules?.append(longRunningRule)
        
        return smartList
    }
    
    private func createCollaborativeSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Shared Tasks",
            description: "Tasks shared with others or by others"
        )
        smartList.icon = "person.2"
        smartList.colorHex = "#5856D6"
        smartList.logicOperator = .or
        
        let sharedWithRule = EnhancedSmartListRule(condition: .sharedWithOthers)
        sharedWithRule.order = 0
        smartList.rules?.append(sharedWithRule)
        
        let sharedByRule = EnhancedSmartListRule(condition: .sharedByOthers)
        sharedByRule.order = 1
        smartList.rules?.append(sharedByRule)
        
        return smartList
    }
    
    private func createTimeTrackedSmartList() -> EnhancedSmartList {
        let smartList = EnhancedSmartList(
            name: "Time Tracked",
            description: "Tasks with time tracking data"
        )
        smartList.icon = "stopwatch"
        smartList.colorHex = "#FF9500"
        smartList.showCompletedItems = true
        smartList.sortBy = .createdAt
        smartList.sortOrder = .descending
        
        let timeTrackedRule = EnhancedSmartListRule(condition: .hasTimeTracking)
        smartList.rules?.append(timeTrackedRule)
        
        return smartList
    }
    
    // MARK: - Search and Filtering
    
    func searchReminders(
        query: String,
        filters: [SmartListCondition] = [],
        context: ModelContext
    ) -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>()
        let allReminders = (try? context.fetch(descriptor)) ?? []
        
        var filteredReminders = allReminders
        
        // Apply text search
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            filteredReminders = filteredReminders.filter { reminder in
                reminder.title.lowercased().contains(lowercaseQuery) ||
                (reminder.details?.lowercased().contains(lowercaseQuery) ?? false)
            }
        }
        
        // Apply filters
        if !filters.isEmpty {
            let timeDescriptor = FetchDescriptor<TimeEntry>()
            let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
            
            let sharedDescriptor = FetchDescriptor<SharedReminder>()
            let sharedReminders = (try? context.fetch(sharedDescriptor)) ?? []
            
            for condition in filters {
                let rule = EnhancedSmartListRule(condition: condition)
                filteredReminders = filteredReminders.filter { reminder in
                    rule.evaluate(reminder: reminder, timeEntries: timeEntries, sharedReminders: sharedReminders)
                }
            }
        }
        
        return filteredReminders
    }
    
    func saveSearch(name: String, query: String, filters: [SmartListCondition], context: ModelContext) -> SavedSearch {
        let savedSearch = SavedSearch(name: name, query: query)
        
        // Encode filters
        if !filters.isEmpty {
            let filterData = try? JSONEncoder().encode(filters.map { $0.rawValue })
            savedSearch.filters = filterData
        }
        
        context.insert(savedSearch)
        
        do {
            try context.save()
            logger.info("Saved search: \(name)")
        } catch {
            logger.error("Failed to save search: \(error.localizedDescription)")
        }
        
        return savedSearch
    }
    
    // MARK: - Utility Methods
    
    func getSmartLists(context: ModelContext) -> [EnhancedSmartList] {
        let descriptor = FetchDescriptor<EnhancedSmartList>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getPopularSmartLists(context: ModelContext, limit: Int = 5) -> [EnhancedSmartList] {
        let descriptor = FetchDescriptor<EnhancedSmartList>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        
        let smartLists = (try? context.fetch(descriptor)) ?? []
        return Array(smartLists.prefix(limit))
    }
    
    func getRecentSmartLists(context: ModelContext, limit: Int = 5) -> [EnhancedSmartList] {
        let descriptor = FetchDescriptor<EnhancedSmartList>(
            predicate: #Predicate { $0.isActive && $0.lastUsed != nil },
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )
        
        let smartLists = (try? context.fetch(descriptor)) ?? []
        return Array(smartLists.prefix(limit))
    }
    
    func getSavedSearches(context: ModelContext) -> [SavedSearch] {
        let descriptor = FetchDescriptor<SavedSearch>(
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func clearCache() {
        cachedResults.removeAll()
        cacheTimestamps.removeAll()
        logger.info("Cleared smart list cache")
    }
    
    func getCacheStats() -> (cachedLists: Int, totalCacheSize: Int) {
        let cachedLists = cachedResults.count
        let totalSize = cachedResults.values.reduce(0) { $0 + $1.count }
        return (cachedLists, totalSize)
    }
}
