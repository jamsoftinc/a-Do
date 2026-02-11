//
//  HabitViewModels.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
@Observable
final class HabitViewModel {
    private let logger = Logger(subsystem: "a-do", category: "HabitViewModel")
    private let behavioralLearning = BehavioralLearningManager.shared
    
    var habits: [Habit] = []
    var selectedHabit: Habit?
    var showingCreateHabit = false
    var showingHabitDetail = false
    var searchText = "" {
        didSet { updateFilteredHabits() }
    }
    var selectedFilter: HabitFilter = .all {
        didSet { updateFilteredHabits() }
    }
    var statistics = HabitStatistics.empty
    
    // Cached filtered habits to prevent expensive recomputation
    var filteredHabits: [Habit] = []
    
    private var modelContext: ModelContext?
    
    init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadHabits()
        updateStatistics()
    }
    
    // MARK: - Data Loading
    
    func loadHabits() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<Habit>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            habits = try context.fetch(descriptor)
            updateStatistics()
            updateFilteredHabits()
            logger.info("Loaded \(self.habits.count) habits")
        } catch {
            logger.error("Failed to load habits: \(error.localizedDescription)")
        }
    }
    
    func updateStatistics() {
        let activeHabits = habits.filter { $0.isActive }
        let completedToday = activeHabits.filter { $0.isCompletedToday }.count
        let totalStreak = activeHabits.map { $0.currentStreak }.reduce(0, +)
        let averageCompletionRate = activeHabits.isEmpty ? 0.0 : 
            activeHabits.map { $0.completionRate }.reduce(0, +) / Double(activeHabits.count)
        
        statistics = HabitStatistics(
            totalHabits: habits.count,
            activeHabits: activeHabits.count,
            completedToday: completedToday,
            totalStreak: totalStreak,
            averageCompletionRate: averageCompletionRate
        )
    }
    
    // MARK: - Habit Management
    
    func createHabit(title: String, description: String, icon: String, color: String, frequency: HabitFrequency, targetCount: Int, unit: String) {
        guard let context = modelContext else { return }
        
        let habit = Habit(
            title: title,
            description: description,
            icon: icon,
            color: color,
            frequency: frequency,
            targetCount: targetCount,
            unit: unit
        )
        
        context.insert(habit)
        
        do {
            try context.save()
            loadHabits()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Created habit: \(title)")
        } catch {
            logger.error("Failed to create habit: \(error.localizedDescription)")
        }
    }
    
    func updateHabit(_ habit: Habit, title: String, description: String, icon: String, color: String, frequency: HabitFrequency, targetCount: Int, unit: String) {
        habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.habitDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.icon = icon
        habit.color = color
        habit.frequency = frequency
        habit.targetCount = max(1, targetCount)
        habit.unit = unit
        habit.updatedAt = Date()
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Updated habit: \(title)")
        } catch {
            logger.error("Failed to update habit: \(error.localizedDescription)")
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        guard let context = modelContext else { return }
        
        context.delete(habit)
        
        do {
            try context.save()
            loadHabits()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Deleted habit: \(habit.title)")
        } catch {
            logger.error("Failed to delete habit: \(error.localizedDescription)")
        }
    }
    
    func toggleHabitActive(_ habit: Habit) {
        habit.isActive.toggle()
        habit.updatedAt = Date()
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Toggled habit active state: \(habit.title)")
        } catch {
            logger.error("Failed to toggle habit: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Habit Entry Management
    
    func incrementHabit(_ habit: Habit) {
        _ = habit.isCompletedToday // Track completion state before increment
        habit.incrementToday()
        let currentTime = Date()
        
        // Determine timing relative to optimal time
        let timing: HabitTiming = {
            // For now, we'll use a simple heuristic based on time of day
            let hour = Calendar.current.component(.hour, from: currentTime)
            if hour < 10 {
                return .early
            } else if hour > 18 {
                return .late
            } else {
                return .onTime
            }
        }()
        
        // Track habit completion for behavioral learning
        if let context = modelContext {
            behavioralLearning.trackHabitCompletion(
                habit: habit,
                completed: habit.isCompletedToday,
                timing: timing,
                modelContext: context
            )
        }
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Incremented habit: \(habit.title)")
        } catch {
            logger.error("Failed to increment habit: \(error.localizedDescription)")
        }
    }
    
    func decrementHabit(_ habit: Habit) {
        habit.decrementToday()
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Decremented habit: \(habit.title)")
        } catch {
            logger.error("Failed to decrement habit: \(error.localizedDescription)")
        }
    }
    
    func setHabitCount(_ habit: Habit, count: Int) {
        habit.addEntry(count: count)
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Set habit count: \(habit.title) to \(count)")
        } catch {
            logger.error("Failed to set habit count: \(error.localizedDescription)")
        }
    }
    
    func addHabitEntry(_ habit: Habit, count: Int, notes: String, date: Date) {
        habit.addEntry(count: count, notes: notes, date: date)
        
        do {
            try modelContext?.save()
            updateStatistics()
            refreshWidgetSnapshotsIfPossible()
            logger.info("Added habit entry: \(habit.title)")
        } catch {
            logger.error("Failed to add habit entry: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Filtering and Search
    
    private func updateFilteredHabits() {
        var filtered = habits
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { habit in
                habit.title.localizedCaseInsensitiveContains(searchText) ||
                habit.habitDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.isActive }
        case .completed:
            filtered = filtered.filter { $0.isCompletedToday }
        case .incomplete:
            filtered = filtered.filter { !$0.isCompletedToday && $0.isActive }
        }
        
        self.filteredHabits = filtered
    }
    
    // MARK: - Navigation
    
    func selectHabit(_ habit: Habit) {
        selectedHabit = habit
        showingHabitDetail = true
    }
    
    func showCreateHabit() {
        showingCreateHabit = true
    }
    
    func dismissCreateHabit() {
        showingCreateHabit = false
    }
    
    func dismissHabitDetail() {
        showingHabitDetail = false
        selectedHabit = nil
    }

    private func refreshWidgetSnapshotsIfPossible() {
        guard let modelContext else { return }
        WidgetSnapshotManager.shared.refreshSnapshots(context: modelContext)
    }
}

// MARK: - Habit Filter Enum
enum HabitFilter: String, CaseIterable {
    case all = "all"
    case active = "active"
    case completed = "completed"
    case incomplete = "incomplete"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .completed: return "Completed"
        case .incomplete: return "Incomplete"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .active: return "play.circle"
        case .completed: return "checkmark.circle"
        case .incomplete: return "circle"
        }
    }
}

