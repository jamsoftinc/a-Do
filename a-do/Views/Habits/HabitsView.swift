//
//  HabitsView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HabitViewModel()
    @State private var showingCreateHabit = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistics Header
                HabitStatisticsView(statistics: viewModel.statistics)
                
                // Search and Filter Bar
                HabitSearchAndFilterView(
                    searchText: $viewModel.searchText,
                    selectedFilter: $viewModel.selectedFilter
                )
                
                // Habits List
                if viewModel.filteredHabits.isEmpty {
                    HabitEmptyStateView(
                        filter: viewModel.selectedFilter,
                        searchText: viewModel.searchText
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredHabits) { habit in
                                HabitCardView(habit: habit) {
                                    viewModel.selectHabit(habit)
                                } onIncrement: {
                                    viewModel.incrementHabit(habit)
                                } onDecrement: {
                                    viewModel.decrementHabit(habit)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for floating button
                    }
                }
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateHabit = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button
                Button(action: {
                    showingCreateHabit = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .sheet(isPresented: $showingCreateHabit) {
            CreateHabitView { title, description, icon, color, frequency, targetCount, unit in
                viewModel.createHabit(
                    title: title,
                    description: description,
                    icon: icon,
                    color: color,
                    frequency: frequency,
                    targetCount: targetCount,
                    unit: unit
                )
            }
        }
        .sheet(isPresented: $viewModel.showingHabitDetail) {
            if let habit = viewModel.selectedHabit {
                HabitDetailView(habit: habit)
            }
        }
    }
}

// MARK: - Habit Statistics View
struct HabitStatisticsView: View {
    let statistics: HabitStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatisticCard(
                    title: "Total",
                    value: "\(statistics.totalHabits)",
                    icon: "list.bullet",
                    color: AppTheme.Colors.primary
                )
                
                StatisticCard(
                    title: "Active",
                    value: "\(statistics.activeHabits)",
                    icon: "play.circle",
                    color: .green
                )
                
                StatisticCard(
                    title: "Today",
                    value: "\(statistics.completedToday)",
                    icon: "checkmark.circle",
                    color: .orange
                )
            }
            
            HStack(spacing: 20) {
                StatisticCard(
                    title: "Streak",
                    value: "\(statistics.totalStreak)",
                    icon: "flame",
                    color: .red
                )
                
                StatisticCard(
                    title: "Rate",
                    value: "\(Int(statistics.averageCompletionRate * 100))%",
                    icon: "chart.bar",
                    color: .blue
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.background)
        .cornerRadius(12)
    }
}

// MARK: - Search and Filter View
struct HabitSearchAndFilterView: View {
    @Binding var searchText: String
    @Binding var selectedFilter: HabitFilter
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Search habits...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.background)
            .cornerRadius(10)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HabitFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.displayName,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.surface)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.background)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Empty State View
struct HabitEmptyStateView: View {
    let filter: HabitFilter
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        }
        
        switch filter {
        case .all:
            return "star"
        case .active:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .incomplete:
            return "circle"
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No habits found"
        }
        
        switch filter {
        case .all:
            return "No habits yet"
        case .active:
            return "No active habits"
        case .completed:
            return "No completed habits"
        case .incomplete:
            return "No incomplete habits"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms"
        }
        
        switch filter {
        case .all:
            return "Create your first habit to start tracking your progress"
        case .active:
            return "All your habits are currently inactive"
        case .completed:
            return "No habits completed today yet"
        case .incomplete:
            return "All your active habits are completed today"
        }
    }
}

#Preview {
    HabitsView()
        .modelContainer(for: [Habit.self, HabitEntry.self])
}
