//
//  SearchModels.swift
//  a-do
//
//  Advanced search and organization models
//

import Foundation
import SwiftData

// MARK: - Search Configuration
@Model
final class SearchConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var enableFuzzySearch: Bool = true
    var enableSemanticSearch: Bool = true
    var enableVoiceSearch: Bool = true
    var searchHistory: Bool = true
    var maxHistoryItems: Int = 100
    var autoComplete: Bool = true
    var searchSuggestions: Bool = true
    var indexContent: Bool = true
    var indexAttachments: Bool = true
    var indexVoiceNotes: Bool = true
    var searchScope: SearchScope = SearchScope.all
    var defaultSortOrder: SearchSortOrder = SearchSortOrder.relevance
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateSettings() {
        updatedAt = Date()
    }
}

// MARK: - Search Scope
enum SearchScope: String, CaseIterable, Codable {
    case all = "all"
    case reminders = "reminders"
    case habits = "habits"
    case notes = "notes"
    case tags = "tags"
    case lists = "lists"
    case completed = "completed"
    case active = "active"
    case overdue = "overdue"
    
    var displayName: String {
        switch self {
        case .all: return "All Items"
        case .reminders: return "Reminders"
        case .habits: return "Habits"
        case .notes: return "Notes"
        case .tags: return "Tags"
        case .lists: return "Lists"
        case .completed: return "Completed"
        case .active: return "Active"
        case .overdue: return "Overdue"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "magnifyingglass"
        case .reminders: return "bell"
        case .habits: return "repeat"
        case .notes: return "note.text"
        case .tags: return "tag"
        case .lists: return "list.bullet"
        case .completed: return "checkmark.circle"
        case .active: return "circle"
        case .overdue: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Search Sort Order
enum SearchSortOrder: String, CaseIterable, Codable {
    case relevance = "relevance"
    case dateCreated = "date_created"
    case dateModified = "date_modified"
    case dueDate = "due_date"
    case priority = "priority"
    case alphabetical = "alphabetical"
    case usage = "usage"
    
    var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .dateCreated: return "Date Created"
        case .dateModified: return "Date Modified"
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .alphabetical: return "Alphabetical"
        case .usage: return "Usage Frequency"
        }
    }
}

// MARK: - Search Query
@Model
final class SearchQuery {
    var id: UUID = UUID()
    var userId: String = ""
    var query: String = ""
    var searchType: SearchType = SearchType.text
    var scope: SearchScope = SearchScope.all
    var filters: Data? // JSON encoded search filters
    var sortOrder: SearchSortOrder = SearchSortOrder.relevance
    var resultCount: Int = 0
    var executionTime: TimeInterval = 0
    var timestamp: Date = Date()
    var isBookmarked: Bool = false
    var usageCount: Int = 1
    var lastUsed: Date = Date()
    
    init(userId: String, query: String, searchType: SearchType = .text) {
        self.userId = userId
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchType = searchType
        self.timestamp = Date()
        self.lastUsed = Date()
    }
    
    func updateUsage(resultCount: Int, executionTime: TimeInterval) {
        self.resultCount = resultCount
        self.executionTime = executionTime
        self.usageCount += 1
        self.lastUsed = Date()
    }
    
    func setFilters<T: Codable>(_ filters: T) {
        self.filters = try? JSONEncoder().encode(filters)
    }
    
    func getFilters<T: Codable>(as type: T.Type) -> T? {
        guard let filters = filters else { return nil }
        return try? JSONDecoder().decode(type, from: filters)
    }
}

// MARK: - Search Type
enum SearchType: String, CaseIterable, Codable {
    case text = "text"
    case voice = "voice"
    case semantic = "semantic"
    case fuzzy = "fuzzy"
    case regex = "regex"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .text: return "Text Search"
        case .voice: return "Voice Search"
        case .semantic: return "Semantic Search"
        case .fuzzy: return "Fuzzy Search"
        case .regex: return "Regular Expression"
        case .advanced: return "Advanced Search"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .voice: return "mic"
        case .semantic: return "brain"
        case .fuzzy: return "wand.and.stars"
        case .regex: return "function"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

// MARK: - Search Result
@Model
final class SearchResult {
    var id: UUID = UUID()
    var queryId: UUID = UUID()
    var itemType: SearchResultType = SearchResultType.reminder
    var itemId: String = ""
    var title: String = ""
    var snippet: String = ""
    var relevanceScore: Double = 0.0
    var matchType: SearchMatchType = SearchMatchType.exact
    var matchedFields: [String] = []
    var highlightRanges: Data? // JSON encoded highlight ranges
    var timestamp: Date = Date()
    
