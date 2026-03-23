//
//  SmartSearchView.swift
//  a-do
//
//  Smart search interface with advanced search capabilities
//

import SwiftUI
import SwiftData

struct SmartSearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let initialQuery: String?
    private let savedSearchID: UUID?
    private let initialScope: SearchScope?
    
    @State private var aiManager = AIManager.shared
    @State private var audioManager = AudioManager.shared
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .text
    @State private var selectedScope: SearchScope = .all
    @State private var selectedSortOrder: SearchSortOrder = .relevance
    @State private var showingFilters = false
    @State private var isSearching = false
    @State private var searchResults: [SearchDisplayResult] = []
    @State private var commandSummary: String?
    @State private var commandRequiresPro = false
    @State private var showingPaywall = false
    @State private var searchableReminders: [SearchableReminderSnapshot] = []
    @State private var searchableHabits: [SearchableHabitSnapshot] = []
    @State private var isLoadingSearchData = false
    @State private var searchTask: Task<Void, Never>?
    @State private var reminderMutationMonitor = ReminderMutationMonitor.shared
    @State private var isViewVisible = false
    
    @Query private var recentSearches: [SearchQuery]
    @Query(sort: [SortDescriptor(\SavedSearch.lastUsed, order: .reverse), SortDescriptor(\SavedSearch.createdAt, order: .reverse)]) private var savedSearches: [SavedSearch]

    init(initialQuery: String? = nil, savedSearchID: UUID? = nil, initialScope: SearchScope? = nil) {
        self.initialQuery = initialQuery
        self.savedSearchID = savedSearchID
        self.initialScope = initialScope
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Search Type Selector
                searchTypeSelector
                
                // Search Results or Recent Searches
                if searchText.isEmpty {
                    recentSearchesSection
                } else {
                    searchResultsSection
                }
            }
            .navigationTitle("Smart Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(
                selectedScope: $selectedScope,
                selectedSortOrder: $selectedSortOrder
            )
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .onAppear {
            isViewVisible = true
            Task {
                await reloadSearchData()
                if let savedSearchID, let savedSearch = savedSearches.first(where: { $0.id == savedSearchID }) {
                    loadSavedSearch(savedSearch, shouldSearchImmediately: true)
                    return
                }
                if let initialScope {
                    selectedScope = initialScope
                }
                guard let initialQuery, searchText.isEmpty else { return }
                searchText = initialQuery
                scheduleSearch(immediate: true)
            }
        }
        .onChange(of: reminderMutationMonitor.revision) { _, _ in
            guard isViewVisible else { return }
            Task {
                await reloadSearchData()
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchTask?.cancel()
                commandSummary = nil
                commandRequiresPro = false
                searchResults = []
                return
            }
            scheduleSearch()
        }
        .onChange(of: selectedSearchType) { _, _ in
            guard !searchText.isEmpty else { return }
            scheduleSearch(immediate: true)
        }
        .onChange(of: selectedScope) { _, _ in
            guard !searchText.isEmpty else { return }
            scheduleSearch(immediate: true)
        }
        .onChange(of: selectedSortOrder) { _, _ in
            guard !searchText.isEmpty else { return }
            scheduleSearch(immediate: true)
        }
        .onChange(of: audioManager.transcribedText) { _, newValue in
            guard selectedSearchType == .voice else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            searchText = trimmed
            scheduleSearch(immediate: true)
        }
        .onDisappear {
            isViewVisible = false
            searchTask?.cancel()
            if audioManager.isRecording {
                audioManager.stopLiveTranscription()
            }
        }
    }

    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Search reminders, habits, and more...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        scheduleSearch(immediate: true)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surfaceLight)
            .cornerRadius(12)
            
            // Quick Actions
            HStack(spacing: 12) {
                Button(audioManager.isRecording ? "Stop Listening" : "Voice Search") {
                    toggleVoiceSearch()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((audioManager.isRecording ? Color.red : AppTheme.Colors.accent).opacity(0.1))
                .foregroundColor(audioManager.isRecording ? .red : AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.small)
                
                Button("Advanced") {
                    selectedSearchType = .advanced
                    showingFilters = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.secondary.opacity(0.1))
                .foregroundColor(AppTheme.Colors.secondary)
                .cornerRadius(AppTheme.CornerRadius.small)

                if !normalizedSearchText.isEmpty {
                    Button(isCurrentSearchBookmarked ? "Saved View" : "Save View") {
                        toggleSavedSearch()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isCurrentSearchBookmarked ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary).opacity(0.12))
                    .foregroundColor(isCurrentSearchBookmarked ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
                
                Spacer()
                
                Text("\(selectedScope.displayName) • \(selectedSortOrder.displayName)")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            if audioManager.isRecording || !audioManager.liveTranscription.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: audioManager.isRecording ? "waveform.circle.fill" : "mic.badge.checkmark")
                        .foregroundColor(audioManager.isRecording ? .red : .mint)

                    Text(audioManager.liveTranscription.isEmpty ? "Listening..." : audioManager.liveTranscription)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, 2)
            }

            if let commandSummary, !commandSummary.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: commandRequiresPro ? "lock.fill" : "wand.and.stars")
                        .foregroundColor(commandRequiresPro ? .orange : .mint)
                        .font(.caption)

                    Text(commandSummary)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Spacer()

                    if commandRequiresPro {
                        Button("Upgrade") {
                            showingPaywall = true
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Search Type Selector
    
    private var searchTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    SearchTypeButton(
                        type: type,
                        isSelected: selectedSearchType == type
                    ) {
                        selectedSearchType = type
                        if !searchText.isEmpty {
                            scheduleSearch(immediate: true)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Recent Searches Section
    
    private var recentSearchesSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !savedSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Saved Views")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                        }

                        ForEach(savedSearches.prefix(5)) { savedSearch in
                            SavedSearchRow(savedSearch: savedSearch) {
                                loadSavedSearch(savedSearch, shouldSearchImmediately: true)
                            }
                        }
                    }
                    .padding()
                }

                // Bookmarked Searches
                let bookmarkedSearches = recentSearches.filter { $0.isBookmarked }
                if !bookmarkedSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Bookmarked Searches")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                        }
                        
                        ForEach(bookmarkedSearches.prefix(5)) { bookmarkedSearch in
                            BookmarkedSearchRow(searchQuery: bookmarkedSearch) {
                                searchText = bookmarkedSearch.query
                                selectedSearchType = bookmarkedSearch.searchType
                                scheduleSearch(immediate: true)
                            }
                        }
                    }
                    .padding()
                }
                
                // Recent Searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Searches")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                        }
                        
                        ForEach(recentSearches.prefix(10)) { recentSearch in
                            RecentSearchRow(searchQuery: recentSearch) {
                                searchText = recentSearch.query
                                selectedSearchType = recentSearch.searchType
                                scheduleSearch(immediate: true)
                            }
                        }
                    }
                    .padding()
                }
                
                // Search Tips
                searchTipsSection
            }
        }
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Display search results
                if !searchResults.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.id) { result in
                            SearchResultRow(result: result)
                        }
                    }
                } else if !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Search Tips Section
    
    private var searchTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Tips")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                SearchTip(
                    icon: "textformat",
                    title: "Text Search",
                    description: "Search for exact words or phrases"
                )
                
                SearchTip(
                    icon: "brain",
                    title: "Semantic Search",
                    description: "Find content by meaning, not just keywords"
                )
                
                SearchTip(
                    icon: "wand.and.stars",
                    title: "Fuzzy Search",
                    description: "Find results even with typos or partial matches"
                )
                
                SearchTip(
                    icon: "mic",
                    title: "Voice Search",
                    description: "Speak your search query naturally"
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight)
        .cornerRadius(12)
        .padding()
    }
    
    // MARK: - Actions
    
    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            guard !Task.isCancelled else { return }
            await runSearch(query: query)
        }
    }

    private func runSearch(query: String) async {
        guard let sanitizedQuery = SecurityUtils.sanitizeTextInput(query) else { return }
        if searchableReminders.isEmpty && searchableHabits.isEmpty {
            await reloadSearchData()
        }

        isSearching = true

        let startTime = Date()
        let normalizedQuery = sanitizedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedQuery = normalizedQuery.lowercased()
        var results: [SearchDisplayResult] = []
        var handledByCommandSearch = false
        var localCommandSummary: String?
        var localCommandRequiresPro = false

        if let command = await aiManager.parseNaturalLanguageSearchCommand(normalizedQuery) {
            handledByCommandSearch = true
            localCommandSummary = command.summary
            results = searchReminderResults(command: command, query: lowercasedQuery)
        } else if looksLikeNaturalCommand(normalizedQuery), !EntitlementManager.shared.isProUser {
            localCommandSummary = "Natural command filters are Pro. Showing basic keyword results."
            localCommandRequiresPro = true
        }

        if !handledByCommandSearch {
            if selectedScope == .all || selectedScope == .reminders || selectedScope == .active || selectedScope == .completed || selectedScope == .overdue {
                results.append(contentsOf: searchReminderResults(query: lowercasedQuery))
            }

            if selectedScope == .all || selectedScope == .habits {
                results.append(contentsOf: searchHabitResults(query: lowercasedQuery))
            }
        }

        let sortedResults = sortResults(results)
        saveSearchHistory(
            query: normalizedQuery,
            resultCount: sortedResults.count,
            executionTime: Date().timeIntervalSince(startTime)
        )

        commandSummary = localCommandSummary
        commandRequiresPro = localCommandRequiresPro
        searchResults = sortedResults
        isSearching = false
    }

    private func reloadSearchData() async {
        guard !isLoadingSearchData else { return }
        isLoadingSearchData = true

        searchableReminders = await MemorySafeDataLoader.loadSearchableReminders(context: context)
        searchableHabits = await MemorySafeDataLoader.loadSearchableHabits(context: context)
        isLoadingSearchData = false
    }

    private func toggleVoiceSearch() {
        selectedSearchType = .voice
        if audioManager.isRecording {
            audioManager.stopLiveTranscription()
        } else {
            audioManager.transcribedText = ""
            audioManager.liveTranscription = ""
            Task {
                await audioManager.startLiveTranscription()
            }
        }
    }

    private func searchReminderResults(query: String) -> [SearchDisplayResult] {
        return searchableReminders.compactMap { reminder in
            if selectedScope == .active && reminder.isCompleted { return nil }
            if selectedScope == .completed && !reminder.isCompleted { return nil }
            if selectedScope == .overdue && !reminder.isOverdue { return nil }

            let text = "\(reminder.title) \(reminder.details) \(reminder.tags.joined(separator: " "))".lowercased()
            guard text.contains(query) || reminder.title.lowercased().contains(query.replacingOccurrences(of: "#", with: "")) else {
                return nil
            }

            let score = relevanceScore(for: reminder, query: query)
            return SearchDisplayResult(
                itemType: .reminder,
                itemId: reminder.id,
                title: reminder.title,
                snippet: reminder.details,
                relevanceScore: score,
                createdAt: reminder.createdAt,
                dueDate: reminder.dueDate,
                priorityRank: reminder.priority.rawValue
            )
        }
    }

    private func searchHabitResults(query: String) -> [SearchDisplayResult] {
        return searchableHabits.compactMap { habit in
            let text = "\(habit.title) \(habit.details)".lowercased()
            guard text.contains(query) else { return nil }

            let score: Double = habit.title.lowercased().contains(query) ? 0.9 : 0.7
            return SearchDisplayResult(
                itemType: .habit,
                itemId: habit.id,
                title: habit.title,
                snippet: habit.details,
                relevanceScore: score,
                createdAt: nil,
                dueDate: nil,
                priorityRank: Priority.none.rawValue
            )
        }
    }

    private func relevanceScore(for reminder: SearchableReminderSnapshot, query: String) -> Double {
        let normalizedQuery = query.replacingOccurrences(of: "#", with: "")
        var score = reminder.title.lowercased().contains(normalizedQuery) ? 0.9 : 0.6
        if reminder.isOverdue { score += 0.05 }
        if reminder.priority == .high { score += 0.05 }
        return min(score, 1.0)
    }

    private func saveSearchHistory(query: String, resultCount: Int, executionTime: TimeInterval) {
        guard !query.isEmpty else { return }
        let descriptor = FetchDescriptor<SearchQuery>(
            predicate: #Predicate<SearchQuery> { $0.query == query }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.searchType = selectedSearchType
            existing.scope = selectedScope
            existing.sortOrder = selectedSortOrder
            existing.updateUsage(resultCount: resultCount, executionTime: executionTime)
        } else {
            let queryModel = SearchQuery(
                userId: SecurityUtils.getCurrentUserID(),
                query: query,
                searchType: selectedSearchType
            )
            queryModel.scope = selectedScope
            queryModel.sortOrder = selectedSortOrder
            queryModel.updateUsage(resultCount: resultCount, executionTime: executionTime)
            context.insert(queryModel)
        }

        if let savedSearch = currentSavedSearch {
            savedSearch.updateUsage()
            Task {
                await SearchSpotlightManager.shared.indexSavedSearch(savedSpotlightItem(for: savedSearch))
            }
        }

        try? context.save()
    }

    private func searchReminderResults(command: ProSearchCommand, query: String) -> [SearchDisplayResult] {
        let calendar = Calendar.current

        let now = Date()
        var cutoffDate: Date?
        if let hour = command.beforeHour {
            cutoffDate = calendar.date(
                bySettingHour: hour,
                minute: command.beforeMinute ?? 0,
                second: 0,
                of: now
            )
        }

        return searchableReminders.compactMap { reminder in
            if !(command.includeCompleted ?? false) && reminder.isCompleted {
                return nil
            }
            if command.requireUnscheduled == true, reminder.dueDate != nil {
                return nil
            }
            if let priority = command.priority?.lowercased(), !priority.isEmpty {
                switch priority {
                case "high" where reminder.priority != .high: return nil
                case "medium" where reminder.priority != .medium: return nil
                case "low" where reminder.priority != .low: return nil
                case "none" where reminder.priority != .none: return nil
                default: break
                }
            }

            if let dueWindow = command.dueWindow?.lowercased() {
                switch dueWindow {
                case "today":
                    guard let due = reminder.dueDate, calendar.isDateInToday(due) else { return nil }
                case "tomorrow":
                    guard let due = reminder.dueDate, calendar.isDateInTomorrow(due) else { return nil }
                case "this_week":
                    guard let due = reminder.dueDate,
                          let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
                          weekInterval.contains(due) else { return nil }
                case "overdue":
                    guard reminder.isOverdue else { return nil }
                default:
                    break
                }
            }

            if let cutoffDate {
                guard let due = reminder.dueDate, due <= cutoffDate else { return nil }
            }

            if let maxDuration = command.maxDurationMinutes {
                let estimate = estimatedDurationMinutes(for: reminder)
                if estimate > maxDuration {
                    return nil
                }
            }

            if !query.isEmpty {
                let searchable = "\(reminder.title) \(reminder.details)".lowercased()
                let hasCommandWords = query.split(separator: " ").contains { token in
                    let word = String(token)
                    return ["before", "today", "tomorrow", "overdue", "priority", "can", "do", "in", "minutes", "hour", "tasks", "reminders", "unscheduled"].contains(word)
                }
                if !searchable.contains(query) && !hasCommandWords {
                    return nil
                }
            }

            var score = relevanceScore(for: reminder, query: query)
            if let maxDuration = command.maxDurationMinutes {
                let estimate = estimatedDurationMinutes(for: reminder)
                score += max(0, 0.2 - (Double(estimate) / Double(max(1, maxDuration * 5))))
            }
            if reminder.priority == .high { score += 0.05 }
            if reminder.isOverdue { score += 0.05 }

            let snippetParts = [
                command.summary,
                reminder.details
            ].filter { !$0.isEmpty }

            return SearchDisplayResult(
                itemType: .reminder,
                itemId: reminder.id,
                title: reminder.title,
                snippet: snippetParts.joined(separator: " • "),
                relevanceScore: min(score, 1.0),
                createdAt: reminder.createdAt,
                dueDate: reminder.dueDate,
                priorityRank: reminder.priority.rawValue
            )
        }
    }

    private func sortResults(_ results: [SearchDisplayResult]) -> [SearchDisplayResult] {
        results.sorted { lhs, rhs in
            switch selectedSortOrder {
            case .alphabetical:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .dateCreated, .dateModified:
                return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            case .dueDate:
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            case .priority:
                return lhs.priorityRank > rhs.priorityRank
            default:
                return lhs.relevanceScore > rhs.relevanceScore
            }
        }
    }

    private func estimatedDurationMinutes(for reminder: SearchableReminderSnapshot) -> Int {
        reminder.estimatedDurationMinutes
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCurrentSearchBookmarked: Bool {
        currentSavedSearch != nil
    }

    private func toggleSavedSearch() {
        let query = normalizedSearchText
        guard !query.isEmpty else { return }

        if let existing = currentSavedSearch {
            let removedID = existing.id
            context.delete(existing)
            try? context.save()
            Task {
                await SearchSpotlightManager.shared.removeSavedSearch(id: removedID)
            }
        } else {
            let savedSearch = SavedSearch(
                name: query,
                query: query,
                searchType: selectedSearchType,
                scope: selectedScope,
                sortOrder: selectedSortOrder
            )
            savedSearch.lastUsed = Date()
            context.insert(savedSearch)
            try? context.save()
            Task {
                await SearchSpotlightManager.shared.indexSavedSearch(savedSpotlightItem(for: savedSearch))
            }
        }
    }

    private var currentSavedSearch: SavedSearch? {
        savedSearches.first(where: {
            $0.query == normalizedSearchText &&
            $0.searchType == selectedSearchType &&
            $0.scope == selectedScope &&
            $0.sortOrder == selectedSortOrder
        })
    }

    private func loadSavedSearch(_ savedSearch: SavedSearch, shouldSearchImmediately: Bool) {
        searchText = savedSearch.query
        selectedSearchType = savedSearch.searchType
        selectedScope = savedSearch.scope
        selectedSortOrder = savedSearch.sortOrder
        savedSearch.updateUsage()
        try? context.save()

        Task {
            await SearchSpotlightManager.shared.indexSavedSearch(savedSpotlightItem(for: savedSearch))
        }

        if shouldSearchImmediately {
            scheduleSearch(immediate: true)
        }
    }

    private func savedSpotlightItem(for savedSearch: SavedSearch) -> SavedSearchSpotlightItem {
        SavedSearchSpotlightItem(
            id: savedSearch.id,
            name: savedSearch.name,
            query: savedSearch.query,
            searchTypeName: savedSearch.searchType.displayName,
            scopeName: savedSearch.scope.displayName,
            sortOrderName: savedSearch.sortOrder.displayName
        )
    }

    private func looksLikeNaturalCommand(_ query: String) -> Bool {
        let lower = query.lowercased()
        let commandKeywords = [
            "can do in", "before", "overdue", "today", "tomorrow",
            "this week", "high priority", "low priority", "unscheduled",
            "without due", "show tasks", "show reminders"
        ]
        if commandKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        return lower.range(of: #"\b\d+\s*(m|min|minutes|h|hr|hours)\b"#, options: .regularExpression) != nil
    }
}

struct SearchDisplayResult: Identifiable {
    let itemType: SearchResultType
    let itemId: String
    let title: String
    let snippet: String
    let relevanceScore: Double
    let createdAt: Date?
    let dueDate: Date?
    let priorityRank: Int

    var id: String {
        "\(itemType.rawValue)-\(itemId)"
    }
}

// MARK: - Supporting Views

struct SearchTypeButton: View {
    let type: SearchType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                Text(type.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surfaceLight)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .cornerRadius(AppTheme.CornerRadius.small)
        }
    }
}

