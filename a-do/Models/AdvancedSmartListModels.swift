//
//  AdvancedSmartListModels.swift
//  a-do
//
//  Advanced smart list and filtering models
//

import Foundation
import SwiftData

// MARK: - Enhanced Smart List Conditions
enum SmartListCondition: String, CaseIterable, Codable, Identifiable {
    // Time-based conditions
    case createdInLastWeek = "created_in_last_week"
    case createdInLastMonth = "created_in_last_month"
    case completedThisWeek = "completed_this_week"
    case completedThisMonth = "completed_this_month"
    case dueInNextWeek = "due_in_next_week"
    case dueInNextMonth = "due_in_next_month"
    case overdueBeyondWeek = "overdue_beyond_week"
    case noDueDate = "no_due_date"
    
    // Content-based conditions
    case hasAttachments = "has_attachments"
    case hasVoiceRecording = "has_voice_recording"
    case hasLocation = "has_location"
    case hasContacts = "has_contacts"
    case hasNotes = "has_notes"
    case hasComments = "has_comments"
    case titleContains = "title_contains"
    case detailsContain = "details_contain"
    
    // Time tracking conditions
    case timeSpentGreaterThan = "time_spent_greater_than"
    case timeSpentLessThan = "time_spent_less_than"
    case hasTimeTracking = "has_time_tracking"
    case noTimeTracking = "no_time_tracking"
    
    // Habit-related conditions
    case habitRelated = "habit_related"
    case recurringReminder = "recurring_reminder"
    case fromTemplate = "from_template"
    
    // Collaboration conditions
    case sharedWithOthers = "shared_with_others"
    case sharedByOthers = "shared_by_others"
    case hasCollaborators = "has_collaborators"
    case recentlyModified = "recently_modified"
    
    // Priority and status conditions
    case highPriorityOverdue = "high_priority_overdue"
    case lowPriorityOld = "low_priority_old"
    case completedWithinHour = "completed_within_hour"
    case longRunningTasks = "long_running_tasks"
    