    init(
        queryId: UUID,
        itemType: SearchResultType,
        itemId: String,
        title: String,
        snippet: String = "",
        relevanceScore: Double = 0.0
    ) {
        self.queryId = queryId
        self.itemType = itemType
        self.itemId = itemId
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relevanceScore = relevanceScore
        self.timestamp = Date()
    }
    
    func setHighlightRanges(_ ranges: [NSRange]) {
        let rangeData = ranges.map { ["location": $0.location, "length": $0.length] }
        highlightRanges = try? JSONEncoder().encode(rangeData)
    }
    
    func getHighlightRanges() -> [NSRange] {
        guard let data = highlightRanges,
              let rangeData = try? JSONDecoder().decode([[String: Int]].self, from: data) else {
            return []
        }
        
        return rangeData.compactMap { dict in
            guard let location = dict["location"], let length = dict["length"] else { return nil }
            return NSRange(location: location, length: length)
        }
    }
}

// MARK: - Search Result Type
enum SearchResultType: String, CaseIterable, Codable {
    case reminder = "reminder"
    case habit = "habit"
    case tag = "tag"
    case list = "list"
    case note = "note"
    case voiceNote = "voice_note"
    case contact = "contact"
    case template = "template"
    case focusSession = "focus_session"
    case timeEntry = "time_entry"
    
    var displayName: String {
        switch self {
        case .reminder: return "Reminder"
        case .habit: return "Habit"
        case .tag: return "Tag"
        case .list: return "List"
        case .note: return "Note"
        case .voiceNote: return "Voice Note"
        case .contact: return "Contact"
        case .template: return "Template"
        case .focusSession: return "Focus Session"
        case .timeEntry: return "Time Entry"
        }
    }
    
    var icon: String {
        switch self {
        case .reminder: return "bell"
        case .habit: return "repeat"
        case .tag: return "tag"
        case .list: return "list.bullet"
        case .note: return "note.text"
        case .voiceNote: return "waveform"
        case .contact: return "person"
        case .template: return "doc.text"
        case .focusSession: return "target"
        case .timeEntry: return "stopwatch"
        }
    }
}

// MARK: - Search Match Type
enum SearchMatchType: String, CaseIterable, Codable {
    case exact = "exact"
    case partial = "partial"
    case fuzzy = "fuzzy"
    case semantic = "semantic"
    case phonetic = "phonetic"
    
    var displayName: String {
        switch self {
        case .exact: return "Exact Match"
        case .partial: return "Partial Match"
        case .fuzzy: return "Fuzzy Match"
        case .semantic: return "Semantic Match"
        case .phonetic: return "Phonetic Match"
        }
    }
    
    var confidence: Double {
        switch self {
        case .exact: return 1.0
        case .partial: return 0.8
        case .fuzzy: return 0.6
        case .semantic: return 0.7
        case .phonetic: return 0.5
        }
    }
}

// MARK: - Search Filter
@Model
final class SearchFilter {
    var id: UUID = UUID()
    var name: String = ""
    var filterType: SearchFilterType = SearchFilterType.dateRange
    var isActive: Bool = true
    var configuration: Data? // JSON encoded filter configuration
    var createdAt: Date = Date()
    var lastUsed: Date?
    var usageCount: Int = 0
    
    init(name: String, filterType: SearchFilterType) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.filterType = filterType
        self.createdAt = Date()
    }
    
    func updateUsage() {
        usageCount += 1
        lastUsed = Date()
    }
    
    func setConfiguration<T: Codable>(_ config: T) {
        configuration = try? JSONEncoder().encode(config)
    }
    
    func getConfiguration<T: Codable>(as type: T.Type) -> T? {
        guard let configuration = configuration else { return nil }
        return try? JSONDecoder().decode(type, from: configuration)
    }
}

// MARK: - Search Filter Type
enum SearchFilterType: String, CaseIterable, Codable {
    case dateRange = "date_range"
    case priority = "priority"
    case status = "status"
    case tags = "tags"
    case lists = "lists"
    case location = "location"
    case duration = "duration"
    case category = "category"
    case collaborators = "collaborators"
    case attachments = "attachments"
    
    var displayName: String {
        switch self {
        case .dateRange: return "Date Range"
        case .priority: return "Priority"
        case .status: return "Status"
        case .tags: return "Tags"
        case .lists: return "Lists"
        case .location: return "Location"
        case .duration: return "Duration"
        case .category: return "Category"
        case .collaborators: return "Collaborators"
        case .attachments: return "Attachments"
        }
    }
    