// MARK: - Habit Detail View Model
@MainActor
@Observable
final class HabitDetailViewModel {
    var habit: Habit
    var selectedTimeframe: HabitTimeframe = .week
    var showingEditHabit = false
    var showingAddEntry = false
    
    private let logger = Logger(subsystem: "a-do", category: "HabitDetailViewModel")
    
    init(habit: Habit) {
        self.habit = habit
    }
    
    var entriesForTimeframe: [HabitEntry] {
        switch selectedTimeframe {
        case .week:
            return habit.getEntriesForWeek()
        case .month:
            return habit.getEntriesForMonth()
        }
    }
    
    var completionRateForTimeframe: Double {
        let entries = entriesForTimeframe
        guard !entries.isEmpty else { return 0.0 }
        
        let completedDays = entries.filter { $0.count >= habit.targetCount }.count
        return Double(completedDays) / Double(entries.count)
    }
    
    var averageCountForTimeframe: Double {
        let entries = entriesForTimeframe
        guard !entries.isEmpty else { return 0.0 }
        
        let totalCount = entries.reduce(0) { $0 + $1.count }
        return Double(totalCount) / Double(entries.count)
    }
    
    func showEditHabit() {
        showingEditHabit = true
    }
    
    func showAddEntry() {
        showingAddEntry = true
    }
    
    func dismissEditHabit() {
        showingEditHabit = false
    }
    
    func dismissAddEntry() {
        showingAddEntry = false
    }
}

// MARK: - Habit Timeframe Enum
enum HabitTimeframe: String, CaseIterable {
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        }
    }
    
    var icon: String {
        switch self {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        }
    }
}
