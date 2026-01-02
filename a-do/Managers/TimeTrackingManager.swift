//
//  TimeTrackingManager.swift
//  a-do
//
//  Time tracking and analytics manager
//

import Foundation
import SwiftData
import Observation
import Combine
import os

@MainActor
@Observable
final class TimeTrackingManager: ObservableObject {
    static let shared = TimeTrackingManager()
    
    private let logger = Logger(subsystem: "a-do", category: "TimeTracking")

    // Current tracking state
    var currentEntry: TimeEntry?
    var isTracking: Bool = false
    var elapsedTime: TimeInterval = 0

    // Timer for updating elapsed time
    // Timer is managed on MainActor - cleanup called before deallocation
    private var timer: Timer?

    private init() {}

    /// Call this method before the manager is deallocated to clean up resources
    func cleanup() {
        timer?.invalidate()
        timer = nil
        currentEntry = nil
        isTracking = false
    }
    
    // MARK: - Time Tracking

    func startTracking(for reminder: Reminder? = nil, habit: Habit? = nil, category: String = "Work", context: ModelContext) {
        // Stop any existing tracking
        if let current = currentEntry, current.isActive {
            stopTracking(context: context)
        }
        
        let entry = TimeEntry(category: category, reminder: reminder, habit: habit)
        context.insert(entry)
        
        currentEntry = entry
        isTracking = true
        elapsedTime = 0
        
        startTimer()
        
        do {
            try context.save()
            logger.info("Started time tracking for category: \(category)")
        } catch {
            logger.error("Failed to start time tracking: \(error.localizedDescription)")
        }
    }
    
    func stopTracking(context: ModelContext) {
        guard let entry = currentEntry, entry.isActive else { return }
        
        entry.stop()
        isTracking = false
        stopTimer()
        
        do {
            try context.save()
            logger.info("Stopped time tracking. Duration: \(entry.formattedDuration)")
        } catch {
            logger.error("Failed to stop time tracking: \(error.localizedDescription)")
        }
        
        currentEntry = nil
        elapsedTime = 0
    }
    
    func pauseTracking(context: ModelContext) {
        guard let entry = currentEntry, entry.isActive else { return }
        
        entry.pause()
        isTracking = false
        stopTimer()
        
        do {
            try context.save()
            logger.info("Paused time tracking")
        } catch {
            logger.error("Failed to pause time tracking: \(error.localizedDescription)")
        }
    }
    
    func resumeTracking(context: ModelContext) {
        guard let entry = currentEntry, !entry.isActive else { return }
        
        entry.resume()
        isTracking = true
        startTimer()
        
        do {
            try context.save()
            logger.info("Resumed time tracking")
        } catch {
            logger.error("Failed to resume time tracking: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard let entry = currentEntry, entry.isActive else { return }
        elapsedTime = entry.actualDuration
    }
    
    // MARK: - Analytics
    
    func getProductivityAnalytics(context: ModelContext, days: Int = 30) -> ProductivityAnalytics {
        let descriptor = FetchDescriptor<TimeEntry>()
        let entries = (try? context.fetch(descriptor)) ?? []
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            logger.error("Failed to calculate start date for analytics")
            return ProductivityAnalytics.empty
        }
        
        let filteredEntries = entries.filter { entry in
            entry.startTime >= startDate && entry.startTime <= endDate
        }
        
        // Calculate analytics
        let totalTime = filteredEntries.reduce(0) { $0 + $1.actualDuration }
        let mostProductiveHour = calculateMostProductiveHour(entries: filteredEntries)
        let mostProductiveDay = calculateMostProductiveDay(entries: filteredEntries)
        let averageFocusSession = calculateAverageFocusSession(entries: filteredEntries)
        let categoriesBreakdown = calculateCategoriesBreakdown(entries: filteredEntries)
        let weeklyTrend = calculateWeeklyTrend(entries: filteredEntries, days: days)
        let completionRate = calculateCompletionRate(entries: filteredEntries, context: context)
        let streakDays = calculateStreakDays(entries: filteredEntries)
        
        return ProductivityAnalytics(
            totalTimeTracked: totalTime,
            mostProductiveHour: mostProductiveHour,
            mostProductiveDay: mostProductiveDay,
            averageFocusSession: averageFocusSession,
            categoriesBreakdown: categoriesBreakdown,
            weeklyTrend: weeklyTrend,
            completionRate: completionRate,
            streakDays: streakDays
        )
    }
    
    private func calculateMostProductiveHour(entries: [TimeEntry]) -> Int {
        var hourlyTime: [Int: TimeInterval] = [:]
        
        for entry in entries {
            let hour = Calendar.current.component(.hour, from: entry.startTime)
            hourlyTime[hour, default: 0] += entry.actualDuration
        }
        
        return hourlyTime.max(by: { $0.value < $1.value })?.key ?? 9
    }
    
    private func calculateMostProductiveDay(entries: [TimeEntry]) -> String {
        var dailyTime: [String: TimeInterval] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        for entry in entries {
            let day = formatter.string(from: entry.startTime)
            dailyTime[day, default: 0] += entry.actualDuration
        }
        
        return dailyTime.max(by: { $0.value < $1.value })?.key ?? "Monday"
    }
    
    private func calculateAverageFocusSession(entries: [TimeEntry]) -> TimeInterval {
        guard !entries.isEmpty else { return 0 }
        let totalTime = entries.reduce(0) { $0 + $1.actualDuration }
        return totalTime / Double(entries.count)
    }
    
    private func calculateCategoriesBreakdown(entries: [TimeEntry]) -> [String: TimeInterval] {
        var breakdown: [String: TimeInterval] = [:]
        
        for entry in entries {
            breakdown[entry.category, default: 0] += entry.actualDuration
        }
        
        return breakdown
    }
    
    private func calculateWeeklyTrend(entries: [TimeEntry], days: Int) -> [Double] {
        let calendar = Calendar.current
        let weeks = days / 7
        var weeklyTotals: [Double] = []
        
        for week in 0..<weeks {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: Date())!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            
            let weekEntries = entries.filter { entry in
                entry.startTime >= weekStart && entry.startTime < weekEnd
            }
            
            let weekTotal = weekEntries.reduce(0) { $0 + $1.actualDuration }
            weeklyTotals.append(weekTotal / 3600) // Convert to hours
        }
        
        return weeklyTotals.reversed()
    }
    
