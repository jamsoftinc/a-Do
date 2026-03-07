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
        NavigationStack {
            List {
                // Statistics
                Section {
                    HabitStatisticsView(statistics: viewModel.statistics)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Filter
                Section {
                    HabitFilterView(selectedFilter: $viewModel.selectedFilter)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                // Habits List
                if viewModel.filteredHabits.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label(
                                viewModel.searchText.isEmpty ? "No Habits" : "No Results",
                                systemImage: viewModel.searchText.isEmpty ? "star" : "magnifyingglass"
                            )
                        } description: {
                            Text(viewModel.searchText.isEmpty
                                 ? "Create your first habit to start tracking."
                                 : "Try adjusting your search terms.")
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
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
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $viewModel.searchText, prompt: "Search habits")
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatisticItem(title: "Total", value: "\(statistics.totalHabits)", color: .accentColor)
                StatisticItem(title: "Active", value: "\(statistics.activeHabits)", color: .green)
                StatisticItem(title: "Today", value: "\(statistics.completedToday)", color: .orange)
            }

            HStack(spacing: 16) {
                StatisticItem(title: "Streak", value: "\(statistics.totalStreak)", color: .red)
                StatisticItem(title: "Rate", value: "\(Int(statistics.averageCompletionRate * 100))%", color: .blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Statistic Item
struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter View
struct HabitFilterView: View {
    @Binding var selectedFilter: HabitFilter

    var body: some View {
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
        }
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
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill),
                        in: Capsule())
            .foregroundStyle(isSelected ? .white : Color(.label))
        }
    }
}


#Preview {
    HabitsView()
        .modelContainer(for: [Habit.self, HabitEntry.self])
}
