//
//  TimeGoalsView.swift
//  a-do
//
//  Time tracking goals and targets
//

import SwiftUI
import SwiftData
import Charts

struct TimeGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private var timeManager = TimeTrackingManager.shared
    
    @Query private var timeGoals: [TimeGoal]
    @Query private var timeEntries: [TimeEntry]
    
    @State private var showingCreateGoal = false
    @State private var selectedGoal: TimeGoal?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Goals Overview
                    goalsOverview
                    
                    // Active Goals
                    activeGoalsSection
                    
                    // Goal Progress
                    goalProgressSection
                }
                .padding()
            }
            .navigationTitle("Time Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateGoal) {
            CreateTimeGoalView()
        }
        .sheet(item: $selectedGoal) { goal in
            TimeGoalDetailView(goal: goal)
        }
    }
    
    private var goalsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goals Overview")
                .font(.headline)
                .primaryText()
            
            let activeGoals = timeGoals.filter { $0.isActive }
            let completedGoals = timeGoals.filter { !$0.isActive }
            let totalProgress = calculateOverallProgress()
            
            HStack(spacing: 12) {
                OverviewCard(
                    title: "Active Goals",
                    value: "\(activeGoals.count)",
                    icon: "target",
                    color: .blue
                )
                
                OverviewCard(
                    title: "Completed",
                    value: "\(completedGoals.count)",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                OverviewCard(
                    title: "Overall Progress",
                    value: "\(Int(totalProgress * 100))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
                
                OverviewCard(
                    title: "This Week",
                    value: formatWeekProgress(),
                    icon: "calendar",
                    color: .orange
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Goals")
                .font(.headline)
                .primaryText()
            
            let activeGoals = timeGoals.filter { $0.isActive }
            
            if activeGoals.isEmpty {
                EmptyGoalsView {
                    showingCreateGoal = true
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activeGoals, id: \.id) { goal in
                        TimeGoalCard(goal: goal) {
                            selectedGoal = goal
                        }
                    }
                }
            }
        }
    }
    
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress This Week")
                .font(.headline)
                .primaryText()
            
            let weeklyProgress = getWeeklyProgress()
            
            if weeklyProgress.isEmpty {
                Text("No progress data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(weeklyProgress, id: \.goal.id) { item in
                    BarMark(
                        x: .value("Goal", item.goal.title),
                        y: .value("Progress", item.progress)
                    )
                    .foregroundStyle(by: .value("Goal", item.goal.title))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallProgress() -> Double {
        let activeGoals = timeGoals.filter { $0.isActive }
        guard !activeGoals.isEmpty else { return 0 }
        
        let totalProgress = activeGoals.reduce(0.0) { $0 + $1.currentProgress }
        return totalProgress / Double(activeGoals.count)
    }
    
    private func formatWeekProgress() -> String {
        let weeklyProgress = getWeeklyProgress()
        let completedGoals = weeklyProgress.filter { $0.progress >= 1.0 }.count
        return "\(completedGoals)/\(weeklyProgress.count)"
    }
    
    private func getWeeklyProgress() -> [GoalProgressData] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return timeGoals.compactMap { goal in
            let weeklyEntries = timeEntries.filter { entry in
                entry.category == goal.category &&
                entry.startTime >= weekStart &&
                entry.startTime <= now
            }
            
            let weeklyTime = weeklyEntries.reduce(0) { $0 + $1.actualDuration }
            let progress = min(weeklyTime / goal.targetDuration, 1.0)
            
            return GoalProgressData(goal: goal, progress: progress)
        }
    }
}

struct OverviewCard: View {
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

struct TimeGoalCard: View {
    let goal: TimeGoal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                            .primaryText()
                        
                        Text(goal.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(goal.currentProgress * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(goal.currentProgress >= 1.0 ? .green : .primary)
                        
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                ProgressView(value: goal.currentProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.currentProgress >= 1.0 ? .green : .blue))
                
                HStack {
                    Text("Target: \(formatDuration(goal.targetDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Current: \(formatDuration(goal.targetDuration * goal.currentProgress))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
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
}

struct EmptyGoalsView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Active Goals")
                .font(.headline)
                .primaryText()
            
            Text("Create time goals to track your productivity and stay motivated.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Create Goal") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
        }
        .padding()
    }
}

struct GoalProgressData {
    let goal: TimeGoal
    let progress: Double
}

#Preview {
    TimeGoalsView()
        .modelContainer(for: [TimeGoal.self, TimeEntry.self])
}
