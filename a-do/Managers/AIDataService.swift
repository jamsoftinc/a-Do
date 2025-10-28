//
//  AIDataService.swift
//  a-do
//
//  Service layer for connecting real productivity data to AI features
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class AIDataService {
    static let shared = AIDataService()
    
    private let logger = Logger(subsystem: "a-do", category: "AIDataService")
    private let timeTrackingManager = TimeTrackingManager.shared
    private let focusModeManager = FocusModeManager.shared

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    private init() {}
    
    // MARK: - Productivity Data Integration

    func getProductivityMetrics(context: ModelContext, timeframe: AIInsightTimeframe = .week) -> ProductivityMetrics {
        guard isProEnabled else {
            logger.warning("AI productivity metrics is a Pro feature")
            return ProductivityMetrics(
                totalFocusTime: 0,
                totalTimeTracked: 0,
                averageProductivityScore: 0,
                completionRate: 0,
                totalSessions: 0,
                totalInterruptions: 0,
                averageSessionLength: 0,
                mostProductiveHour: 0,
                timeframe: timeframe
            )
        }

        let dateRange = getDateRange(for: timeframe)
        let startDate = dateRange.start
        let endDate = dateRange.end
        
        // Fetch time entries
        let timeDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
        )
        let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
        
        // Fetch focus sessions
        let focusDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        let focusSessions = (try? context.fetch(focusDescriptor)) ?? []
        
        // Fetch reminders for completion analysis
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                (reminder.completedAt != nil && 
                 reminder.completedAt! >= startDate && 
                 reminder.completedAt! <= endDate) ||
                (reminder.dueDate != nil &&
                 reminder.dueDate! >= startDate &&
                 reminder.dueDate! <= endDate)
            }
        )
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        // Calculate metrics
        return calculateProductivityMetrics(
            timeEntries: timeEntries,
            focusSessions: focusSessions,
            reminders: reminders,
            timeframe: timeframe
        )
    }
    
    func getHabitMetrics(context: ModelContext, timeframe: AIInsightTimeframe = .week) -> HabitMetrics {
        guard isProEnabled else {
            logger.warning("AI habit metrics is a Pro feature")
            return HabitMetrics(
                totalHabits: 0,
                habitsWithActiveStreak: 0,
                averageStreak: 0,
                totalCompletions: 0,
                bestPerformingHabit: "None",
                overallCompletionRate: 0
            )
        }

        let dateRange = getDateRange(for: timeframe)
        
        // Fetch active habits
        let habitsDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitsDescriptor)) ?? []
        
        return calculateHabitMetrics(habits: habits, dateRange: dateRange)
    }
    
    func getTimeUsageMetrics(context: ModelContext, timeframe: AIInsightTimeframe = .week) -> TimeUsageMetrics {
        let dateRange = getDateRange(for: timeframe)
        let startDate = dateRange.start
        let endDate = dateRange.end
        
        let timeDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
        )
        let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
        
        return calculateTimeUsageMetrics(timeEntries: timeEntries, timeframe: timeframe)
    }
    
    func getFocusEffectivenessMetrics(context: ModelContext, timeframe: AIInsightTimeframe = .week) -> FocusEffectivenessMetrics {
        let dateRange = getDateRange(for: timeframe)
        let startDate = dateRange.start
        let endDate = dateRange.end
        
        let focusDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        let focusSessions = (try? context.fetch(focusDescriptor)) ?? []
        
        return calculateFocusEffectivenessMetrics(sessions: focusSessions, timeframe: timeframe)
    }
    
    // MARK: - Chart Data Generation
    
    func getProductivityTrendData(context: ModelContext, days: Int = 7) -> [ProductivityDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        var dataPoints: [ProductivityDataPoint] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            // Get focus sessions for this day
            let focusDescriptor = FetchDescriptor<FocusSession>(
                predicate: #Predicate { session in
                    session.startTime >= dayStart && session.startTime < dayEnd
                }
            )
            let sessions = (try? context.fetch(focusDescriptor)) ?? []
            
            // Calculate daily productivity score
            let score = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
            
            dataPoints.append(ProductivityDataPoint(
                date: date,
                score: score,
                sessions: sessions.count,
                focusTime: sessions.reduce(0) { $0 + $1.actualDuration }
            ))
        }
        
        return dataPoints
    }
    
    func getHabitCompletionData(context: ModelContext, days: Int = 7) -> [HabitCompletionData] {
        let habitsDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitsDescriptor)) ?? []
        
        return habits.prefix(10).map { habit in
            let completionRate = calculateHabitCompletionRate(habit: habit, days: days)
            return HabitCompletionData(
                name: habit.title,
                completionRate: completionRate,
                streak: habit.currentStreak,
                color: getHabitColor(for: habit.title)
            )
        }
    }
    
    func getTimeDistributionData(context: ModelContext, days: Int = 7) -> [TimeDistributionData] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let timeDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
        )
        let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
        
        var categoryTotals: [String: TimeInterval] = [:]
        for entry in timeEntries {
            categoryTotals[entry.category, default: 0] += entry.actualDuration
        }
        
        let totalTime = categoryTotals.values.reduce(0, +)
        
        return categoryTotals.map { category, time in
            TimeDistributionData(
                category: category,
                hours: time / 3600, // Convert to hours
                percentage: totalTime > 0 ? (time / totalTime) * 100 : 0,
                color: getCategoryColor(for: category)
            )
        }.sorted { $0.hours > $1.hours }
    }
    
    // MARK: - Private Helper Methods
    
    private func getDateRange(for timeframe: AIInsightTimeframe) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endDate = Date()
        
        let startDate: Date
        switch timeframe {
        case .day:
            startDate = calendar.startOfDay(for: endDate)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        return (start: startDate, end: endDate)
    }
    
    private func calculateProductivityMetrics(
        timeEntries: [TimeEntry],
        focusSessions: [FocusSession],
        reminders: [Reminder],
        timeframe: AIInsightTimeframe
    ) -> ProductivityMetrics {
        let totalFocusTime = focusSessions.reduce(0) { $0 + $1.actualDuration }
        let totalTimeTracked = timeEntries.reduce(0) { $0 + $1.actualDuration }
        let averageProductivityScore = focusSessions.isEmpty ? 0 : 
            focusSessions.reduce(0) { $0 + $1.productivityScore } / Double(focusSessions.count)
        
        let completedReminders = reminders.filter { $0.isCompleted }
        let completionRate = reminders.isEmpty ? 0 : Double(completedReminders.count) / Double(reminders.count)
        
        let totalInterruptions = focusSessions.reduce(0) { $0 + $1.interruptionCount }
        let averageSessionLength = focusSessions.isEmpty ? 0 : totalFocusTime / Double(focusSessions.count)
        
        return ProductivityMetrics(
            totalFocusTime: totalFocusTime,
            totalTimeTracked: totalTimeTracked,
            averageProductivityScore: averageProductivityScore,
            completionRate: completionRate,
            totalSessions: focusSessions.count,
            totalInterruptions: totalInterruptions,
            averageSessionLength: averageSessionLength,
            mostProductiveHour: calculateMostProductiveHour(sessions: focusSessions),
            timeframe: timeframe
        )
    }
    
    private func calculateHabitMetrics(habits: [Habit], dateRange: (start: Date, end: Date)) -> HabitMetrics {
        let activeHabits = habits.filter { $0.isActive }
        let habitsWithStreak = activeHabits.filter { $0.currentStreak > 0 }
        let averageStreak = habitsWithStreak.isEmpty ? 0 : 
            Double(habitsWithStreak.reduce(0) { $0 + $1.currentStreak }) / Double(habitsWithStreak.count)
        
        let totalCompletions = habits.reduce(0) { total, habit in
            total + (habit.entries?.count ?? 0)
        }
        
        let bestPerformingHabit = habits.max { $0.currentStreak < $1.currentStreak }
        
        return HabitMetrics(
            totalHabits: activeHabits.count,
            habitsWithActiveStreak: habitsWithStreak.count,
            averageStreak: averageStreak,
            totalCompletions: totalCompletions,
            bestPerformingHabit: bestPerformingHabit?.title ?? "None",
            overallCompletionRate: calculateOverallHabitCompletionRate(habits: activeHabits)
        )
    }
    
    private func calculateTimeUsageMetrics(timeEntries: [TimeEntry], timeframe: AIInsightTimeframe) -> TimeUsageMetrics {
        let totalTime = timeEntries.reduce(0) { $0 + $1.actualDuration }
        
        var categoryBreakdown: [String: TimeInterval] = [:]
        for entry in timeEntries {
            categoryBreakdown[entry.category, default: 0] += entry.actualDuration
        }
        
        let topCategory = categoryBreakdown.max { $0.value < $1.value }?.key ?? "None"
        let averageSessionLength = timeEntries.isEmpty ? 0 : totalTime / Double(timeEntries.count)
        
        return TimeUsageMetrics(
            totalTimeTracked: totalTime,
            categoryBreakdown: categoryBreakdown,
            topCategory: topCategory,
            averageSessionLength: averageSessionLength,
            totalSessions: timeEntries.count,
            mostActiveDay: calculateMostActiveDay(entries: timeEntries)
        )
    }
    
    private func calculateFocusEffectivenessMetrics(sessions: [FocusSession], timeframe: AIInsightTimeframe) -> FocusEffectivenessMetrics {
        let completedSessions = sessions.filter { $0.wasCompleted }
        let completionRate = sessions.isEmpty ? 0 : Double(completedSessions.count) / Double(sessions.count)
        
        let averageProductivityScore = sessions.isEmpty ? 0 : 
            sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        
        let totalInterruptions = sessions.reduce(0) { $0 + $1.interruptionCount }
        let averageInterruptions = sessions.isEmpty ? 0 : Double(totalInterruptions) / Double(sessions.count)
        
        let mostProductiveFocusType = calculateMostProductiveFocusType(sessions: sessions)
        
        return FocusEffectivenessMetrics(
            totalSessions: sessions.count,
            completedSessions: completedSessions.count,
            completionRate: completionRate,
            averageProductivityScore: averageProductivityScore,
            totalInterruptions: totalInterruptions,
            averageInterruptions: averageInterruptions,
            mostProductiveFocusType: mostProductiveFocusType.displayName,
            bestTimeOfDay: calculateMostProductiveHour(sessions: sessions)
        )
    }
    
    private func calculateMostProductiveHour(sessions: [FocusSession]) -> Int {
        var hourlyProductivity: [Int: Double] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyProductivity[hour, default: 0] += session.productivityScore
        }
        
        return hourlyProductivity.max { $0.value < $1.value }?.key ?? 9
    }
    
    private func calculateMostProductiveFocusType(sessions: [FocusSession]) -> FocusType {
        var typeProductivity: [FocusType: Double] = [:]
        
        for session in sessions {
            typeProductivity[session.focusType, default: 0] += session.productivityScore
        }
        
        return typeProductivity.max { $0.value < $1.value }?.key ?? .work
    }
    
    private func calculateMostActiveDay(entries: [TimeEntry]) -> String {
        var dailyTime: [String: TimeInterval] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        for entry in entries {
            let day = formatter.string(from: entry.startTime)
            dailyTime[day, default: 0] += entry.actualDuration
        }
        
        return dailyTime.max { $0.value < $1.value }?.key ?? "Monday"
    }
    
    private func calculateHabitCompletionRate(habit: Habit, days: Int) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let recentEntries = habit.entries?.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        } ?? []
        
        return Double(recentEntries.count) / Double(days)
    }
    
    private func calculateOverallHabitCompletionRate(habits: [Habit]) -> Double {
        let habitsWithEntries = habits.filter { habit in !(habit.entries?.isEmpty ?? true) }
        guard !habitsWithEntries.isEmpty else { return 0 }
        
        let totalPossibleCompletions = habitsWithEntries.count * 7 // Assuming weekly calculation
        let actualCompletions = habitsWithEntries.reduce(0) { total, habit in
            total + min(habit.entries?.count ?? 0, 7) // Cap at 7 for weekly
        }
        
        return Double(actualCompletions) / Double(totalPossibleCompletions)
    }
    
    private func getHabitColor(for title: String) -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        let index = abs(title.hashValue) % colors.count
        return colors[index]
    }
    
    private func getCategoryColor(for category: String) -> String {
        switch category.lowercased() {
        case "work": return "#007AFF"
        case "study": return "#34C759"
        case "exercise": return "#FF9500"
        case "reading": return "#AF52DE"
        case "creative": return "#FF2D92"
        case "personal": return "#8E8E93"
        default: return "#007AFF"
        }
    }
}

