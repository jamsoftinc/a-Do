//
//  HabitDetailView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData
import Charts

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let habit: Habit
    @State private var viewModel: HabitDetailViewModel
    @State private var showingEditHabit = false
    @State private var showingAddEntry = false
    
    init(habit: Habit) {
        self.habit = habit
        self._viewModel = State(initialValue: HabitDetailViewModel(habit: habit))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    HabitDetailHeaderCard(habit: habit)
                    
                    // Quick Actions
                    HabitDetailQuickActions(
                        habit: habit,
                        onIncrement: {
                            habit.incrementToday()
                            try? modelContext.save()
                        },
                        onDecrement: {
                            habit.decrementToday()
                            try? modelContext.save()
                        },
                        onEdit: {
                            showingEditHabit = true
                        }
                    )
                    
                    // Statistics Cards
                    HabitDetailStatisticsCards(habit: habit)
                    
                    // Timeframe Selector
                    HabitTimeframeSelector(
                        selectedTimeframe: $viewModel.selectedTimeframe
                    )
                    
                    // Progress Chart
                    HabitProgressChart(
                        habit: habit,
                        timeframe: viewModel.selectedTimeframe
                    )
                    
                    // Recent Entries
                    HabitRecentEntriesView(
                        habit: habit,
                        timeframe: viewModel.selectedTimeframe
                    )
                }
                .padding()
            }
            .navigationTitle(habit.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingEditHabit = true
                        }) {
                            Label("Edit Habit", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            showingAddEntry = true
                        }) {
                            Label("Add Entry", systemImage: "plus")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            // TODO: Implement delete confirmation
                        }) {
                            Label("Delete Habit", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditHabit) {
            EditHabitView(habit: habit)
        }
        .sheet(isPresented: $showingAddEntry) {
            AddHabitEntryView(habit: habit)
        }
    }
}

// MARK: - Habit Detail Header Card
struct HabitDetailHeaderCard: View {
    let habit: Habit
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: habit.color) ?? AppTheme.Colors.primary)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: habit.icon)
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if !habit.habitDescription.isEmpty {
                        Text(habit.habitDescription)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    HStack(spacing: 16) {
                        Text(habit.frequency.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary.opacity(0.1))
                            .foregroundColor(AppTheme.Colors.primary)
                            .cornerRadius(8)
                        
                        Text("\(habit.targetCount) \(habit.unit)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.background)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            
            // Today's Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Today's Progress")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(habit.todayEntry?.count ?? 0) / \(habit.targetCount)")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                ProgressView(value: habit.progressToday)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.color) ?? AppTheme.Colors.primary))
                    .frame(height: 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(AppTheme.Colors.background)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Habit Detail Quick Actions
struct HabitDetailQuickActions: View {
    let habit: Habit
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Decrement Button
            Button(action: onDecrement) {
                VStack(spacing: 8) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text("Remove")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.background)
                .cornerRadius(12)
            }
            .disabled(!habit.isActive || (habit.todayEntry?.count ?? 0) <= 0)
            
            // Current Count Display
            VStack(spacing: 4) {
                Text("\(habit.todayEntry?.count ?? 0)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Today")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.background)
            .cornerRadius(12)
            
            // Increment Button
            Button(action: onIncrement) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("Add")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.background)
                .cornerRadius(12)
            }
            .disabled(!habit.isActive)
        }
    }
}

// MARK: - Habit Detail Statistics Cards
struct HabitDetailStatisticsCards: View {
    let habit: Habit
    
    var body: some View {
        HStack(spacing: 12) {
            StatisticCard(
                title: "Current Streak",
                value: "\(habit.currentStreak)",
                icon: "flame.fill",
                color: .orange
            )
            
            StatisticCard(
                title: "Longest Streak",
                value: "\(habit.longestStreak)",
                icon: "trophy.fill",
                color: .yellow
            )
            
            StatisticCard(
                title: "Completion Rate",
                value: "\(Int(habit.completionRate * 100))%",
                icon: "chart.bar.fill",
                color: .blue
            )
        }
    }
}

// MARK: - Habit Timeframe Selector
struct HabitTimeframeSelector: View {
    @Binding var selectedTimeframe: HabitTimeframe
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(HabitTimeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    selectedTimeframe = timeframe
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: timeframe.icon)
                            .font(.caption)
                        
                        Text(timeframe.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedTimeframe == timeframe ? AppTheme.Colors.primary : AppTheme.Colors.background)
                    .foregroundColor(selectedTimeframe == timeframe ? .white : AppTheme.Colors.textPrimary)
                    .cornerRadius(20)
                }
            }
        }
    }
}

// MARK: - Habit Progress Chart
struct HabitProgressChart: View {
    let habit: Habit
    let timeframe: HabitTimeframe
    @State private var viewModel: HabitDetailViewModel
    
    init(habit: Habit, timeframe: HabitTimeframe) {
        self.habit = habit
        self.timeframe = timeframe
        self._viewModel = State(initialValue: HabitDetailViewModel(habit: habit))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Chart")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Simple progress visualization
            VStack(spacing: 16) {
                HStack {
                    Text("Progress")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.completionRateForTimeframe * 100))%")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                ProgressView(value: viewModel.completionRateForTimeframe)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.color) ?? AppTheme.Colors.primary))
                    .frame(height: 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                HStack {
                    Text("Average: \(String(format: "%.1f", viewModel.averageCountForTimeframe)) \(habit.unit)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("Target: \(habit.targetCount) \(habit.unit)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(AppTheme.Colors.background)
        .cornerRadius(16)
    }
    
    private var entriesForTimeframe: [HabitEntry] {
        switch timeframe {
        case .week:
            return habit.getEntriesForWeek()
        case .month:
            return habit.getEntriesForMonth()
        }
    }
}

// MARK: - Habit Recent Entries View
struct HabitRecentEntriesView: View {
    let habit: Habit
    let timeframe: HabitTimeframe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if entriesForTimeframe.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.title)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("No entries yet")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entriesForTimeframe.prefix(10), id: \.date) { entry in
                        HabitEntryRow(entry: entry, targetCount: habit.targetCount)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.background)
        .cornerRadius(16)
    }
    
    private var entriesForTimeframe: [HabitEntry] {
        switch timeframe {
        case .week:
            return habit.getEntriesForWeek()
        case .month:
            return habit.getEntriesForMonth()
        }
    }
}

// MARK: - Habit Entry Row
struct HabitEntryRow: View {
    let entry: HabitEntry
    let targetCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 80, alignment: .leading)
            
            // Count
            HStack(spacing: 4) {
                Text("\(entry.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(entry.count >= targetCount ? .green : AppTheme.Colors.textPrimary)
                
                Text("/ \(targetCount)")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 60, alignment: .center)
            
            // Progress Bar
            ProgressView(value: Double(entry.count), total: Double(targetCount))
                .progressViewStyle(LinearProgressViewStyle(tint: entry.count >= targetCount ? .green : AppTheme.Colors.primary))
                .frame(height: 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(3)
            
            // Notes
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(8)
    }
}

#Preview {
    HabitDetailView(habit: Habit(title: "Drink Water", description: "Stay hydrated", icon: "drop.fill", color: "#007AFF"))
}