    // Custom conditions
    case customFilter = "custom_filter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .createdInLastWeek: return "Created in Last Week"
        case .createdInLastMonth: return "Created in Last Month"
        case .completedThisWeek: return "Completed This Week"
        case .completedThisMonth: return "Completed This Month"
        case .dueInNextWeek: return "Due in Next Week"
        case .dueInNextMonth: return "Due in Next Month"
        case .overdueBeyondWeek: return "Overdue Beyond Week"
        case .noDueDate: return "No Due Date"
        case .hasAttachments: return "Has Attachments"
        case .hasVoiceRecording: return "Has Voice Recording"
        case .hasLocation: return "Has Location"
        case .hasContacts: return "Has Contacts"
        case .hasNotes: return "Has Notes"
        case .hasComments: return "Has Comments"
        case .titleContains: return "Title Contains"
        case .detailsContain: return "Details Contain"
        case .timeSpentGreaterThan: return "Time Spent Greater Than"
        case .timeSpentLessThan: return "Time Spent Less Than"
        case .hasTimeTracking: return "Has Time Tracking"
        case .noTimeTracking: return "No Time Tracking"
        case .habitRelated: return "Habit Related"
        case .recurringReminder: return "Recurring Reminder"
        case .fromTemplate: return "From Template"
        case .sharedWithOthers: return "Shared with Others"
        case .sharedByOthers: return "Shared by Others"
        case .hasCollaborators: return "Has Collaborators"
        case .recentlyModified: return "Recently Modified"
        case .highPriorityOverdue: return "High Priority Overdue"
        case .lowPriorityOld: return "Low Priority Old"
        case .completedWithinHour: return "Completed Within Hour"
        case .longRunningTasks: return "Long Running Tasks"
        case .customFilter: return "Custom Filter"
        }
    }
    
    var icon: String {
        switch self {
        case .createdInLastWeek, .createdInLastMonth: return "calendar.badge.plus"
        case .completedThisWeek, .completedThisMonth: return "checkmark.circle"
        case .dueInNextWeek, .dueInNextMonth: return "clock.badge"
        case .overdueBeyondWeek: return "exclamationmark.triangle"
        case .noDueDate: return "calendar.badge.minus"
        case .hasAttachments: return "paperclip"
        case .hasVoiceRecording: return "waveform"
        case .hasLocation: return "location"
        case .hasContacts: return "person.2"
        case .hasNotes: return "note.text"
        case .hasComments: return "bubble.left"
        case .titleContains, .detailsContain: return "magnifyingglass"
        case .timeSpentGreaterThan, .timeSpentLessThan: return "timer"
        case .hasTimeTracking: return "stopwatch"
        case .noTimeTracking: return "stopwatch.fill"
        case .habitRelated: return "chart.line.uptrend.xyaxis"
        case .recurringReminder: return "repeat"
        case .fromTemplate: return "doc.text"
        case .sharedWithOthers, .sharedByOthers: return "person.2.badge.gearshape"
        case .hasCollaborators: return "person.3"
        case .recentlyModified: return "clock.arrow.circlepath"
        case .highPriorityOverdue: return "exclamationmark.triangle.fill"
        case .lowPriorityOld: return "clock.badge.questionmark"
        case .completedWithinHour: return "checkmark.circle.fill"
        case .longRunningTasks: return "hourglass"
        case .customFilter: return "slider.horizontal.3"
        }
    }
    
    var requiresValue: Bool {
        switch self {
        case .titleContains, .detailsContain, .timeSpentGreaterThan, .timeSpentLessThan, .customFilter:
            return true
        default:
            return false
        }
    }
    
    var valueType: SmartListValueType {
        switch self {
        case .titleContains, .detailsContain, .customFilter:
            return .text
        case .timeSpentGreaterThan, .timeSpentLessThan:
            return .duration
        default:
            return .none
        }
    }
}

// MARK: - Value Types for Conditions
enum SmartListValueType: String, CaseIterable, Codable {
    case none = "none"
    case text = "text"
    case number = "number"
    case duration = "duration"
    case date = "date"
    case priority = "priority"
    case tag = "tag"
    case category = "category"
}

// MARK: - Enhanced Smart List Rule
@Model
final class EnhancedSmartListRule {
    var id: UUID = UUID()
    var condition: SmartListCondition = SmartListCondition.createdInLastWeek
    var listOperator: SmartListOperator = SmartListOperator.equals
    var value: String = ""
    var isEnabled: Bool = true
    var order: Int = 0
    
    // Advanced options
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var invertCondition: Bool = false // NOT condition
    
    @Relationship(deleteRule: .nullify) var smartList: EnhancedSmartList?
    
    init(condition: SmartListCondition, operator: SmartListOperator = .equals, value: String = "") {
        self.condition = condition
        self.listOperator = `operator`
        self.value = value
    }
    
    // MARK: - Rule Evaluation
    
    func evaluate(reminder: Reminder, timeEntries: [TimeEntry] = [], sharedReminders: [SharedReminder] = []) -> Bool {
        let result = evaluateCondition(reminder: reminder, timeEntries: timeEntries, sharedReminders: sharedReminders)
        return invertCondition ? !result : result
    }
    