    private func calculateCompletionRate(entries: [TimeEntry], context: ModelContext) -> Double {
        let remindersWithTime = entries.compactMap { $0.reminder }
        let completedReminders = remindersWithTime.filter { $0.isCompleted }
        
        guard !remindersWithTime.isEmpty else { return 0 }
        return Double(completedReminders.count) / Double(remindersWithTime.count)
    }
    
    private func calculateStreakDays(entries: [TimeEntry]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        let maxIterations = 365 // Prevent infinite loops - max 1 year streak calculation
        var iterations = 0
        
        while iterations < maxIterations {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            let dayEntries = entries.filter { entry in
                entry.startTime >= currentDate && entry.startTime < nextDay
            }
            
            if dayEntries.isEmpty {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            iterations += 1
        }
        
        return streak
    }
    
    // MARK: - Time Goals
    
    func createTimeGoal(title: String, targetDuration: TimeInterval, category: String, frequency: TimeGoalFrequency, context: ModelContext) {
        let goal = TimeGoal(title: title, targetDuration: targetDuration, category: category, frequency: frequency)
        context.insert(goal)
        
        do {
            try context.save()
            logger.info("Created time goal: \(title)")
        } catch {
            logger.error("Failed to create time goal: \(error.localizedDescription)")
        }
    }
    
    func getTimeGoalProgress(goal: TimeGoal, context: ModelContext) -> Double {
        let descriptor = FetchDescriptor<TimeEntry>()
        let entries = (try? context.fetch(descriptor)) ?? []
        return goal.progressToday(entries: entries)
    }
    
    // MARK: - Categories Management
    
    func createCategory(name: String, colorHex: String, icon: String, context: ModelContext) {
        let category = TimeCategory(name: name, colorHex: colorHex, icon: icon)
        context.insert(category)
        
        do {
            try context.save()
            logger.info("Created time category: \(name)")
        } catch {
            logger.error("Failed to create time category: \(error.localizedDescription)")
        }
    }
    
    func getCategories(context: ModelContext) -> [TimeCategory] {
        let descriptor = FetchDescriptor<TimeCategory>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Reporting
    
    func generateTimeReport(startDate: Date, endDate: Date, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<TimeEntry>()
        let allEntries = (try? context.fetch(descriptor)) ?? []
        
        let entries = allEntries.filter { entry in
            entry.startTime >= startDate && entry.startTime <= endDate
        }
        
        let totalTime = entries.reduce(0) { $0 + $1.actualDuration }
        let categoriesBreakdown = calculateCategoriesBreakdown(entries: entries)
        
        var report = "Time Tracking Report\n"
        report += "Period: \(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))\n\n"
        report += "Total Time Tracked: \(formatDuration(totalTime))\n\n"
        report += "Categories Breakdown:\n"
        
        for (category, time) in categoriesBreakdown.sorted(by: { $0.value > $1.value }) {
            let percentage = (time / totalTime) * 100
            report += "• \(category): \(formatDuration(time)) (\(String(format: "%.1f", percentage))%)\n"
        }
        
        return report
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}
