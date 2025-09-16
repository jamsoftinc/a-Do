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
    @StateObject private var searchManager = AdvancedSearchManager.shared
    
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .text
    @State private var selectedScope: SearchScope = .all
    @State private var selectedSortOrder: SearchSortOrder = .relevance
    @State private var showingFilters = false
    @State private var isSearching = false
    @State private var searchResults: [SearchResult] = []
    
    @Query private var recentSearches: [SearchQuery]
    
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
                        performSearch()
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
                Button("Voice Search") {
                    selectedSearchType = .voice
                    // Voice search would be implemented here
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.accent.opacity(0.1))
                .foregroundColor(AppTheme.Colors.accent)
                .cornerRadius(8)
                
                Button("Advanced") {
                    selectedSearchType = .advanced
                    showingFilters = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.secondary.opacity(0.1))
                .foregroundColor(AppTheme.Colors.secondary)
                .cornerRadius(8)
                
                Spacer()
                
                Text("\(selectedScope.displayName) • \(selectedSortOrder.displayName)")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
                            performSearch()
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
                                performSearch()
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
                                performSearch()
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
                        .foregroundColor(.secondary)
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
    
    private func performSearch() {
        // Validate and sanitize search input
        guard let sanitizedQuery = SecurityUtils.sanitizeTextInput(searchText) else {
            // Show user-friendly error without exposing technical details
            return
        }
        
        isSearching = true
        
        Task {
            // This would integrate with AdvancedSearchManager
            // For now, simulate search results
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            
            await MainActor.run {
                searchResults = [
                    SearchResult(
                        queryId: UUID(),
                        itemType: .reminder,
                        itemId: UUID().uuidString,
                        title: "Sample Reminder",
                        snippet: "This is a sample search result",
                        relevanceScore: 0.9
                    )
                ]
                isSearching = false
            }
        }
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
            .cornerRadius(8)
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
    let result: SearchResult
    
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