    private func evaluateCondition(reminder: Reminder, timeEntries: [TimeEntry], sharedReminders: [SharedReminder]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch condition {
        // Time-based conditions
        case .createdInLastWeek:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return reminder.createdAt >= weekAgo
            
        case .createdInLastMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return reminder.createdAt >= monthAgo
            
        case .completedThisWeek:
            guard reminder.isCompleted, let completedAt = reminder.completedAt else { return false }
            return calendar.isDate(completedAt, equalTo: now, toGranularity: .weekOfYear)
            
        case .completedThisMonth:
            guard reminder.isCompleted, let completedAt = reminder.completedAt else { return false }
            return calendar.isDate(completedAt, equalTo: now, toGranularity: .month)
            
        case .dueInNextWeek:
            guard let dueDate = reminder.dueDate else { return false }
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return dueDate >= now && dueDate <= nextWeek
            
        case .dueInNextMonth:
            guard let dueDate = reminder.dueDate else { return false }
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return dueDate >= now && dueDate <= nextMonth
            
        case .overdueBeyondWeek:
            guard let dueDate = reminder.dueDate else { return false }
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return dueDate < weekAgo && !reminder.isCompleted
            
        case .noDueDate:
            return reminder.dueDate == nil
            
        // Content-based conditions
        case .hasAttachments:
            return reminder.appleNote != nil || reminder.voiceReminder != nil
            
        case .hasVoiceRecording:
            return reminder.voiceReminder != nil
            
        case .hasLocation:
            return reminder.locationTrigger != nil
            
        case .hasContacts:
            return !(reminder.taggedContacts?.isEmpty ?? true)
            
        case .hasNotes:
            return reminder.appleNote != nil
            
        case .hasComments:
            // This would need to be implemented with a relationship to comments
            return false // Placeholder
            
        case .titleContains:
            return evaluateTextCondition(text: reminder.title, searchValue: value)
            
        case .detailsContain:
            guard let details = reminder.details else { return false }
            return evaluateTextCondition(text: details, searchValue: value)
            
        // Time tracking conditions
        case .timeSpentGreaterThan:
            let totalTime = timeEntries.filter { $0.reminder?.uuid == reminder.uuid }
                .reduce(0) { $0 + $1.actualDuration }
            guard let threshold = TimeInterval(value) else { return false }
            return totalTime > threshold
            
        case .timeSpentLessThan:
            let totalTime = timeEntries.filter { $0.reminder?.uuid == reminder.uuid }
                .reduce(0) { $0 + $1.actualDuration }
            guard let threshold = TimeInterval(value) else { return false }
            return totalTime < threshold
            
        case .hasTimeTracking:
            return timeEntries.contains { $0.reminder?.uuid == reminder.uuid }
            
        case .noTimeTracking:
            return !timeEntries.contains { $0.reminder?.uuid == reminder.uuid }
            
        // Collaboration conditions
        case .sharedWithOthers:
            return sharedReminders.contains { $0.reminderID == reminder.uuid && $0.isActive }
            
        case .sharedByOthers:
            return sharedReminders.contains { 
                $0.reminderID == reminder.uuid && $0.isActive && $0.ownerID != getCurrentUserID()
            }
            
        case .hasCollaborators:
            return sharedReminders.first { $0.reminderID == reminder.uuid }?.activeParticipants.count ?? 0 > 0
            
        case .recentlyModified:
            let hourAgo = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            return reminder.createdAt >= hourAgo // This could be enhanced with a lastModified field
            
        // Priority and status conditions
        case .highPriorityOverdue:
            return reminder.priority == .high && reminder.isOverdue
            
        case .lowPriorityOld:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return reminder.priority == .low && reminder.createdAt < weekAgo
            
        case .completedWithinHour:
            guard reminder.isCompleted, let completedAt = reminder.completedAt else { return false }
            let hourAgo = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            return completedAt >= hourAgo
            
        case .longRunningTasks:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return reminder.createdAt < monthAgo && !reminder.isCompleted
            
        // Placeholder conditions
        case .habitRelated, .recurringReminder, .fromTemplate, .customFilter:
            return false // These would need additional implementation
        }
    }
    