    var icon: String {
        switch self {
        case .dateRange: return "calendar"
        case .priority: return "exclamationmark"
        case .status: return "checkmark.circle"
        case .tags: return "tag"
        case .lists: return "list.bullet"
        case .location: return "location"
        case .duration: return "timer"
        case .category: return "folder"
        case .collaborators: return "person.2"
        case .attachments: return "paperclip"
        }
    }
}

// MARK: - Search Index
@Model
final class SearchIndex {
    var id: UUID = UUID()
    var itemType: SearchResultType = SearchResultType.reminder
    var itemId: String = ""
    var content: String = ""
    var keywords: [String] = []
    var metadata: Data? // JSON encoded metadata
    var lastIndexed: Date = Date()
    var indexVersion: String = "1.0"
    var isActive: Bool = true
    
    init(itemType: SearchResultType, itemId: String, content: String) {
        self.itemType = itemType
        self.itemId = itemId
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.keywords = extractKeywords(from: content)
        self.lastIndexed = Date()
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 2 } // Only words longer than 2 characters
            .filter { !stopWords.contains($0) }
        
        return Array(Set(words)) // Remove duplicates
    }
    
    func updateContent(_ newContent: String) {
        content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        keywords = extractKeywords(from: content)
        lastIndexed = Date()
    }
    
    func setMetadata<T: Codable>(_ data: T) {
        metadata = try? JSONEncoder().encode(data)
    }
    
    func getMetadata<T: Codable>(as type: T.Type) -> T? {
        guard let metadata = metadata else { return nil }
        return try? JSONDecoder().decode(type, from: metadata)
    }
    
    private var stopWords: Set<String> {
        return Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "is", "are", "was", "were", "be", "been", "have",
            "has", "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "can", "must", "shall", "this", "that", "these", "those"
        ])
    }
}

// MARK: - Organization Rule
@Model
final class OrganizationRule {
    var id: UUID = UUID()
    var userId: String = ""
    var name: String = ""
    var ruleDescription: String = ""
    var ruleType: OrganizationRuleType = OrganizationRuleType.autoTag
    var isActive: Bool = true
    var priority: Int = 0
    var conditions: Data? // JSON encoded conditions
    var actions: Data? // JSON encoded actions
    var createdAt: Date = Date()
    var lastTriggered: Date?
    var triggerCount: Int = 0
    var successRate: Double = 0.0
    
    init(userId: String, name: String, ruleType: OrganizationRuleType) {
        self.userId = userId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ruleType = ruleType
        self.createdAt = Date()
    }
    
    func trigger() {
        lastTriggered = Date()
        triggerCount += 1
    }
    
    func updateSuccessRate(successful: Bool) {
        let newSuccess = successful ? 1.0 : 0.0
        successRate = (successRate * Double(triggerCount - 1) + newSuccess) / Double(triggerCount)
    }
    
    func setConditions<T: Codable>(_ conditions: T) {
        self.conditions = try? JSONEncoder().encode(conditions)
    }
    
    func getConditions<T: Codable>(as type: T.Type) -> T? {
        guard let conditions = conditions else { return nil }
        return try? JSONDecoder().decode(type, from: conditions)
    }
    
    func setActions<T: Codable>(_ actions: T) {
        self.actions = try? JSONEncoder().encode(actions)
    }
    
    func getActions<T: Codable>(as type: T.Type) -> T? {
        guard let actions = actions else { return nil }
        return try? JSONDecoder().decode(type, from: actions)
    }
}

// MARK: - Organization Rule Type
enum OrganizationRuleType: String, CaseIterable, Codable {
    case autoTag = "auto_tag"
    case autoList = "auto_list"
    case autoPriority = "auto_priority"
    case autoSchedule = "auto_schedule"
    case autoArchive = "auto_archive"
    case autoDelegate = "auto_delegate"
    case autoReminder = "auto_reminder"
    case autoCategory = "auto_category"
    
    var displayName: String {
        switch self {
        case .autoTag: return "Auto-Tag"
        case .autoList: return "Auto-List Assignment"
        case .autoPriority: return "Auto-Priority"
        case .autoSchedule: return "Auto-Schedule"
        case .autoArchive: return "Auto-Archive"
        case .autoDelegate: return "Auto-Delegate"
        case .autoReminder: return "Auto-Reminder"
        case .autoCategory: return "Auto-Category"
        }
    }
    
    var description: String {
        switch self {
        case .autoTag: return "Automatically assign tags based on content"
        case .autoList: return "Automatically assign to lists based on criteria"
        case .autoPriority: return "Automatically set priority based on keywords"
        case .autoSchedule: return "Automatically schedule based on patterns"
        case .autoArchive: return "Automatically archive completed items"
        case .autoDelegate: return "Automatically delegate based on content"
        case .autoReminder: return "Automatically create follow-up reminders"
        case .autoCategory: return "Automatically categorize items"
        }
    }
    
