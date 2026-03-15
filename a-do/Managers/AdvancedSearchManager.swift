//
//  AdvancedSearchManager.swift
//  a-do
//
//  Advanced search and organization manager
//

import Foundation
import SwiftData
import Observation
import Combine
import os
import NaturalLanguage

@MainActor
@Observable
final class AdvancedSearchManager: ObservableObject {
    static let shared = AdvancedSearchManager()
    
    private let logger = Logger(subsystem: "a-do", category: "AdvancedSearch")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Search state
    var isSearching: Bool = false
    var currentQuery: String = ""
    var searchResults: [SearchResult] = []
    var searchSuggestions: [String] = []
    var recentSearches: [SearchQuery] = []
    
    // Configuration
    private var configuration: SearchConfiguration?
    
    // Search index
    private var searchIndex: [SearchIndex] = []
    private var lastIndexUpdate: Date?
    private var isIndexDirty = true
    private let indexRefreshInterval: TimeInterval = 6 * 3600
    
    // Organization rules
    private var organizationRules: [OrganizationRule] = []
    
    // Quick actions
    private var quickActions: [QuickAction] = []
    
    private init() {}
    
    // MARK: - Configuration Management
    
    func getConfiguration(userId: String, context: ModelContext) -> SearchConfiguration {
        if let config = configuration, config.userId == userId {
            return config
        }
        
        let descriptor = FetchDescriptor<SearchConfiguration>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingConfig = try? context.fetch(descriptor).first {
            configuration = existingConfig
            return existingConfig
        }
        
        // Create default configuration
        let newConfig = SearchConfiguration(userId: userId)
        context.insert(newConfig)
        
        do {
            try context.save()
            configuration = newConfig
            logger.info("Created search configuration for user: \(userId)")
        } catch {
            logger.error("Failed to create search configuration: \(error.localizedDescription)")
        }
        
        return newConfig
    }
    
    // MARK: - Search Operations

    func search(
        query: String,
        type: SearchType = .text,
        scope: SearchScope = .all,
        filters: [SearchFilter] = [],
        sortOrder: SearchSortOrder = .relevance,
        userId: String,
        context: ModelContext
    ) async -> [SearchResult] {
        guard isProEnabled else {
            logger.warning("Advanced search is a Pro feature")
            return []
        }

        // Validate and sanitize search query
        guard let sanitizedQuery = SecurityUtils.sanitizeTextInput(query) else {
            logger.warning("Invalid search query rejected")
            return []
        }
        
        // Rate limiting for search operations
        let rateLimitKey = "search_\(userId)"
        guard SecurityUtils.isWithinRateLimit(key: rateLimitKey, maxAttempts: 50, timeWindow: 60) else {
            logger.warning("Search rate limit exceeded for user: \(userId)")
            return []
        }
        
        isSearching = true
        currentQuery = sanitizedQuery
        
        defer {
            isSearching = false
        }
        
        let startTime = Date()
        
        logger.info("Starting search: '\(query)' type: \(type.rawValue) scope: \(scope.rawValue)")
        
        // Validate user ID before creating search query
        guard SecurityUtils.isValidUserID(userId) else {
            logger.error("Invalid user ID format rejected: \(userId)")
            return []
        }
        
        // Create search query record with sanitized input
        let searchQuery = SearchQuery(userId: userId, query: sanitizedQuery, searchType: type)
        searchQuery.scope = scope
        searchQuery.sortOrder = sortOrder
        
        if !filters.isEmpty {
            searchQuery.setFilters(filters.map { $0.id.uuidString })
        }
        
        context.insert(searchQuery)
        
        var results: [SearchResult] = []
        
        switch type {
        case .text:
            results = await performTextSearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        case .fuzzy:
            results = await performFuzzySearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        case .semantic:
            results = await performSemanticSearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        case .voice:
            results = await performVoiceSearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        case .regex:
            results = await performRegexSearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        case .advanced:
            results = await performAdvancedSearch(query: sanitizedQuery, scope: scope, filters: filters, context: context)
        }
        
        // Apply sorting
        results = sortResults(results, by: sortOrder)
        
        // Update search query with results
        let executionTime = Date().timeIntervalSince(startTime)
        searchQuery.updateUsage(resultCount: results.count, executionTime: executionTime)
        
        // Keep result rows in memory. Persisting every transient search result causes
        // unnecessary database growth and slows down repeated searches.
        for result in results {
            result.queryId = searchQuery.id
        }
        
        do {
            try context.save()
            logger.info("Search completed: \(results.count) results in \(String(format: "%.3f", executionTime))s")
        } catch {
            logger.error("Failed to save search results: \(error.localizedDescription)")
        }
        
        // Update recent searches
        await updateRecentSearches(searchQuery, context: context)
        
        searchResults = results
        return results
    }
    
    // MARK: - Text Search
    