    private func evaluateTextCondition(text: String, searchValue: String) -> Bool {
        let searchText = caseSensitive ? text : text.lowercased()
        let searchFor = caseSensitive ? searchValue : searchValue.lowercased()
        
        if useRegex {
            do {
                let regex = try NSRegularExpression(pattern: searchFor)
                let range = NSRange(location: 0, length: searchText.utf16.count)
                return regex.firstMatch(in: searchText, options: [], range: range) != nil
            } catch {
                return false
            }
        } else {
            switch listOperator {
            case .equals:
                return searchText == searchFor
            case .contains:
                return searchText.contains(searchFor)
            case .startsWith:
                return searchText.hasPrefix(searchFor)
            case .endsWith:
                return searchText.hasSuffix(searchFor)
            default:
                return searchText.contains(searchFor)
            }
        }
    }
    
    private func getCurrentUserID() -> String {
        // Return a default user ID for now - this would be properly implemented
        // with proper user management in a real app
        return "default_user"
    }
}

// MARK: - Smart List Operators
enum SmartListOperator: String, CaseIterable, Codable {
    case equals = "equals"
    case notEquals = "not_equals"
    case contains = "contains"
    case notContains = "not_contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThanOrEqual = "less_than_or_equal"
    case isEmpty = "is_empty"
    case isNotEmpty = "is_not_empty"
    
    var displayName: String {
        switch self {
        case .equals: return "Equals"
        case .notEquals: return "Not Equals"
        case .contains: return "Contains"
        case .notContains: return "Not Contains"
        case .startsWith: return "Starts With"
        case .endsWith: return "Ends With"
        case .greaterThan: return "Greater Than"
        case .lessThan: return "Less Than"
        case .greaterThanOrEqual: return "Greater Than or Equal"
        case .lessThanOrEqual: return "Less Than or Equal"
        case .isEmpty: return "Is Empty"
        case .isNotEmpty: return "Is Not Empty"
        }
    }
}

// MARK: - Enhanced Smart List
@Model
final class EnhancedSmartList {
    var id: UUID = UUID()
    var name: String = ""
    var listDescription: String = ""
    var icon: String = "list.bullet"
    var colorHex: String = "#007AFF"
    var isActive: Bool = true
    var createdAt: Date = Date()
    var lastUsed: Date?
    var usageCount: Int = 0
    
    // Logic settings
    var logicOperator: SmartListLogicOperator = SmartListLogicOperator.and
    var sortBy: SmartListSortOption = SmartListSortOption.dueDate
    var sortOrder: SmartListSortOrder = SmartListSortOrder.ascending
    var maxResults: Int = 100
    
    // Display settings
    var showCompletedItems: Bool = false
    var groupBy: SmartListGroupOption = SmartListGroupOption.none
    var showSubtasks: Bool = true
    
    // Auto-refresh settings
    var autoRefresh: Bool = true
    var refreshInterval: TimeInterval = 300 // 5 minutes
    
    @Relationship(deleteRule: .cascade) var rules: [EnhancedSmartListRule] = []
    