    var icon: String {
        switch self {
        case .autoTag: return "tag"
        case .autoList: return "list.bullet"
        case .autoPriority: return "exclamationmark"
        case .autoSchedule: return "calendar"
        case .autoArchive: return "archivebox"
        case .autoDelegate: return "person.2"
        case .autoReminder: return "bell"
        case .autoCategory: return "folder"
        }
    }
}

// MARK: - Quick Action
@Model
final class QuickAction {
    var id: UUID = UUID()
    var userId: String = ""
    var name: String = ""
    var actionDescription: String = ""
    var actionType: QuickActionType = QuickActionType.createReminder
    var icon: String = "plus"
    var shortcut: String = ""
    var isActive: Bool = true
    var order: Int = 0
    var configuration: Data? // JSON encoded action configuration
    var usageCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date()
    
    init(userId: String, name: String, actionType: QuickActionType) {
        self.userId = userId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.actionType = actionType
        self.icon = actionType.defaultIcon
        self.createdAt = Date()
    }
    
    func updateUsage() {
        usageCount += 1
        lastUsed = Date()
    }
    
    func setConfiguration<T: Codable>(_ config: T) {
        configuration = try? JSONEncoder().encode(config)
    }
    
    func getConfiguration<T: Codable>(as type: T.Type) -> T? {
        guard let configuration = configuration else { return nil }
        return try? JSONDecoder().decode(type, from: configuration)
    }
}

// MARK: - Quick Action Type
enum QuickActionType: String, CaseIterable, Codable {
    case createReminder = "create_reminder"
    case createHabit = "create_habit"
    case startFocus = "start_focus"
    case startTimer = "start_timer"
    case voiceNote = "voice_note"
    case quickCapture = "quick_capture"
    case searchAll = "search_all"
    case viewToday = "view_today"
    case viewOverdue = "view_overdue"
    case backup = "backup"
    case sync = "sync"
    case openList = "open_list"
    
    var displayName: String {
        switch self {
        case .createReminder: return "Create Reminder"
        case .createHabit: return "Create Habit"
        case .startFocus: return "Start Focus Session"
        case .startTimer: return "Start Timer"
        case .voiceNote: return "Voice Note"
        case .quickCapture: return "Quick Capture"
        case .searchAll: return "Search All"
        case .viewToday: return "View Today"
        case .viewOverdue: return "View Overdue"
        case .backup: return "Backup Data"
        case .sync: return "Sync Data"
        case .openList: return "Open List"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .createReminder: return "plus.circle"
        case .createHabit: return "repeat.circle"
        case .startFocus: return "target"
        case .startTimer: return "timer"
        case .voiceNote: return "mic.circle"
        case .quickCapture: return "camera.circle"
        case .searchAll: return "magnifyingglass.circle"
        case .viewToday: return "calendar.circle"
        case .viewOverdue: return "exclamationmark.triangle"
        case .backup: return "icloud.and.arrow.up"
        case .sync: return "arrow.triangle.2.circlepath"
        case .openList: return "list.bullet.circle"
        }
    }
}

// MARK: - Search Analytics
@Model
final class SearchAnalytics {
    var id: UUID = UUID()
    var userId: String = ""
    var date: Date = Date()
    var totalSearches: Int = 0
    var successfulSearches: Int = 0
    var averageResultCount: Double = 0.0
    var averageExecutionTime: TimeInterval = 0.0
    var topSearchTerms: [String] = []
    var topResultTypes: [String] = []
    var mostUsedFilters: [String] = []
    var searchSuccessRate: Double = 0.0
    var userSatisfactionScore: Double = 0.0
    
    init(userId: String, date: Date = Date()) {
        self.userId = userId
        self.date = Calendar.current.startOfDay(for: date)
    }
    
    func updateMetrics(
        totalSearches: Int,
        successfulSearches: Int,
        avgResults: Double,
        avgTime: TimeInterval,
        topTerms: [String],
        topTypes: [String],
        topFilters: [String]
    ) {
        self.totalSearches = totalSearches
        self.successfulSearches = successfulSearches
        self.averageResultCount = avgResults
        self.averageExecutionTime = avgTime
        self.topSearchTerms = topTerms
        self.topResultTypes = topTypes
        self.mostUsedFilters = topFilters
        
        searchSuccessRate = totalSearches > 0 ? Double(successfulSearches) / Double(totalSearches) : 0.0
    }
}
