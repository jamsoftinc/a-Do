//
//  TimeHistoryView.swift
//  a-do
//
//  Time tracking history and entries
//

import SwiftUI
import SwiftData

struct TimeHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var timeEntries: [TimeEntry]
    @State private var selectedPeriod = HistoryPeriod.week
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    
    let categories = ["All", "Work", "Study", "Exercise", "Reading", "Creative", "Personal"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                filtersSection
                
                // Content
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .navigationTitle("Time History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search entries...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(HistoryPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        CategoryFilterChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Time Entries")
                .font(.headline)
                .primaryText()
            
            Text("Start tracking time to see your history here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedEntries, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date Header
                        HStack {
                            Text(group.date, style: .date)
                                .font(.headline)
                                .primaryText()
                            
                            Spacer()
                            
                            Text(formatDuration(group.totalTime))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.surfaceLight)
                        .cornerRadius(8)
                        
                        // Entries for this date
                        LazyVStack(spacing: 8) {
                            ForEach(group.entries, id: \.id) { entry in
                                TimeHistoryEntryRow(entry: entry)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [TimeEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch selectedPeriod {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            startDate = Date.distantPast
        }
        
        var entries = timeEntries.filter { $0.startTime >= startDate }
        
        if selectedCategory != "All" {
            entries = entries.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.category.localizedCaseInsensitiveContains(searchText) ||
                (entry.reminder?.title.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return entries.sorted { $0.startTime > $1.startTime }
    }
    
    private var groupedEntries: [TimeEntryGroup] {
        let calendar = Calendar.current
        var groups: [Date: [TimeEntry]] = [:]
        
        for entry in filteredEntries {
            let date = calendar.startOfDay(for: entry.startTime)
            groups[date, default: []].append(entry)
        }
        
        return groups.map { date, entries in
            let totalTime = entries.reduce(0) { $0 + $1.actualDuration }
            return TimeEntryGroup(date: date, entries: entries, totalTime: totalTime)
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct CategoryFilterChip: View {
    let category: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(category)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surfaceLight,
                    in: Capsule()
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct TimeHistoryEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: categoryIcon(for: entry.category))
                .font(.title2)
                .foregroundColor(categoryColor(for: entry.category))
                .frame(width: 24, height: 24)
            
            // Entry Details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.category)
                    .font(.body)
                    .fontWeight(.medium)
                    .primaryText()
                
                if let reminder = entry.reminder {
                    Text(reminder.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(entry.startTime, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(entry.formattedDuration)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            Spacer()
            
            // Status
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: entry.isActive ? "play.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(entry.isActive ? .orange : .green)
                
                Text(entry.isActive ? "Active" : "Complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Work": return "briefcase.fill"
        case "Study": return "book.fill"
        case "Exercise": return "figure.run"
        case "Reading": return "text.book.closed.fill"
        case "Creative": return "paintbrush.fill"
        case "Personal": return "person.fill"
        default: return "clock.fill"
        }
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Work": return .blue
        case "Study": return .green
        case "Exercise": return .orange
        case "Reading": return .purple
        case "Creative": return .pink
        case "Personal": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Supporting Types

enum HistoryPeriod: CaseIterable {
    case day, week, month, all
    
    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All"
        }
    }
}

struct TimeEntryGroup {
    let date: Date
    let entries: [TimeEntry]
    let totalTime: TimeInterval
}

#Preview {
    TimeHistoryView()
        .modelContainer(for: [TimeEntry.self])
}
