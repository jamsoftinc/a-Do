//
//  AdvancedSearchManager.swift
//  a-do
//
//  Advanced search and organization manager
//

import Foundation
import SwiftData
import Observation
import os
import NaturalLanguage

@MainActor
@Observable
final class AdvancedSearchManager {
    static let shared = AdvancedSearchManager()
    
    private let logger = Logger(subsystem: "a-do", category: "AdvancedSearch")
    
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
    
    // Organization rules
    private var organizationRules: [OrganizationRule] = []
    
    // Quick actions
    private var quickActions: [QuickAction] = []
    
    private init() {
        setupPeriodicIndexing()
    }
    
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
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isSearching = true
        currentQuery = query
        
        defer {
            isSearching = false
        }
        
        let startTime = Date()
        
        logger.info("Starting search: '\(query)' type: \(type.rawValue) scope: \(scope.rawValue)")
        
        // Create search query record
        let searchQuery = SearchQuery(userId: userId, query: query, searchType: type)
        searchQuery.scope = scope
        searchQuery.sortOrder = sortOrder
        
        if !filters.isEmpty {
            searchQuery.setFilters(filters.map { $0.id.uuidString })
        }
        
        context.insert(searchQuery)
        
        var results: [SearchResult] = []
        
        switch type {
        case .text:
            results = await performTextSearch(query: query, scope: scope, filters: filters, context: context)
        case .fuzzy:
            results = await performFuzzySearch(query: query, scope: scope, filters: filters, context: context)
        case .semantic:
            results = await performSemanticSearch(query: query, scope: scope, filters: filters, context: context)
        case .voice:
            results = await performVoiceSearch(query: query, scope: scope, filters: filters, context: context)
        case .regex:
            results = await performTextSearch(query: query, scope: scope, filters: filters, context: context) // Regex search not implemented yet
        case .advanced:
            results = await performAdvancedSearch(query: query, scope: scope, filters: filters, context: context)
        }
        
        // Apply sorting
        results = sortResults(results, by: sortOrder)
        
        // Update search query with results
        let executionTime = Date().timeIntervalSince(startTime)
        searchQuery.updateUsage(resultCount: results.count, executionTime: executionTime)
        
        // Save results
        for result in results {
            result.queryId = searchQuery.id
            context.insert(result)
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
        
        // Search reminders
        if scope == .all || scope == .reminders || scope == .active || scope == .overdue {
            let reminderResults = await searchReminders(query: lowercaseQuery, scope: scope, context: context)
            results.append(contentsOf: reminderResults)
        }
        
        // Search habits
        if scope == .all || scope == .habits {
            let habitResults = await searchHabits(query: lowercaseQuery, context: context)
            results.append(contentsOf: habitResults)
        }
        
        // Search tags
        if scope == .all || scope == .tags {
            let tagResults = await searchTags(query: lowercaseQuery, context: context)
            results.append(contentsOf: tagResults)
        }
        
        // Search lists
        if scope == .all || scope == .lists {
            let listResults = await searchLists(query: lowercaseQuery, context: context)
            results.append(contentsOf: listResults)
        }
        
        // Apply filters
        results = applyFilters(results, filters: filters, context: context)
        
        return results
    }
    