struct BookmarkedSearchRow: View {
    let searchQuery: SearchQuery
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: searchQuery.searchType.icon)
                    .foregroundColor(AppTheme.Colors.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(searchQuery.query)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(searchQuery.searchType.displayName)
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.accent)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct SavedSearchRow: View {
    let savedSearch: SavedSearch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(AppTheme.Colors.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(savedSearch.name)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text("\(savedSearch.query) • \(savedSearch.scope.displayName)")
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.accent)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct RecentSearchRow: View {
    let searchQuery: SearchQuery
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(searchQuery.query)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(searchQuery.searchType.displayName)
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text(searchQuery.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct SearchResultRow: View {
    let result: SearchDisplayResult
    
    var body: some View {
        HStack {
            Image(systemName: result.itemType.icon)
                .foregroundColor(result.itemType.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(result.snippet)
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight)
        .cornerRadius(12)
    }
}

struct SearchTip: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Smart Search Result Type

enum SmartSearchResultType {
    case reminder
    case habit
    case template
    case list
    
    var icon: String {
        switch self {
        case .reminder: return "bell"
        case .habit: return "chart.line.uptrend.xyaxis"
        case .template: return "doc.text"
        case .list: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .reminder: return AppTheme.Colors.accent
        case .habit: return .orange
        case .template: return .indigo
        case .list: return .blue
        }
    }
}

// MARK: - Search Filters View

struct SearchFiltersView: View {
    @Binding var selectedScope: SearchScope
    @Binding var selectedSortOrder: SearchSortOrder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Search Scope") {
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Sort Order") {
                    Picker("Sort", selection: $selectedSortOrder) {
                        ForEach(SearchSortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SmartSearchView()
        .modelContainer(for: [SearchQuery.self])
}