    init(name: String, description: String = "") {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.listDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
    
    // MARK: - Rule Management
    
    func addRule(condition: SmartListCondition, operator: SmartListOperator = .equals, value: String = "") {
        let rule = EnhancedSmartListRule(condition: condition, operator: `operator`, value: value)
        rule.order = rules.count
        rule.smartList = self
        rules.append(rule)
    }
    
    func removeRule(_ rule: EnhancedSmartListRule) {
        if let index = rules.firstIndex(of: rule) {
            rules.remove(at: index)
            // Reorder remaining rules
            for (newIndex, remainingRule) in rules.enumerated() {
                remainingRule.order = newIndex
            }
        }
    }
    
    func moveRule(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < rules.count,
              destinationIndex >= 0, destinationIndex < rules.count else { return }
        
        let rule = rules.remove(at: sourceIndex)
        rules.insert(rule, at: destinationIndex)
        
        // Update order values
        for (index, rule) in rules.enumerated() {
            rule.order = index
        }
    }
    
    // MARK: - List Evaluation
    
    func evaluate(reminders: [Reminder], timeEntries: [TimeEntry] = [], sharedReminders: [SharedReminder] = []) -> [Reminder] {
        guard !rules.isEmpty else { return reminders }
        
        let enabledRules = rules.filter { $0.isEnabled }.sorted { $0.order < $1.order }
        guard !enabledRules.isEmpty else { return reminders }
        
        var filteredReminders: [Reminder] = []
        
        for reminder in reminders {
            let ruleResults = enabledRules.map { rule in
                rule.evaluate(reminder: reminder, timeEntries: timeEntries, sharedReminders: sharedReminders)
            }
            
            let matches: Bool
            switch logicOperator {
            case .and:
                matches = ruleResults.allSatisfy { $0 }
            case .or:
                matches = ruleResults.contains { $0 }
            case .not:
                matches = !ruleResults.allSatisfy { $0 }
            }
            
            if matches {
                filteredReminders.append(reminder)
            }
        }
        
        // Apply completion filter
        if !showCompletedItems {
            filteredReminders = filteredReminders.filter { !$0.isCompleted }
        }
        
        // Sort results
        filteredReminders = sortReminders(filteredReminders)
        
        // Apply limit
        if maxResults > 0 && filteredReminders.count > maxResults {
            filteredReminders = Array(filteredReminders.prefix(maxResults))
        }
        
        // Update usage statistics
        lastUsed = Date()
        usageCount += 1
        
        return filteredReminders
    }
    
    private func sortReminders(_ reminders: [Reminder]) -> [Reminder] {
        return reminders.sorted { reminder1, reminder2 in
            let comparison: Bool
            
            switch sortBy {
            case .title:
                comparison = reminder1.title < reminder2.title
            case .createdAt:
                comparison = reminder1.createdAt < reminder2.createdAt
            case .dueDate:
                let date1 = reminder1.dueDate ?? Date.distantFuture
                let date2 = reminder2.dueDate ?? Date.distantFuture
                comparison = date1 < date2
            case .priority:
                comparison = reminder1.priorityRaw > reminder2.priorityRaw // Higher priority first
            case .completedAt:
                let date1 = reminder1.completedAt ?? Date.distantPast
                let date2 = reminder2.completedAt ?? Date.distantPast
                comparison = date1 < date2
            }
            
            return sortOrder == .ascending ? comparison : !comparison
        }
    }
}

// MARK: - Supporting Enums

enum SmartListLogicOperator: String, CaseIterable, Codable {
    case and = "and"
    case or = "or"
    case not = "not"
    
    var displayName: String {
        switch self {
        case .and: return "AND (All conditions)"
        case .or: return "OR (Any condition)"
        case .not: return "NOT (None of the conditions)"
        }
    }
}

enum SmartListSortOption: String, CaseIterable, Codable {
    case title = "title"
    case createdAt = "created_at"
    case dueDate = "due_date"
    case priority = "priority"
    case completedAt = "completed_at"
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .createdAt: return "Created Date"
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .completedAt: return "Completed Date"
        }
    }
}

enum SmartListSortOrder: String, CaseIterable, Codable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

enum SmartListGroupOption: String, CaseIterable, Codable {
    case none = "none"
    case priority = "priority"
    case dueDate = "due_date"
    case tag = "tag"
    case list = "list"
    case status = "status"
    
    var displayName: String {
        switch self {
        case .none: return "No Grouping"
        case .priority: return "Priority"
        case .dueDate: return "Due Date"
        case .tag: return "Tag"
        case .list: return "List"
        case .status: return "Status"
        }
    }
}

// MARK: - Saved Search
@Model
final class SavedSearch {
    var id: UUID = UUID()
    var name: String = ""
    var query: String = ""
    var filters: Data? // JSON encoded filter criteria
    var createdAt: Date = Date()
    var lastUsed: Date?
    var usageCount: Int = 0
    var isGlobal: Bool = false // Available to all users in workspace
    
    init(name: String, query: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
    
    func updateUsage() {
        lastUsed = Date()
        usageCount += 1
    }
}
