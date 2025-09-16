//
//  TimeGoalDetailView.swift
//  a-do
//
//  Time goal details and management
//

import SwiftUI
import SwiftData
import Charts

struct TimeGoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let goal: TimeGoal
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    
    @Query private var timeEntries: [TimeEntry]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Goal Header
                    goalHeader
                    
                    // Progress Overview
                    progressOverview
                    
                    // Daily Progress Chart
                    dailyProgressChart
                    
                    // Recent Activity
                    recentActivity
                    
                    // Goal Statistics
                    goalStatistics
                }
                .padding()
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Goal") {
                            showingEditView = true
                        }
                        
                        Button(goal.isActive ? "Pause Goal" : "Resume Goal") {
                            toggleActive()
                        }
                        
                        Button("Delete Goal", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditTimeGoalView(goal: goal)
        }
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }
    
    private var goalHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: categoryIcon(for: goal.category))
                .font(.system(size: 60))
                .foregroundColor(categoryColor(for: goal.category))
            
            VStack(spacing: 8) {
                Text(goal.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .primaryText()
                    .multilineTextAlignment(.center)
                
                HStack {
                    Text(goal.category)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(categoryColor(for: goal.category).opacity(0.2))
                        .foregroundColor(categoryColor(for: goal.category))
                        .cornerRadius(8)
                    
                    Text(goal.isActive ? "Active" : "Paused")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(goal.isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(goal.isActive ? .green : .gray)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Overview")
                .font(.headline)
                .primaryText()
            
            VStack(spacing: 12) {
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(goal.currentProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(goal.currentProgress >= 1.0 ? .green : .primary)
                    }
                    
                    ProgressView(value: goal.currentProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: goal.currentProgress >= 1.0 ? .green : .blue))
                }
                
                // Time Details
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(goal.targetDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .primaryText()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(goal.targetDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .primaryText()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(goal.targetDuration * goal.currentProgress))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(goal.currentProgress >= 1.0 ? .green : .orange)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var dailyProgressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Progress")
                .font(.headline)
                .primaryText()
            
            let dailyData = getDailyProgressData()
            
            if dailyData.isEmpty {
                Text("No progress data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(dailyData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Time", item.time)
                    )
                    .foregroundStyle(categoryColor(for: goal.category))
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .primaryText()
            
            let recentEntries = getRecentEntries()
            
            if recentEntries.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentEntries.prefix(5), id: \.id) { entry in
                        RecentActivityRow(entry: entry)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var goalStatistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .primaryText()
            
            let stats = calculateStatistics()
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Sessions",
                    value: "\(stats.sessionCount)",
                    icon: "number",
                    color: .blue
                )
                
                StatCard(
                    title: "Avg Session",
                    value: formatDuration(stats.averageSession),
                    icon: "timer",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Best Day",
                    value: formatDuration(stats.bestDay),
                    icon: "star.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Days Active",
                    value: "\(stats.activeDays)",
                    icon: "calendar",
                    color: .purple
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Methods
    
    private func getDailyProgressData() -> [DailyProgressData] {
        let calendar = Calendar.current
        var dailyTotals: [Date: TimeInterval] = [:]
        
        let goalEntries = timeEntries.filter { $0.category == goal.category }
        
        for entry in goalEntries {
            let day = calendar.startOfDay(for: entry.startTime)
            dailyTotals[day, default: 0] += entry.actualDuration
        }
        
        return dailyTotals.map { DailyProgressData(date: $0.key, time: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private func getRecentEntries() -> [TimeEntry] {
        return timeEntries
            .filter { $0.category == goal.category }
            .sorted { $0.startTime > $1.startTime }
    }
    
    private func calculateStatistics() -> GoalStatistics {
        let goalEntries = timeEntries.filter { $0.category == goal.category }
        
        let sessionCount = goalEntries.count
        let averageSession = sessionCount > 0 ? goalEntries.reduce(0) { $0 + $1.actualDuration } / Double(sessionCount) : 0
        
        let dailyData = getDailyProgressData()
        let bestDay = dailyData.max(by: { $0.time < $1.time })?.time ?? 0
        let activeDays = dailyData.count
        
        return GoalStatistics(
            sessionCount: sessionCount,
            averageSession: averageSession,
            bestDay: bestDay,
            activeDays: activeDays
        )
    }
    
    private func toggleActive() {
        goal.isActive.toggle()
        try? context.save()
    }
    
    private func deleteGoal() {
        context.delete(goal)
        try? context.save()
        dismiss()
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
        case "Health": return "heart.fill"
        case "Social": return "person.2.fill"
        case "Travel": return "airplane"
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
        case "Health": return .red
        case "Social": return .cyan
        case "Travel": return .mint
        default: return .secondary
        }
    }
}

struct RecentActivityRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let reminder = entry.reminder {
                    Text(reminder.title)
                        .font(.body)
                        .primaryText()
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(entry.formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct StatCard: View {
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

// MARK: - Supporting Types

struct DailyProgressData {
    let date: Date
    let time: TimeInterval
}

struct GoalStatistics {
    let sessionCount: Int
    let averageSession: TimeInterval
    let bestDay: TimeInterval
    let activeDays: Int
}

#Preview {
    let goal = TimeGoal(title: "Daily Work", targetDuration: 28800, category: "Work")
    goal.isActive = true
    
    return TimeGoalDetailView(goal: goal)
        .modelContainer(for: [TimeGoal.self, TimeEntry.self])
}