    private func searchReminders(query: String, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        var predicate: Predicate<Reminder>
        
        switch scope {
        case .active:
            predicate = #Predicate<Reminder> { reminder in
                !reminder.isCompleted && (
                    reminder.title.contains(query) ||
                    (reminder.details?.contains(query) ?? false)
                )
            }
        case .overdue:
            let now = Date()
            predicate = #Predicate<Reminder> { reminder in
                !reminder.isCompleted &&
                reminder.dueDate != nil &&
                reminder.dueDate! < now && (
                    reminder.title.contains(query) ||
                    (reminder.details?.contains(query) ?? false)
                )
            }
        case .completed:
            predicate = #Predicate<Reminder> { reminder in
                reminder.isCompleted && (
                    reminder.title.contains(query) ||
                    (reminder.details?.contains(query) ?? false)
                )
            }
        default:
            predicate = #Predicate<Reminder> { reminder in
                reminder.title.contains(query) ||
                (reminder.details?.contains(query) ?? false)
            }
        }
        
        let descriptor = FetchDescriptor<Reminder>(predicate: predicate)
        let reminders = (try? context.fetch(descriptor)) ?? []
        
        return reminders.map { reminder in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: reminder.title,
                content: reminder.details ?? ""
            )
            
            let snippet = createSnippet(
                query: query,
                content: reminder.details ?? reminder.title,
                maxLength: 150
            )
            
            let result = SearchResult(
                queryId: UUID(),
                itemType: .reminder,
                itemId: reminder.uuid.uuidString,
                title: reminder.title,
                snippet: snippet,
                relevanceScore: relevanceScore
            )
            
            result.matchType = determineMatchType(query: query, text: reminder.title)
            result.matchedFields = getMatchedFields(query: query, reminder: reminder)
            
            return result
        }
    }
    
    private func searchHabits(query: String, context: ModelContext) async -> [SearchResult] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                habit.title.contains(query) ||
                habit.habitDescription.contains(query)
            }
        )
        
        let habits = (try? context.fetch(descriptor)) ?? []
        
        return habits.map { habit in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: habit.title,
                content: habit.habitDescription
            )
            
            let snippet = createSnippet(
                query: query,
                content: habit.habitDescription.isEmpty ? habit.title : habit.habitDescription,
                maxLength: 150
            )
            
            return SearchResult(
                queryId: UUID(),
                itemType: .habit,
                itemId: habit.id.uuidString,
                title: habit.title,
                snippet: snippet,
                relevanceScore: relevanceScore
            )
        }
    }
    
    private func searchTags(query: String, context: ModelContext) async -> [SearchResult] {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.name.contains(query)
            }
        )
        
        let tags = (try? context.fetch(descriptor)) ?? []
        
        return tags.map { tag in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: tag.name,
                content: ""
            )
            
            return SearchResult(
                queryId: UUID(),
                itemType: .tag,
                itemId: UUID().uuidString, // Tags don't have persistent IDs in the current model
                title: tag.name,
                snippet: "Tag with \(tag.reminders?.count ?? 0) reminders",
                relevanceScore: relevanceScore
            )
        }
    }
    
    private func searchLists(query: String, context: ModelContext) async -> [SearchResult] {
        let descriptor = FetchDescriptor<ReminderList>(
            predicate: #Predicate<ReminderList> { list in
                list.name.contains(query)
            }
        )
        
        let lists = (try? context.fetch(descriptor)) ?? []
        
        return lists.map { list in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: list.name,
                content: ""
            )
            
            return SearchResult(
                queryId: UUID(),
                itemType: .list,
                itemId: UUID().uuidString, // Lists don't have persistent IDs in the current model
                title: list.name,
                snippet: "List with \(list.reminders?.count ?? 0) reminders",
                relevanceScore: relevanceScore
            )
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
        if scope == .all || scope == .reminders {
            let reminderDescriptor = FetchDescriptor<Reminder>()
            let reminders = (try? context.fetch(reminderDescriptor)) ?? []
            
            for reminder in reminders {
                let similarity = calculateSemanticSimilarity(
                    query: query,
                    text: reminder.title + " " + (reminder.details ?? ""),
                    embedding: embedding
                )
                
                if similarity > 0.3 { // Threshold for semantic relevance
                    let result = SearchResult(
                        queryId: UUID(),
                        itemType: .reminder,
                        itemId: reminder.uuid.uuidString,
                        title: reminder.title,
                        snippet: createSnippet(query: query, content: reminder.details ?? "", maxLength: 150),
                        relevanceScore: similarity
                    )
                    result.matchType = .semantic
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
        
        // Get suggestions from reminder titles
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.title.contains(partialQuery)
            }
        )
        
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        suggestions.append(contentsOf: reminders.prefix(3).map { $0.title })
        
        // Get suggestions from tags
        let tagDescriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.name.contains(partialQuery)
            }
        )
        
        let tags = (try? context.fetch(tagDescriptor)) ?? []
        suggestions.append(contentsOf: tags.prefix(3).map { $0.name })
        
        return suggestions
    }
    
    // MARK: - Search Index Management
    
    private func setupPeriodicIndexing() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateSearchIndex()
            }
        }
    }
    
    private func updateSearchIndex() async {
        logger.info("Updating search index")
        lastIndexUpdate = Date()
        
        // This would update the search index with new/modified content
        // Implementation would depend on the specific indexing strategy
    }
    
    func rebuildSearchIndex(context: ModelContext) async {
        logger.info("Rebuilding search index")
        
        // Clear existing index
        let indexDescriptor = FetchDescriptor<SearchIndex>()
        let existingIndexes = (try? context.fetch(indexDescriptor)) ?? []
        
        for index in existingIndexes {
            context.delete(index)
        }
        
        // Rebuild index for reminders
        let reminderDescriptor = FetchDescriptor<Reminder>()
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        for reminder in reminders {
            let content = reminder.title + " " + (reminder.details ?? "")
            let index = SearchIndex(
                itemType: .reminder,
                itemId: reminder.uuid.uuidString,
                content: content
            )
            context.insert(index)
        }
        
        // Rebuild index for habits
        let habitDescriptor = FetchDescriptor<Habit>()
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        
        for habit in habits {
            let content = habit.title + " " + habit.habitDescription
            let index = SearchIndex(
                itemType: .habit,
                itemId: habit.id.uuidString,
                content: content
            )
            context.insert(index)
        }
        
        do {
            try context.save()
            logger.info("Search index rebuilt successfully")
        } catch {
            logger.error("Failed to rebuild search index: \(error.localizedDescription)")
        }
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
        // Evaluate rule conditions against the item
        // This would be implemented based on the specific rule conditions
        return false // Placeholder
    }
    
    private func executeRule(_ rule: OrganizationRule, on item: Any, context: ModelContext) async {
        // Execute rule actions on the item
        // This would be implemented based on the specific rule actions
        logger.info("Executing organization rule: \(rule.name)")
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
        var fields: [String] = []
        
        if reminder.title.localizedStandardContains(query) {
            fields.append("title")
        }
        
        if reminder.details?.localizedStandardContains(query) == true {
            fields.append("details")
        }
        
        return fields
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
        // Apply search filters to results
        // This would be implemented based on the specific filter types
        return results
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
        // This would use the NLEmbedding to calculate semantic similarity
        // For now, return a placeholder value
        return 0.5
    }
    
    private func isPhoneticMatch(_ query: String, _ text: String) -> Bool {
        // Implement phonetic matching algorithm (e.g., Soundex, Metaphone)
        // For now, return a simple similarity check
        return levenshteinDistance(query.lowercased(), text.lowercased()) <= 2
    }
    
    private func parseAdvancedQuery(_ query: String) -> [AdvancedSearchTerm] {
        // Parse advanced search syntax
        // For now, return a simple term
        return [AdvancedSearchTerm(field: "title", searchOperator: .and, value: query)]
    }
    
    private func executeAdvancedTerm(_ term: AdvancedSearchTerm, scope: SearchScope, context: ModelContext) async -> [SearchResult] {
        // Execute advanced search term
        return []
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
