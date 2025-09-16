//
//  TimeAnalyticsView.swift
//  a-do
//
//  Time tracking analytics and insights
//

import SwiftUI
import SwiftData
import Charts

struct TimeAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var timeManager = TimeTrackingManager.shared
    
    @Query private var timeEntries: [TimeEntry]
    @State private var selectedPeriod = AnalyticsPeriod.week
    @State private var selectedCategory = "All"
    
    let categories = ["All", "Work", "Study", "Exercise", "Reading", "Creative", "Personal"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelector
                    
                    // Summary Cards
                    summaryCards
                    
                    // Category Breakdown
                    categoryBreakdown
                    
                    // Time Trends
                    timeTrends
                    
                    // Productivity Insights
                    productivityInsights
                }
                .padding()
            }
            .navigationTitle("Time Analytics")
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
    
    private var periodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period")
                .font(.headline)
                .primaryText()
            
            Picker("Period", selection: $selectedPeriod) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var summaryCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .primaryText()
            
            let filteredEntries = getFilteredEntries()
            let totalTime = filteredEntries.reduce(0) { $0 + $1.actualDuration }
            let averageSession = filteredEntries.isEmpty ? 0 : totalTime / Double(filteredEntries.count)
            let mostProductiveDay = getMostProductiveDay(entries: filteredEntries)
            
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Total Time",
                    value: formatDuration(totalTime),
                    icon: "clock.fill",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Sessions",
                    value: "\(filteredEntries.count)",
                    icon: "number",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Avg Session",
                    value: formatDuration(averageSession),
                    icon: "timer",
                    color: .orange
                )
                
                SummaryCard(
                    title: "Best Day",
                    value: mostProductiveDay,
                    icon: "star.fill",
                    color: .purple
                )
            }
        }
    }
    
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)
                .primaryText()
            
            let filteredEntries = getFilteredEntries()
            let categoryData = getCategoryBreakdown(entries: filteredEntries)
            
            if categoryData.isEmpty {
                Text("No time entries for this period")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(categoryData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Time", item.time),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .frame(height: 200)
                
                // Category Legend
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(categoryData, id: \.category) { item in
                        HStack {
                            Circle()
                                .fill(categoryColor(for: item.category))
                                .frame(width: 12, height: 12)
                            
                            Text(item.category)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(formatDuration(item.time))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var timeTrends: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Trends")
                .font(.headline)
                .primaryText()
            
            let filteredEntries = getFilteredEntries()
            let dailyData = getDailyTrends(entries: filteredEntries)
            
            if dailyData.isEmpty {
                Text("No trend data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(dailyData, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Time", item.time)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Time", item.time)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var productivityInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Insights")
                .font(.headline)
                .primaryText()
            
            let filteredEntries = getFilteredEntries()
            let insights = generateInsights(entries: filteredEntries)
            
            LazyVStack(spacing: 8) {
                ForEach(insights, id: \.title) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Methods
    
    private func getFilteredEntries() -> [TimeEntry] {
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
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        var entries = timeEntries.filter { $0.startTime >= startDate }
        
        if selectedCategory != "All" {
            entries = entries.filter { $0.category == selectedCategory }
        }
        
        return entries
    }
    
    private func getCategoryBreakdown(entries: [TimeEntry]) -> [CategoryTimeData] {
        var breakdown: [String: TimeInterval] = [:]
        
        for entry in entries {
            breakdown[entry.category, default: 0] += entry.actualDuration
        }
        
        return breakdown.map { CategoryTimeData(category: $0.key, time: $0.value) }
            .sorted { $0.time > $1.time }
    }
    
    private func getDailyTrends(entries: [TimeEntry]) -> [DailyTimeData] {
        let calendar = Calendar.current
        var dailyTotals: [Date: TimeInterval] = [:]
        
        for entry in entries {
            let day = calendar.startOfDay(for: entry.startTime)
            dailyTotals[day, default: 0] += entry.actualDuration
        }
        
        return dailyTotals.map { DailyTimeData(date: $0.key, time: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private func getMostProductiveDay(entries: [TimeEntry]) -> String {
        let dailyData = getDailyTrends(entries: entries)
        guard let bestDay = dailyData.max(by: { $0.time < $1.time }) else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: bestDay.date)
    }
    
    private func generateInsights(entries: [TimeEntry]) -> [ProductivityInsight] {
        var insights: [ProductivityInsight] = []
        
        if entries.isEmpty {
            insights.append(ProductivityInsight(
                title: "No Data",
                description: "Start tracking time to see insights",
                type: .info
            ))
            return insights
        }
        
        let totalTime = entries.reduce(0) { $0 + $1.actualDuration }
        let averageSession = totalTime / Double(entries.count)
        
        if averageSession > 3600 { // More than 1 hour
            insights.append(ProductivityInsight(
                title: "Long Sessions",
                description: "You're maintaining good focus with long work sessions",
                type: .positive
            ))
        }
        
        let categoryBreakdown = getCategoryBreakdown(entries: entries)
        if let topCategory = categoryBreakdown.first {
            insights.append(ProductivityInsight(
                title: "Top Category",
                description: "You spend most time on \(topCategory.category) activities",
                type: .neutral
            ))
        }
        
        return insights
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

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .primaryText()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct InsightRow: View {
    let insight: ProductivityInsight
    
    var body: some View {
        HStack {
            Image(systemName: insight.type.icon)
                .foregroundColor(insight.type.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .primaryText()
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Types

enum AnalyticsPeriod: CaseIterable {
    case day, week, month, year
    
    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}


struct DailyTimeData {
    let date: Date
    let time: TimeInterval
}

struct ProductivityInsight {
    let title: String
    let description: String
    let type: InsightType
}

enum InsightType {
    case positive, neutral, negative, info
    
    var icon: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .neutral: return "info.circle.fill"
        case .negative: return "exclamationmark.triangle.fill"
        case .info: return "info.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .blue
        case .negative: return .orange
        case .info: return .gray
        }
    }
}

#Preview {
    TimeAnalyticsView()
        .modelContainer(for: [TimeEntry.self])
}
