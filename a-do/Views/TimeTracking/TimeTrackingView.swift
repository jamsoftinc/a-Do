//
//  TimeTrackingView.swift
//  a-do
//
//  Time tracking interface
//

import SwiftUI
import SwiftData
import Charts

struct TimeTrackingView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var timeManager = TimeTrackingManager.shared
    @State private var timeEntries: [TimeEntry] = []
    @State private var timeGoals: [TimeGoal] = []
    @State private var categories: [TimeCategory] = []
    
    @State private var selectedCategory = "Work"
    @State private var showingCategoryPicker = false
    @State private var showingAnalytics = false
    @State private var showingGoals = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Tracking Card
                    currentTrackingCard
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Today's Summary
                    todaySummaryCard
                    
                    // Recent Entries
                    recentEntriesSection
                }
                .padding()
            }
            .navigationTitle("Time Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        HStack {
                            Button("Analytics") {
                                showingAnalytics = true
                            }
                            if !EntitlementManager.shared.isProUser {
                                ProFeaturesAvailableBadge()
                            }
                        }
                        Button("Goals") {
                            showingGoals = true
                        }
                        Button("Categories") {
                            // Navigate to categories management
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAnalytics) {
            TimeAnalyticsView()
        }
        .sheet(isPresented: $showingGoals) {
            TimeGoalsView()
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(selectedCategory: $selectedCategory)
        }
    }
    
    // MARK: - Current Tracking Card
    
    private var currentTrackingCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Tracker")
                            .font(AppTheme.Typography.headline)
                            .primaryText()
                        
                        if timeManager.isTracking {
                            Text("Tracking: \(selectedCategory)")
                                .font(AppTheme.Typography.caption1)
                                .foregroundColor(.green)
                        } else {
                            Text("Ready to track")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        Text(selectedCategory)
                            .font(AppTheme.Typography.caption1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.primary, in: Capsule())
                            .foregroundColor(.white)
                    }
                }
                
                // Timer Display
                VStack(spacing: 8) {
                    Text(formatElapsedTime())
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .primaryText()
                    
                    HStack(spacing: 16) {
                        if timeManager.isTracking {
                            Button("Pause") {
                                timeManager.pauseTracking(context: context)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Stop") {
                                timeManager.stopTracking(context: context)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else if timeManager.currentEntry != nil {
                            Button("Resume") {
                                timeManager.resumeTracking(context: context)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Stop") {
                                timeManager.stopTracking(context: context)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Start Tracking") {
                                timeManager.startTracking(category: selectedCategory, context: context)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(["Work", "Study", "Exercise", "Reading", "Creative", "Personal"], id: \.self) { category in
                    Button {
                        selectedCategory = category
                        timeManager.startTracking(category: category, context: context)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: categoryIcon(for: category))
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text(category)
                                .font(AppTheme.Typography.caption1)
                                .primaryText()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(timeManager.isTracking)
                }
            }
        }
    }
    
    // MARK: - Today's Summary
    
    private var todaySummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's Summary")
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                let todayEntries = getTodayEntries()
                let totalTime = todayEntries.reduce(0) { $0 + $1.actualDuration }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Time")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                        Text(formatDuration(totalTime))
                            .font(AppTheme.Typography.title3)
                            .primaryText()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Sessions")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                        Text("\(todayEntries.count)")
                            .font(AppTheme.Typography.title3)
                            .primaryText()
                    }
                }
                
                if !todayEntries.isEmpty {
                    // Category breakdown chart
                    let categoryData = getCategoryBreakdown(entries: todayEntries)
                    
                    Chart(categoryData, id: \.category) { item in
                        SectorMark(
                            angle: .value("Time", item.time),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", item.category))
                    }
                    .frame(height: 120)
                }
            }
        }
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                Spacer()
                
                NavigationLink("View All") {
                    TimeHistoryView()
                }
                .font(AppTheme.Typography.caption1)
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(getRecentEntries().prefix(5), id: \.id) { entry in
                    TimeEntryRow(entry: entry)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatElapsedTime() -> String {
        let duration = timeManager.elapsedTime
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
    
    private func getTodayEntries() -> [TimeEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return timeEntries.filter { entry in
            entry.startTime >= today && entry.startTime < tomorrow
        }
    }
    
    private func getRecentEntries() -> [TimeEntry] {
        return timeEntries
            .filter { !$0.isActive }
            .sorted { $0.startTime > $1.startTime }
    }
    
    private func getCategoryBreakdown(entries: [TimeEntry]) -> [CategoryTimeData] {
        var breakdown: [String: TimeInterval] = [:]
        
        for entry in entries {
            breakdown[entry.category, default: 0] += entry.actualDuration
        }
        
        return breakdown.map { CategoryTimeData(category: $0.key, time: $0.value) }
    }
}

// MARK: - Supporting Views

struct TimeEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.category)
                    .font(AppTheme.Typography.body)
                    .primaryText()
                
                Text(entry.startTime, style: .time)
                    .font(AppTheme.Typography.caption2)
                    .secondaryText()
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.formattedDuration)
                    .font(AppTheme.Typography.body)
                    .fontWeight(.medium)
                    .primaryText()
                
                if let reminder = entry.reminder {
                    Text(reminder.title)
                        .font(AppTheme.Typography.caption2)
                        .secondaryText()
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: String
    
    let categories = ["Work", "Study", "Exercise", "Reading", "Creative", "Personal", "Health", "Social", "Travel", "Other"]
    
    var body: some View {
        NavigationStack {
            List(categories, id: \.self) { category in
                Button {
                    selectedCategory = category
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: categoryIcon(for: category))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(category)
                            .primaryText()
                        
                        Spacer()
                        
                        if selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
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
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Work": return "briefcase.fill"
        case "Study": return "book.fill"
        case "Exercise": return "figure.run"
        case "Reading": return "text.book.closed.fill"
        case "Creative": return "paintbrush.fill"
        case "Personal": return "person.fill"
        case "Health": return "heart.fill"
        case "Social": return "person.2.fill"
        case "Travel": return "airplane"
        default: return "clock.fill"
        }
    }
}

struct CategoryTimeData {
    let category: String
    let time: TimeInterval
}

#Preview {
    TimeTrackingView()
        .modelContainer(for: [TimeEntry.self, TimeGoal.self, TimeCategory.self])
}