    private func performTextSearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        context: ModelContext
    ) async -> [SearchResult] {
        var results: [SearchResult] = []
        let lowercaseQuery = query.lowercased()
        async let reminderSnapshots: [SearchableReminderSnapshot] = shouldSearchReminders(in: scope)
            ? MemorySafeDataLoader.loadSearchableReminders(context: context)
            : []
        async let habitSnapshots: [SearchableHabitSnapshot] = shouldSearchHabits(in: scope)
            ? MemorySafeDataLoader.loadSearchableHabits(context: context)
            : []
        async let tagSnapshots: [SearchableTagSnapshot] = shouldSearchTags(in: scope)
            ? MemorySafeDataLoader.loadSearchableTags(context: context)
            : []
        async let listSnapshots: [SearchableListSnapshot] = shouldSearchLists(in: scope)
            ? MemorySafeDataLoader.loadSearchableLists(context: context)
            : []

        let reminders = await reminderSnapshots
        let habits = await habitSnapshots
        let tags = await tagSnapshots
        let lists = await listSnapshots

        if !reminders.isEmpty {
            results.append(contentsOf: searchReminders(query: lowercaseQuery, scope: scope, reminders: reminders))
        }

        if !habits.isEmpty {
            results.append(contentsOf: searchHabits(query: lowercaseQuery, habits: habits))
        }

        if !tags.isEmpty {
            results.append(contentsOf: searchTags(query: lowercaseQuery, tags: tags))
        }

        if !lists.isEmpty {
            results.append(contentsOf: searchLists(query: lowercaseQuery, lists: lists))
        }
        
        // Apply filters
        results = applyFilters(results, filters: filters, context: context)
        
        return results
    }
    
    private func searchReminders(
        query: String,
        scope: SearchScope,
        reminders: [SearchableReminderSnapshot]
    ) -> [SearchResult] {
        reminders.compactMap { reminder in
            guard matchesReminderScope(reminder, scope: scope) else { return nil }
            guard reminder.title.localizedCaseInsensitiveContains(query)
                || reminder.details.localizedCaseInsensitiveContains(query) else {
                return nil
            }

            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: reminder.title,
                content: reminder.details
            )

            let snippet = createSnippet(
                query: query,
                content: reminder.details.isEmpty ? reminder.title : reminder.details,
                maxLength: 150
            )

            let result = SearchResult(
                queryId: UUID(),
                itemType: SearchResultType.reminder,
                itemId: reminder.id,
                title: reminder.title,
                snippet: snippet,
                relevanceScore: relevanceScore
            )

            result.matchType = determineMatchType(query: query, text: reminder.title)
            result.matchedFields = try? JSONEncoder().encode(
                getMatchedFields(query: query, title: reminder.title, details: reminder.details)
            )
            return result
        }
    }
    
    private func searchHabits(query: String, habits: [SearchableHabitSnapshot]) -> [SearchResult] {
        habits.compactMap { habit in
            guard habit.title.localizedCaseInsensitiveContains(query)
                || habit.details.localizedCaseInsensitiveContains(query) else {
                return nil
            }

            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: habit.title,
                content: habit.details
            )
            
            let snippet = createSnippet(
                query: query,
                content: habit.details.isEmpty ? habit.title : habit.details,
                maxLength: 150
            )
            
            let result = SearchResult(
                queryId: UUID(),
                itemType: SearchResultType.habit,
                itemId: habit.id,
                title: habit.title,
                snippet: snippet,
                relevanceScore: relevanceScore
            )
            
            result.matchType = determineMatchType(query: query, text: habit.title)
            
            return result
        }
    }
    
    private func searchTags(query: String, tags: [SearchableTagSnapshot]) -> [SearchResult] {
        tags.compactMap { tag in
            guard tag.name.localizedCaseInsensitiveContains(query) else { return nil }
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: tag.name,
                content: ""
            )
            
            let result = SearchResult(
                queryId: UUID(),
                itemType: SearchResultType.tag,
                itemId: tag.id,
                title: tag.name,
                snippet: "Tag with \(tag.reminderCount) reminders",
                relevanceScore: relevanceScore
            )
            
            result.matchType = determineMatchType(query: query, text: tag.name)
            
            return result
        }
    }
    
    private func searchLists(query: String, lists: [SearchableListSnapshot]) -> [SearchResult] {
        lists.compactMap { list in
            guard list.name.localizedCaseInsensitiveContains(query) else { return nil }
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: list.name,
                content: ""
            )
            
            let result = SearchResult(
                queryId: UUID(),
                itemType: SearchResultType.list,
                itemId: list.id,
                title: list.name,
                snippet: "List with \(list.reminderCount) reminders",
                relevanceScore: relevanceScore
            )
            
            result.matchType = determineMatchType(query: query, text: list.name)
            
            return result
        }
    }
    
    // MARK: - Fuzzy Search
    
    private func performFuzzySearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        context: ModelContext
    ) async -> [SearchResult] {
        // Implement fuzzy search using Levenshtein distance or similar algorithm
        let results = await performTextSearch(query: query, scope: scope, filters: filters, context: context)
        
        // Apply fuzzy matching to expand results
        let fuzzyResults = results.filter { result in
            let distance = levenshteinDistance(query.lowercased(), result.title.lowercased())
            let threshold = max(1, query.count / 3) // Allow up to 1/3 character differences
            return distance <= threshold
        }
        
        return fuzzyResults.map { result in
            result.matchType = .fuzzy
            return result
        }
    }
    
    // MARK: - Semantic Search
    
    private func performSemanticSearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        context: ModelContext
    ) async -> [SearchResult] {
        // Use Natural Language framework for semantic analysis
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        
        var results: [SearchResult] = []
        
        // Get semantic similarity for reminders
        if shouldSearchReminders(in: scope) {
            let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
            
            for reminder in reminders {
                guard matchesReminderScope(reminder, scope: scope) else { continue }
                let similarity = calculateSemanticSimilarity(
                    query: query,
                    text: reminder.title + " " + reminder.details,
                    embedding: embedding
                )
                
                if similarity > 0.3 { // Threshold for semantic relevance
                    let result = SearchResult(
                        queryId: UUID(),
                        itemType: SearchResultType.reminder,
                        itemId: reminder.id,
                        title: reminder.title,
                        snippet: createSnippet(query: query, content: reminder.details, maxLength: 150),
                        relevanceScore: similarity
                    )
                    result.matchType = SearchMatchType.semantic
                    results.append(result)
                }
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Voice Search
    
    private func performVoiceSearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        context: ModelContext
    ) async -> [SearchResult] {
        // Voice search would typically involve speech-to-text conversion
        // For now, we'll treat it as enhanced text search with phonetic matching
        
        let textResults = await performTextSearch(query: query, scope: scope, filters: filters, context: context)
        
        // Add phonetic matching for voice queries
        let phoneticResults = textResults.filter { result in
            isPhoneticMatch(query, result.title)
        }
        
        return phoneticResults.map { result in
            result.matchType = .phonetic
            return result
        }
    }
    
    // MARK: - Regex Search
    
    private func performRegexSearch(query: String, scope: SearchScope, filters: [SearchFilter], context: ModelContext) async -> [SearchResult] {
        // Regex search implementation
        var results: [SearchResult] = []
        
        do {
            let regex = try NSRegularExpression(pattern: query, options: [.caseInsensitive])
            async let reminderSnapshots: [SearchableReminderSnapshot] = shouldSearchReminders(in: scope)
                ? MemorySafeDataLoader.loadSearchableReminders(context: context)
                : []
            async let habitSnapshots: [SearchableHabitSnapshot] = shouldSearchHabits(in: scope)
                ? MemorySafeDataLoader.loadSearchableHabits(context: context)
                : []
            let reminders = await reminderSnapshots
            let habits = await habitSnapshots
            
            // Search in reminders
            if shouldSearchReminders(in: scope) {
                for reminder in reminders {
                    guard matchesReminderScope(reminder, scope: scope) else { continue }
                    if matchesRegex(regex, in: reminder.title) ||
                       matchesRegex(regex, in: reminder.details) {
                        results.append(SearchResult(
                            queryId: UUID(),
                            itemType: .reminder,
                            itemId: reminder.id,
                            title: reminder.title,
                            snippet: reminder.details,
                            relevanceScore: 0.8
                        ))
                    }
                }
            }
            
            // Search in habits
            if shouldSearchHabits(in: scope) {
                for habit in habits {
                    if matchesRegex(regex, in: habit.title) ||
                       matchesRegex(regex, in: habit.details) {
                        results.append(SearchResult(
                            queryId: UUID(),
                            itemType: .habit,
                            itemId: habit.id,
                            title: habit.title,
                            snippet: habit.details,
                            relevanceScore: 0.8
                        ))
                    }
                }
            }
            
        } catch {
            // If regex is invalid, fall back to text search
            return await performTextSearch(query: query, scope: scope, filters: filters, context: context)
        }
        
        return results
    }
    
    private func matchesRegex(_ regex: NSRegularExpression, in text: String) -> Bool {
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    // MARK: - Advanced Search
    
    private func performAdvancedSearch(
        query: String,
        scope: SearchScope,
        filters: [SearchFilter],
        context: ModelContext
    ) async -> [SearchResult] {
        // Parse advanced search syntax (e.g., "title:meeting AND priority:high")
        let searchTerms = parseAdvancedQuery(query)
        var results: [SearchResult] = []
        
        // Apply each search term
        for term in searchTerms {
            let termResults = await executeAdvancedTerm(term, scope: scope, context: context)
            
            if results.isEmpty {
                results = termResults
            } else {
                // Combine results based on operator (AND/OR)
                results = combineResults(results, termResults, operator: term.searchOperator)
            }
        }
        
        return applyFilters(results, filters: filters, context: context)
    }
    
    // MARK: - Search Suggestions
    
    func generateSearchSuggestions(partialQuery: String, userId: String, context: ModelContext) async -> [String] {
        guard partialQuery.count >= 2 else { return [] }
        
        var suggestions: [String] = []
        
        // Get suggestions from recent searches
        let recentSuggestions = await getRecentSearchSuggestions(partialQuery: partialQuery, userId: userId, context: context)
        suggestions.append(contentsOf: recentSuggestions)
        
        // Get suggestions from content
        let contentSuggestions = await getContentSuggestions(partialQuery: partialQuery, context: context)
        suggestions.append(contentsOf: contentSuggestions)
        
        // Remove duplicates and limit
        suggestions = Array(Set(suggestions)).sorted()
        return Array(suggestions.prefix(10))
    }
    
    private func getRecentSearchSuggestions(partialQuery: String, userId: String, context: ModelContext) async -> [String] {
        let descriptor = FetchDescriptor<SearchQuery>(
            predicate: #Predicate<SearchQuery> { query in
                query.userId == userId && query.query.contains(partialQuery)
            },
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )
        
        let queries = (try? context.fetch(descriptor)) ?? []
        return Array(queries.prefix(5).map { $0.query })
    }
    
    private func getContentSuggestions(partialQuery: String, context: ModelContext) async -> [String] {
        var suggestions: [String] = []
        async let reminderSnapshots = MemorySafeDataLoader.loadSearchableReminders(context: context, limit: 200)
        async let tagSnapshots = MemorySafeDataLoader.loadSearchableTags(context: context, limit: 100)
        let reminders = await reminderSnapshots
        let tags = await tagSnapshots

        suggestions.append(
            contentsOf: reminders
                .filter { $0.title.localizedCaseInsensitiveContains(partialQuery) }
                .prefix(3)
                .map(\.title)
        )
        suggestions.append(
            contentsOf: tags
                .filter { $0.name.localizedCaseInsensitiveContains(partialQuery) }
                .prefix(3)
                .map(\.name)
        )
        
        return suggestions
    }
    
    // MARK: - Search Index Management
    
    func markIndexDirty() {
        isIndexDirty = true
    }

    func upsertReminderIndex(for reminder: Reminder, context: ModelContext) async {
        let itemId = reminder.uuid.uuidString
        let content = [
            reminder.title,
            reminder.details ?? "",
            (reminder.tags ?? []).map(\.name).joined(separator: " ")
        ]
            .joined(separator: " ")

        await upsertSearchIndex(
            itemType: .reminder,
            itemId: itemId,
            content: content,
            container: context.container
        )
    }

    func removeReminderIndex(for reminder: Reminder, context: ModelContext) async {
        await removeSearchIndex(
            itemType: .reminder,
            itemId: reminder.uuid.uuidString,
            container: context.container
        )
    }

    func upsertHabitIndex(for habit: Habit, context: ModelContext) async {
        await upsertSearchIndex(
            itemType: .habit,
            itemId: habit.id.uuidString,
            content: [habit.title, habit.habitDescription].joined(separator: " "),
            container: context.container
        )
    }

    func removeHabitIndex(for habit: Habit, context: ModelContext) async {
        await removeSearchIndex(
            itemType: .habit,
            itemId: habit.id.uuidString,
            container: context.container
        )
    }

    func removeHabitIndex(itemId: String, context: ModelContext) async {
        await removeSearchIndex(
            itemType: .habit,
            itemId: itemId,
            container: context.container
        )
    }

    private func upsertSearchIndex(
        itemType: SearchResultType,
        itemId: String,
        content: String,
        container: ModelContainer
    ) async {
        let itemTypeRaw = itemType.rawValue
        let didSave = await Task.detached(priority: .utility) {
            let backgroundContext = ModelContext(container)
            let descriptor = FetchDescriptor<SearchIndex>(
                predicate: #Predicate<SearchIndex> { index in
                    index.itemTypeRaw == itemTypeRaw && index.itemId == itemId
                }
            )

            if let existingIndex = try? backgroundContext.fetch(descriptor).first {
                existingIndex.updateContent(content)
                existingIndex.isActive = true
            } else {
                backgroundContext.insert(
                    SearchIndex(
                        itemType: itemType,
                        itemId: itemId,
                        content: content
                    )
                )
            }

            do {
                try backgroundContext.save()
                return true
            } catch {
                return false
            }
        }.value

        if didSave {
            isIndexDirty = false
            lastIndexUpdate = Date()
        } else {
            markIndexDirty()
        }
    }

    private func removeSearchIndex(
        itemType: SearchResultType,
        itemId: String,
        container: ModelContainer
    ) async {
        let itemTypeRaw = itemType.rawValue
        let didSave = await Task.detached(priority: .utility) {
            let backgroundContext = ModelContext(container)
            let descriptor = FetchDescriptor<SearchIndex>(
                predicate: #Predicate<SearchIndex> { index in
                    index.itemTypeRaw == itemTypeRaw && index.itemId == itemId
                }
            )

            let indexes = (try? backgroundContext.fetch(descriptor)) ?? []
            for index in indexes {
                backgroundContext.delete(index)
            }

            do {
                try backgroundContext.save()
                return true
            } catch {
                return false
            }
        }.value

        if didSave {
            lastIndexUpdate = Date()
        } else {
            markIndexDirty()
        }
    }

    func refreshIndexIfNeeded(context: ModelContext, reason: String, force: Bool = false) async {
        let isStale = lastIndexUpdate.map { Date().timeIntervalSince($0) >= indexRefreshInterval } ?? true
        guard force || isIndexDirty || isStale else { return }
        logger.info("Refreshing search index for \(reason, privacy: .public)")
        await rebuildSearchIndex(context: context)
    }
    
    func rebuildSearchIndex(context: ModelContext) async {
        logger.info("Rebuilding search index")
        let container = context.container

        let rebuildCount = await Task.detached(priority: .utility) { () -> Int in
            let backgroundContext = ModelContext(container)

            let indexDescriptor = FetchDescriptor<SearchIndex>()
            let existingIndexes = (try? backgroundContext.fetch(indexDescriptor)) ?? []
            for index in existingIndexes {
                backgroundContext.delete(index)
            }

            let reminderDescriptor = FetchDescriptor<Reminder>()
            let reminders = (try? backgroundContext.fetch(reminderDescriptor)) ?? []
            var rebuiltCount = 0

            for reminder in reminders {
                let index = SearchIndex(
                    itemType: SearchResultType.reminder,
                    itemId: reminder.uuid.uuidString,
                    content: reminder.title + " " + (reminder.details ?? "")
                )
                backgroundContext.insert(index)
                rebuiltCount += 1
            }

            let habitDescriptor = FetchDescriptor<Habit>()
            let habits = (try? backgroundContext.fetch(habitDescriptor)) ?? []

            for habit in habits {
                let index = SearchIndex(
                    itemType: SearchResultType.habit,
                    itemId: habit.id.uuidString,
                    content: habit.title + " " + habit.habitDescription
                )
                backgroundContext.insert(index)
                rebuiltCount += 1
            }

            do {
                try backgroundContext.save()
            } catch {
                return -1
            }

            return rebuiltCount
        }.value

        guard rebuildCount >= 0 else {
            logger.error("Failed to rebuild search index")
            return
        }

        searchIndex = (try? context.fetch(FetchDescriptor<SearchIndex>())) ?? []
        lastIndexUpdate = Date()
        isIndexDirty = false
        logger.info("Search index rebuilt successfully")
    }
    
    // MARK: - Organization Rules
    
    func applyOrganizationRules(for item: Any, context: ModelContext) async {
        let activeRules = organizationRules.filter { $0.isActive }.sorted { $0.priority > $1.priority }
        
        for rule in activeRules {
            if await shouldApplyRule(rule, to: item) {
                await executeRule(rule, on: item, context: context)
                rule.trigger()
            }
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to apply organization rules: \(error.localizedDescription)")
        }
    }
    
    private func shouldApplyRule(_ rule: OrganizationRule, to item: Any) async -> Bool {
        // No conditions means the rule applies to every compatible item.
        guard let conditionData = rule.conditions, !conditionData.isEmpty else { return true }
        
        // Supported JSON shape:
        // [{"field":"title","operator":"contains","value":"meeting"}]
        // or {"field":"title","operator":"contains","value":"meeting"}
        if let conditions = try? JSONDecoder().decode([OrganizationRuleCondition].self, from: conditionData) {
            return conditions.allSatisfy { evaluateRuleCondition($0, item: item) }
        }
        
        if let condition = try? JSONDecoder().decode(OrganizationRuleCondition.self, from: conditionData) {
            return evaluateRuleCondition(condition, item: item)
        }
        
        // If conditions cannot be decoded, fail closed.
        return false
    }
    
    private func executeRule(_ rule: OrganizationRule, on item: Any, context: ModelContext) async {
        guard let reminder = item as? Reminder else {
            logger.info("Skipping organization rule \(rule.name) for unsupported item type")
            return
        }
        
        switch rule.ruleType {
        case .autoTag:
            let tagName = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tagName.isEmpty else { return }
            
            let tagDescriptor = FetchDescriptor<Tag>(
                predicate: #Predicate<Tag> { tag in
                    tag.name == tagName
                }
            )
            
            let tag = (try? context.fetch(tagDescriptor).first) ?? Tag(name: tagName)
            if (try? context.fetch(tagDescriptor).first) == nil {
                context.insert(tag)
            }
            
            var existingTags = reminder.tags ?? []
            if !existingTags.contains(where: { $0.name.caseInsensitiveCompare(tagName) == .orderedSame }) {
                existingTags.append(tag)
                reminder.tags = existingTags
            }
            
        case .autoList:
            guard !rule.name.isEmpty else { return }
            let listName = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let listDescriptor = FetchDescriptor<ReminderList>(
                predicate: #Predicate<ReminderList> { list in
                    list.name == listName
                }
            )
            
            if let list = try? context.fetch(listDescriptor).first {
                reminder.list = list
            }
            
        case .autoPriority:
            let lowered = rule.ruleDescription.lowercased()
            if lowered.contains("high") {
                reminder.priority = .high
            } else if lowered.contains("medium") {
                reminder.priority = .medium
            } else if lowered.contains("low") {
                reminder.priority = .low
            }
            
        case .autoSchedule:
            guard reminder.dueDate == nil else { break }
            // Apply a conservative default schedule only when missing.
            reminder.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            
        case .autoArchive:
            if reminder.isCompleted {
                reminder.list = nil
            }
            
        case .autoDelegate, .autoReminder, .autoCategory:
            // These require data models not currently present in this repository.
            break
        }
        
        logger.info("Executed organization rule: \(rule.name)")
    }
    
    // MARK: - Helper Methods
    
    private func calculateRelevanceScore(query: String, title: String, content: String) -> Double {
        let lowercaseQuery = query.lowercased()
        let lowercaseTitle = title.lowercased()
        let lowercaseContent = content.lowercased()
        
        var score = 0.0
        
        // Exact title match gets highest score
        if lowercaseTitle == lowercaseQuery {
            score += 1.0
        } else if lowercaseTitle.contains(lowercaseQuery) {
            score += 0.8
        }
        
        // Content match gets lower score
        if lowercaseContent.contains(lowercaseQuery) {
            score += 0.4
        }
        
        // Word boundary matches get bonus
        if lowercaseTitle.range(of: "\\b\(lowercaseQuery)\\b", options: .regularExpression) != nil {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    private func createSnippet(query: String, content: String, maxLength: Int) -> String {
        guard !content.isEmpty else { return "" }
        
        let lowercaseQuery = query.lowercased()
        let lowercaseContent = content.lowercased()
        
        // Find the position of the query in the content
        if let range = lowercaseContent.range(of: lowercaseQuery) {
            let startIndex = max(content.startIndex, content.index(range.lowerBound, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex)
            let endIndex = min(content.endIndex, content.index(range.upperBound, offsetBy: 50, limitedBy: content.endIndex) ?? content.endIndex)
            
            var snippet = String(content[startIndex..<endIndex])
            
            if snippet.count > maxLength {
                snippet = String(snippet.prefix(maxLength)) + "..."
            }
            
            return snippet
        }
        
        // If query not found, return beginning of content
        return String(content.prefix(maxLength)) + (content.count > maxLength ? "..." : "")
    }
    
    private func determineMatchType(query: String, text: String) -> SearchMatchType {
        let lowercaseQuery = query.lowercased()
        let lowercaseText = text.lowercased()
        
        if lowercaseText == lowercaseQuery {
            return .exact
        } else if lowercaseText.contains(lowercaseQuery) {
            return .partial
        } else {
            return .fuzzy
        }
    }
    
    private func getMatchedFields(query: String, reminder: Reminder) -> [String] {
        getMatchedFields(query: query, title: reminder.title, details: reminder.details ?? "")
    }

    private func getMatchedFields(query: String, title: String, details: String) -> [String] {
        var fields: [String] = []
        
        if title.localizedStandardContains(query) {
            fields.append("title")
        }
        
        if details.localizedStandardContains(query) {
            fields.append("details")
        }
        
        return fields
    }

    private func shouldSearchReminders(in scope: SearchScope) -> Bool {
        scope == .all || scope == .reminders || scope == .active || scope == .overdue || scope == .completed
    }

    private func shouldSearchHabits(in scope: SearchScope) -> Bool {
        scope == .all || scope == .habits
    }

    private func shouldSearchTags(in scope: SearchScope) -> Bool {
        scope == .all || scope == .tags
    }

    private func shouldSearchLists(in scope: SearchScope) -> Bool {
        scope == .all || scope == .lists
    }

    private func matchesReminderScope(_ reminder: SearchableReminderSnapshot, scope: SearchScope) -> Bool {
        switch scope {
        case .active:
            return !reminder.isCompleted
        case .overdue:
            return reminder.isOverdue
        case .completed:
            return reminder.isCompleted
        default:
            return true
        }
    }
    
    private func sortResults(_ results: [SearchResult], by sortOrder: SearchSortOrder) -> [SearchResult] {
        switch sortOrder {
        case .relevance:
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        case .alphabetical:
            return results.sorted { $0.title < $1.title }
        case .dateCreated, .dateModified, .dueDate, .priority, .usage:
            // These would require additional data from the original items
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        }
    }
    
    private func applyFilters(_ results: [SearchResult], filters: [SearchFilter], context: ModelContext) -> [SearchResult] {
        let activeFilters = filters.filter(\.isActive)
        guard !activeFilters.isEmpty else { return results }
        
        return results.filter { result in
            activeFilters.allSatisfy { filter in
                evaluateSearchFilter(filter, for: result, context: context)
            }
        }
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,
                        matrix[i][j-1] + 1,
                        matrix[i-1][j-1] + 1
                    )
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    private func calculateSemanticSimilarity(query: String, text: String, embedding: NLEmbedding?) -> Double {
        let queryTokens = tokenizeForSimilarity(query)
        let textTokens = tokenizeForSimilarity(text)
        
        guard !queryTokens.isEmpty, !textTokens.isEmpty else { return 0.0 }
        
        let overlapScore = jaccardSimilarity(queryTokens, textTokens)
        
        guard let embedding else {
            return overlapScore
        }
        
        // Compute mean of best token-to-token semantic similarities.
        let semanticComponents: [Double] = queryTokens.compactMap { queryToken in
            let best = textTokens.compactMap { token in
                embedding.distance(between: queryToken, and: token)
            }
            .map { distance in max(0.0, 1.0 - distance) }
            .max()
            
            return best
        }
        
        let semanticScore = semanticComponents.isEmpty
            ? 0.0
            : semanticComponents.reduce(0, +) / Double(semanticComponents.count)
        
        let phraseBonus = text.localizedCaseInsensitiveContains(query) ? 0.15 : 0.0
        return min(1.0, max(0.0, semanticScore * 0.7 + overlapScore * 0.3 + phraseBonus))
    }
    
    private func isPhoneticMatch(_ query: String, _ text: String) -> Bool {
        // Implement phonetic matching algorithm (e.g., Soundex, Metaphone)
        return levenshteinDistance(query.lowercased(), text.lowercased()) <= 2
    }
    
    private func parseAdvancedQuery(_ query: String) -> [AdvancedSearchTerm] {
        let tokens = tokenizeAdvancedQuery(query)
        guard !tokens.isEmpty else { return [] }
        
        var terms: [AdvancedSearchTerm] = []
        var pendingOperator: AdvancedSearchOperator = .and
        
        for token in tokens {
            let normalized = token.uppercased()
            if normalized == "AND" {
                pendingOperator = .and
                continue
            }
            if normalized == "OR" {
                pendingOperator = .or
                continue
            }
            if normalized == "NOT" {
                pendingOperator = .not
                continue
            }
            
            let cleanedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedToken.isEmpty else { continue }
            
            let fieldValue = cleanedToken.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if fieldValue.count == 2 {
                let field = String(fieldValue[0]).lowercased()
                let value = stripWrappingQuotes(String(fieldValue[1]))
                terms.append(AdvancedSearchTerm(field: field, searchOperator: pendingOperator, value: value))
            } else {
                terms.append(AdvancedSearchTerm(field: "any", searchOperator: pendingOperator, value: stripWrappingQuotes(cleanedToken)))
            }
            
            pendingOperator = .and
        }
        
        return terms
    }
    
    private func executeAdvancedTerm(_ term: AdvancedSearchTerm, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        let normalizedValue = term.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else { return [] }
        
        switch term.field {
        case "title":
            return await executeAdvancedTextFieldSearch(
                value: normalizedValue,
                scope: scope,
                context: context
            ) { reminder, habit in
                reminder?.title.localizedCaseInsensitiveContains(normalizedValue) == true ||
                habit?.title.localizedCaseInsensitiveContains(normalizedValue) == true
            }
            
        case "details", "description", "content":
            return await executeAdvancedTextFieldSearch(
                value: normalizedValue,
                scope: scope,
                context: context
            ) { reminder, habit in
                reminder?.details.localizedCaseInsensitiveContains(normalizedValue) == true ||
                habit?.details.localizedCaseInsensitiveContains(normalizedValue) == true
            }
            
        case "priority":
            return await executePrioritySearch(value: normalizedValue, scope: scope, context: context)
            
        case "status":
            return await executeStatusSearch(value: normalizedValue, scope: scope, context: context)
            
        case "due", "duedate":
            return await executeDueDateSearch(value: normalizedValue, scope: scope, context: context)
            
        case "tag", "tags":
            return await executeTagSearch(value: normalizedValue, scope: scope, context: context)
            
        case "list", "listname":
            return await executeListSearch(value: normalizedValue, scope: scope, context: context)
            
        default:
            return await performTextSearch(
                query: normalizedValue,
                scope: scope,
                filters: [],
                context: context
            )
        }
    }
    
    private func combineResults(_ results1: [SearchResult], _ results2: [SearchResult], operator searchOperator: AdvancedSearchOperator) -> [SearchResult] {
        switch searchOperator {
        case .and:
            return results1.filter { result1 in
                results2.contains { result2 in result1.itemId == result2.itemId }
            }
        case .or:
            var combined = results1
            for result2 in results2 {
                if !combined.contains(where: { $0.itemId == result2.itemId }) {
                    combined.append(result2)
                }
            }
            return combined
        case .not:
            return results1.filter { result1 in
                !results2.contains { result2 in result1.itemId == result2.itemId }
            }
        }
    }
    
    private func updateRecentSearches(_ searchQuery: SearchQuery, context: ModelContext) async {
        let userId = searchQuery.userId
        let descriptor = FetchDescriptor<SearchQuery>(
            predicate: #Predicate<SearchQuery> { query in
                query.userId == userId
            },
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )
        
        let queries = (try? context.fetch(descriptor)) ?? []
        recentSearches = Array(queries.prefix(20))
    }
    
    // MARK: - Advanced Search Helpers
    
    private struct OrganizationRuleCondition: Codable {
        let field: String
        let `operator`: String
        let value: String
    }
    
    private struct DateRangeFilterConfiguration: Codable {
        let startDate: Date?
        let endDate: Date?
        let field: String?
    }
    
    private struct PriorityFilterConfiguration: Codable {
        let priorities: [Int]?
        let minimum: Int?
        let maximum: Int?
    }
    
    private struct StatusFilterConfiguration: Codable {
        let values: [String]?
    }
    
    private struct StringSetFilterConfiguration: Codable {
        let values: [String]?
    }
    
    private func evaluateRuleCondition(_ condition: OrganizationRuleCondition, item: Any) -> Bool {
        if let reminder = item as? Reminder {
            return evaluateConditionForReminder(condition, reminder: reminder)
        }
        
        if let habit = item as? Habit {
            return evaluateConditionForHabit(condition, habit: habit)
        }
        
        return false
    }
    
    private func evaluateConditionForReminder(_ condition: OrganizationRuleCondition, reminder: Reminder) -> Bool {
        let value = condition.value.lowercased()
        let op = condition.operator.lowercased()
        
        switch condition.field.lowercased() {
        case "title":
            return compare(reminder.title.lowercased(), op: op, value: value)
        case "details":
            return compare((reminder.details ?? "").lowercased(), op: op, value: value)
        case "priority":
            return compare(reminder.priority.title.lowercased(), op: op, value: value)
        case "completed":
            return compare(String(reminder.isCompleted), op: op, value: value)
        default:
            return false
        }
    }
    
    private func evaluateConditionForHabit(_ condition: OrganizationRuleCondition, habit: Habit) -> Bool {
        let value = condition.value.lowercased()
        let op = condition.operator.lowercased()
        
        switch condition.field.lowercased() {
        case "title":
            return compare(habit.title.lowercased(), op: op, value: value)
        case "description":
            return compare(habit.habitDescription.lowercased(), op: op, value: value)
        case "active":
            return compare(String(habit.isActive), op: op, value: value)
        default:
            return false
        }
    }
    
    private func compare(_ lhs: String, op: String, value: String) -> Bool {
        switch op {
        case "equals", "==":
            return lhs == value
        case "contains":
            return lhs.contains(value)
        case "startswith":
            return lhs.hasPrefix(value)
        case "endswith":
            return lhs.hasSuffix(value)
        case "not_equals", "!=":
            return lhs != value
        default:
            return false
        }
    }
    
    private func evaluateSearchFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        switch filter.filterType {
        case .dateRange:
            return evaluateDateRangeFilter(filter, for: result, context: context)
        case .priority:
            return evaluatePriorityFilter(filter, for: result, context: context)
        case .status:
            return evaluateStatusFilter(filter, for: result, context: context)
        case .tags:
            return evaluateTagFilter(filter, for: result, context: context)
        case .lists:
            return evaluateListFilter(filter, for: result, context: context)
        case .attachments:
            return evaluateAttachmentFilter(for: result, context: context)
        case .location, .duration, .category, .collaborators:
            // These filters require additional entities that are not represented by SearchResult directly.
            return true
        }
    }
    
    private func evaluateDateRangeFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        guard let config: DateRangeFilterConfiguration = filter.getConfiguration(as: DateRangeFilterConfiguration.self) else {
            return true
        }
        
        guard let date = getFilterDate(for: result, field: config.field, context: context) else {
            return false
        }
        
        if let startDate = config.startDate, date < startDate {
            return false
        }
        
        if let endDate = config.endDate, date > endDate {
            return false
        }
        
        return true
    }
    
    private func getFilterDate(for result: SearchResult, field: String?, context: ModelContext) -> Date? {
        switch result.itemType {
        case .reminder:
            guard let reminder = fetchReminder(by: result.itemId, context: context) else { return nil }
            switch field?.lowercased() {
            case "due", "duedate":
                return reminder.dueDate
            case "completed":
                return reminder.completedAt
            default:
                return reminder.createdAt
            }
            
        case .habit:
            guard let habit = fetchHabit(by: result.itemId, context: context) else { return nil }
            return habit.createdAt
            
        default:
            return nil
        }
    }
    
    private func evaluatePriorityFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        guard result.itemType == .reminder,
              let reminder = fetchReminder(by: result.itemId, context: context),
              let config: PriorityFilterConfiguration = filter.getConfiguration(as: PriorityFilterConfiguration.self) else {
            return true
        }
        
        let priorityValue = reminder.priority.rawValue
        
        if let priorities = config.priorities, !priorities.isEmpty, !priorities.contains(priorityValue) {
            return false
        }
        
        if let minimum = config.minimum, priorityValue < minimum {
            return false
        }
        
        if let maximum = config.maximum, priorityValue > maximum {
            return false
        }
        
        return true
    }
    
    private func evaluateStatusFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        guard result.itemType == .reminder,
              let reminder = fetchReminder(by: result.itemId, context: context),
              let config: StatusFilterConfiguration = filter.getConfiguration(as: StatusFilterConfiguration.self),
              let values = config.values?.map({ $0.lowercased() }),
              !values.isEmpty else {
            return true
        }
        
        return values.contains { value in
            switch value {
            case "completed":
                return reminder.isCompleted
            case "active":
                return !reminder.isCompleted
            case "overdue":
                return reminder.isOverdue
            default:
                return false
            }
        }
    }
    
    private func evaluateTagFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        guard let config: StringSetFilterConfiguration = filter.getConfiguration(as: StringSetFilterConfiguration.self),
              let values = config.values?.map({ $0.lowercased() }),
              !values.isEmpty else {
            return true
        }
        
        switch result.itemType {
        case .reminder:
            guard let reminder = fetchReminder(by: result.itemId, context: context) else { return false }
            let tagNames = Set((reminder.tags ?? []).map { $0.name.lowercased() })
            return !tagNames.isDisjoint(with: values)
        case .habit:
            guard let habit = fetchHabit(by: result.itemId, context: context) else { return false }
            let tagNames = Set((habit.tags ?? []).map { $0.name.lowercased() })
            return !tagNames.isDisjoint(with: values)
        default:
            return true
        }
    }
    
    private func evaluateListFilter(_ filter: SearchFilter, for result: SearchResult, context: ModelContext) -> Bool {
        guard result.itemType == .reminder,
              let reminder = fetchReminder(by: result.itemId, context: context),
              let config: StringSetFilterConfiguration = filter.getConfiguration(as: StringSetFilterConfiguration.self),
              let values = config.values?.map({ $0.lowercased() }),
              !values.isEmpty else {
            return true
        }
        
        let listName = reminder.list?.name.lowercased() ?? ""
        return values.contains(listName)
    }
    
    private func evaluateAttachmentFilter(for result: SearchResult, context: ModelContext) -> Bool {
        guard result.itemType == .reminder,
              let reminder = fetchReminder(by: result.itemId, context: context) else {
            return true
        }
        
        return reminder.appleNote != nil || reminder.voiceReminder != nil
    }
    
    private func fetchReminder(by itemId: String, context: ModelContext) -> Reminder? {
        guard let uuid = UUID(uuidString: itemId) else { return nil }
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.uuid == uuid
            }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func fetchHabit(by itemId: String, context: ModelContext) -> Habit? {
        guard let uuid = UUID(uuidString: itemId) else { return nil }
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                habit.id == uuid
            }
        )
        return try? context.fetch(descriptor).first
    }
    
    private func tokenizeForSimilarity(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }
    
    private func jaccardSimilarity(_ lhs: [String], _ rhs: [String]) -> Double {
        let leftSet = Set(lhs)
        let rightSet = Set(rhs)
        guard !leftSet.isEmpty || !rightSet.isEmpty else { return 0 }
        
        let intersection = leftSet.intersection(rightSet)
        let union = leftSet.union(rightSet)
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
    
    private func tokenizeAdvancedQuery(_ query: String) -> [String] {
        let pattern = #""[^"]+"|\S+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return query.split(separator: " ").map(String.init)
        }
        
        let nsQuery = query as NSString
        let matches = regex.matches(in: query, range: NSRange(location: 0, length: nsQuery.length))
        return matches.map { nsQuery.substring(with: $0.range) }
    }
    
    private func stripWrappingQuotes(_ value: String) -> String {
        guard value.count >= 2,
              value.first == "\"",
              value.last == "\"" else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
    
    private func executeAdvancedTextFieldSearch(
        value: String,
        scope: SearchScope,
        context: ModelContext,
        matcher: (SearchableReminderSnapshot?, SearchableHabitSnapshot?) -> Bool
    ) async -> [SearchResult] {
        var results: [SearchResult] = []
        async let reminderSnapshots: [SearchableReminderSnapshot] = shouldSearchReminders(in: scope)
            ? MemorySafeDataLoader.loadSearchableReminders(context: context)
            : []
        async let habitSnapshots: [SearchableHabitSnapshot] = shouldSearchHabits(in: scope)
            ? MemorySafeDataLoader.loadSearchableHabits(context: context)
            : []
        let reminders = await reminderSnapshots
        let habits = await habitSnapshots
        
        if shouldSearchReminders(in: scope) {
            for reminder in reminders where matcher(reminder, nil) {
                let result = SearchResult(
                    queryId: UUID(),
                    itemType: .reminder,
                    itemId: reminder.id,
                    title: reminder.title,
                    snippet: reminder.details,
                    relevanceScore: calculateRelevanceScore(query: value, title: reminder.title, content: reminder.details)
                )
                results.append(result)
            }
        }
        
        if shouldSearchHabits(in: scope) {
            for habit in habits where matcher(nil, habit) {
                let result = SearchResult(
                    queryId: UUID(),
                    itemType: .habit,
                    itemId: habit.id,
                    title: habit.title,
                    snippet: habit.details,
                    relevanceScore: calculateRelevanceScore(query: value, title: habit.title, content: habit.details)
                )
                results.append(result)
            }
        }
        
        return results
    }
    
    private func executePrioritySearch(value: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        guard scope == .all || scope == .reminders || scope == .active || scope == .overdue || scope == .completed else {
            return []
        }
        
        let targetPriority: Priority?
        switch value.lowercased() {
        case "high", "3": targetPriority = .high
        case "medium", "2": targetPriority = .medium
        case "low", "1": targetPriority = .low
        case "none", "0": targetPriority = Priority.none
        default: targetPriority = nil
        }
        
        guard let targetPriority else { return [] }
        
        let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
        return reminders
            .filter { $0.priority == targetPriority }
            .map { reminder in
                SearchResult(
                    queryId: UUID(),
                    itemType: .reminder,
                    itemId: reminder.id,
                    title: reminder.title,
                    snippet: reminder.details,
                    relevanceScore: 0.9
                )
            }
    }
    
    private func executeStatusSearch(value: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        guard scope == .all || scope == .reminders || scope == .active || scope == .overdue || scope == .completed else {
            return []
        }
        
        let normalized = value.lowercased()
        let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
        
        let filtered = reminders.filter { reminder in
            switch normalized {
            case "completed":
                return reminder.isCompleted
            case "active", "open":
                return !reminder.isCompleted
            case "overdue":
                return reminder.isOverdue
            default:
                return false
            }
        }
        
        return filtered.map { reminder in
            SearchResult(
                queryId: UUID(),
                itemType: .reminder,
                itemId: reminder.id,
                title: reminder.title,
                snippet: reminder.details,
                relevanceScore: 0.9
            )
        }
    }
    
    private func executeDueDateSearch(value: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        guard scope == .all || scope == .reminders || scope == .active || scope == .overdue || scope == .completed else {
            return []
        }
        
        let normalized = value.lowercased()
        let calendar = Calendar.current
        let now = Date()
        let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
        
        let filtered = reminders.filter { reminder in
            guard let dueDate = reminder.dueDate else {
                return normalized == "none" || normalized == "nodue"
            }
            
            switch normalized {
            case "today":
                return calendar.isDateInToday(dueDate)
            case "tomorrow":
                return calendar.isDateInTomorrow(dueDate)
            case "overdue":
                return dueDate < now && !reminder.isCompleted
            case "thisweek":
                return calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear)
            case "nextweek":
                guard let startOfNextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) else { return false }
                return calendar.isDate(dueDate, equalTo: startOfNextWeek, toGranularity: .weekOfYear)
            default:
                if let parsedDate = parseDateLiteral(normalized) {
                    return calendar.isDate(dueDate, inSameDayAs: parsedDate)
                }
                return false
            }
        }
        
        return filtered.map { reminder in
            SearchResult(
                queryId: UUID(),
                itemType: .reminder,
                itemId: reminder.id,
                title: reminder.title,
                snippet: reminder.details,
                relevanceScore: 0.85
            )
        }
    }
    
    private func parseDateLiteral(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let isoDate = isoFormatter.date(from: value) {
            return isoDate
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
    
    private func executeTagSearch(value: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        let normalizedValue = value.lowercased()
        var results: [SearchResult] = []
        
        if shouldSearchReminders(in: scope) {
            let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
            for reminder in reminders {
                let matches = reminder.tags.contains { $0.localizedCaseInsensitiveContains(normalizedValue) }
                
                if matches {
                    results.append(
                        SearchResult(
                            queryId: UUID(),
                            itemType: .reminder,
                            itemId: reminder.id,
                            title: reminder.title,
                            snippet: reminder.details,
                            relevanceScore: 0.85
                        )
                    )
                }
            }
        }
        
        if shouldSearchHabits(in: scope) {
            let habits = await MemorySafeDataLoader.loadSearchableHabits(context: context)
            for habit in habits {
                let matches = habit.tags.contains { $0.localizedCaseInsensitiveContains(normalizedValue) }
                
                if matches {
                    results.append(
                        SearchResult(
                            queryId: UUID(),
                            itemType: .habit,
                            itemId: habit.id,
                            title: habit.title,
                            snippet: habit.details,
                            relevanceScore: 0.85
                        )
                    )
                }
            }
        }
        
        return results
    }
    
    private func executeListSearch(value: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        guard scope == .all || scope == .reminders || scope == .active || scope == .overdue || scope == .completed else {
            return []
        }
        
        let normalizedValue = value.lowercased()
        let reminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
        
        return reminders
            .filter { reminder in
                reminder.listName?.localizedCaseInsensitiveContains(normalizedValue) == true
            }
            .map { reminder in
                SearchResult(
                    queryId: UUID(),
                    itemType: .reminder,
                    itemId: reminder.id,
                    title: reminder.title,
                    snippet: reminder.details,
                    relevanceScore: 0.85
                )
            }
    }
}

// MARK: - Supporting Types

struct AdvancedSearchTerm {
    let field: String
    let searchOperator: AdvancedSearchOperator
    let value: String
}

enum AdvancedSearchOperator {
    case and
    case or
    case not
}