// MARK: - Data Models

struct ProductivityMetrics {
    let totalFocusTime: TimeInterval
    let totalTimeTracked: TimeInterval
    let averageProductivityScore: Double
    let completionRate: Double
    let totalSessions: Int
    let totalInterruptions: Int
    let averageSessionLength: TimeInterval
    let mostProductiveHour: Int
    let timeframe: AIInsightTimeframe
}

struct HabitMetrics {
    let totalHabits: Int
    let habitsWithActiveStreak: Int
    let averageStreak: Double
    let totalCompletions: Int
    let bestPerformingHabit: String
    let overallCompletionRate: Double
}

struct TimeUsageMetrics {
    let totalTimeTracked: TimeInterval
    let categoryBreakdown: [String: TimeInterval]
    let topCategory: String
    let averageSessionLength: TimeInterval
    let totalSessions: Int
    let mostActiveDay: String
}

struct FocusEffectivenessMetrics {
    let totalSessions: Int
    let completedSessions: Int
    let completionRate: Double
    let averageProductivityScore: Double
    let totalInterruptions: Int
    let averageInterruptions: Double
    let mostProductiveFocusType: String
    let bestTimeOfDay: Int
}

struct ProductivityDataPoint {
    let date: Date
    let score: Double
    let sessions: Int
    let focusTime: TimeInterval
}

struct HabitCompletionData {
    let name: String
    let completionRate: Double
    let streak: Int
    let color: String
}

struct TimeDistributionData {
    let category: String
    let hours: Double
    let percentage: Double
    let color: String
}