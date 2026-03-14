import Foundation
import SwiftData

struct AIAnalyticsSnapshot: Sendable {
    let productivityMetrics: ProductivityMetrics
    let habitMetrics: HabitMetrics
    let timeUsageMetrics: TimeUsageMetrics
    let focusMetrics: FocusEffectivenessMetrics
    let productivityTrendData: [ProductivityDataPoint]
    let habitCompletionData: [HabitCompletionData]
    let timeDistributionData: [TimeDistributionData]
}

struct AIVisualizationSnapshot: Sendable {
    let productivityTrendData: [ProductivityDataPoint]
    let habitCompletionData: [HabitCompletionData]
    let timeDistributionData: [TimeDistributionData]
}

enum AIAnalyticsSnapshotLoader {
    nonisolated static func loadDashboard(
        container: ModelContainer,
        timeframe: AIInsightTimeframe,
        trendDays: Int = 7
    ) async -> AIAnalyticsSnapshot {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            return makeDashboardSnapshot(context: context, timeframe: timeframe, trendDays: trendDays)
        }.value
    }

    nonisolated static func loadVisualization(
        container: ModelContainer,
        days: Int
    ) async -> AIVisualizationSnapshot {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            return makeVisualizationSnapshot(context: context, days: days)
        }.value
    }

    nonisolated private static func makeDashboardSnapshot(
        context: ModelContext,
        timeframe: AIInsightTimeframe,
        trendDays: Int
    ) -> AIAnalyticsSnapshot {
        let dateRange = dateRange(for: timeframe)
        let startDate = dateRange.start
        let endDate = dateRange.end

        let timeEntries = fetchTimeEntries(context: context, startDate: startDate, endDate: endDate)
        let focusSessions = fetchFocusSessions(context: context, startDate: startDate, endDate: endDate)
        let reminders = fetchRelevantReminders(context: context, startDate: startDate, endDate: endDate)
        let habits = fetchActiveHabits(context: context)

        return AIAnalyticsSnapshot(
            productivityMetrics: makeProductivityMetrics(
                timeEntries: timeEntries,
                focusSessions: focusSessions,
                reminders: reminders,
                timeframe: timeframe
            ),
            habitMetrics: makeHabitMetrics(habits: habits),
            timeUsageMetrics: makeTimeUsageMetrics(timeEntries: timeEntries),
            focusMetrics: makeFocusMetrics(sessions: focusSessions),
            productivityTrendData: makeProductivityTrendData(context: context, days: trendDays),
            habitCompletionData: makeHabitCompletionData(habits: habits, days: trendDays),
            timeDistributionData: makeTimeDistributionData(context: context, days: trendDays)
        )
    }

    nonisolated private static func makeVisualizationSnapshot(
        context: ModelContext,
        days: Int
    ) -> AIVisualizationSnapshot {
        let habits = fetchActiveHabits(context: context)
        return AIVisualizationSnapshot(
            productivityTrendData: makeProductivityTrendData(context: context, days: max(3, days)),
            habitCompletionData: makeHabitCompletionData(habits: habits, days: days),
            timeDistributionData: makeTimeDistributionData(context: context, days: days)
        )
    }

    nonisolated private static func dateRange(for timeframe: AIInsightTimeframe) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endDate = Date()

        let startDate: Date
        switch timeframe {
        case .day:
            startDate = calendar.startOfDay(for: endDate)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }

        return (start: startDate, end: endDate)
    }

    nonisolated private static func fetchTimeEntries(context: ModelContext, startDate: Date, endDate: Date) -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    nonisolated private static func fetchFocusSessions(context: ModelContext, startDate: Date, endDate: Date) -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    nonisolated private static func fetchRelevantReminders(context: ModelContext, startDate: Date, endDate: Date) -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                (reminder.completedAt != nil &&
                 reminder.completedAt! >= startDate &&
                 reminder.completedAt! <= endDate) ||
                (reminder.dueDate != nil &&
                 reminder.dueDate! >= startDate &&
                 reminder.dueDate! <= endDate)
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    nonisolated private static func fetchActiveHabits(context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    nonisolated private static func makeProductivityMetrics(
        timeEntries: [TimeEntry],
        focusSessions: [FocusSession],
        reminders: [Reminder],
        timeframe: AIInsightTimeframe
    ) -> ProductivityMetrics {
        let totalFocusTime = focusSessions.reduce(0) { $0 + $1.actualDuration }
        let totalTimeTracked = timeEntries.reduce(0) { $0 + $1.actualDuration }
        let averageProductivityScore = focusSessions.isEmpty ? 0 :
            focusSessions.reduce(0) { $0 + $1.productivityScore } / Double(focusSessions.count)
        let completedReminders = reminders.filter(\.isCompleted)
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
            mostProductiveHour: mostProductiveHour(for: focusSessions),
            timeframe: timeframe
        )
    }

    nonisolated private static func makeHabitMetrics(habits: [Habit]) -> HabitMetrics {
        let activeHabits = habits.filter(\.isActive)
        let habitsWithStreak = activeHabits.filter { $0.currentStreak > 0 }
        let averageStreak = habitsWithStreak.isEmpty ? 0 :
            Double(habitsWithStreak.reduce(0) { $0 + $1.currentStreak }) / Double(habitsWithStreak.count)
        let totalCompletions = habits.reduce(0) { $0 + ($1.entries?.count ?? 0) }
        let bestPerformingHabit = habits.max { $0.currentStreak < $1.currentStreak }

        return HabitMetrics(
            totalHabits: activeHabits.count,
            habitsWithActiveStreak: habitsWithStreak.count,
            averageStreak: averageStreak,
            totalCompletions: totalCompletions,
            bestPerformingHabit: bestPerformingHabit?.title ?? "None",
            overallCompletionRate: overallHabitCompletionRate(for: activeHabits)
        )
    }

    nonisolated private static func makeTimeUsageMetrics(timeEntries: [TimeEntry]) -> TimeUsageMetrics {
        let totalTimeTracked = timeEntries.reduce(0) { $0 + $1.actualDuration }

        var categoryBreakdown: [String: TimeInterval] = [:]
        for entry in timeEntries {
            categoryBreakdown[entry.category, default: 0] += entry.actualDuration
        }

        return TimeUsageMetrics(
            totalTimeTracked: totalTimeTracked,
            categoryBreakdown: categoryBreakdown,
            topCategory: categoryBreakdown.max { $0.value < $1.value }?.key ?? "None",
            averageSessionLength: timeEntries.isEmpty ? 0 : totalTimeTracked / Double(timeEntries.count),
            totalSessions: timeEntries.count,
            mostActiveDay: mostActiveDay(for: timeEntries)
        )
    }

    nonisolated private static func makeFocusMetrics(sessions: [FocusSession]) -> FocusEffectivenessMetrics {
        let completedSessions = sessions.filter(\.wasCompleted)
        let completionRate = sessions.isEmpty ? 0 : Double(completedSessions.count) / Double(sessions.count)
        let averageProductivityScore = sessions.isEmpty ? 0 :
            sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        let totalInterruptions = sessions.reduce(0) { $0 + $1.interruptionCount }

        return FocusEffectivenessMetrics(
            totalSessions: sessions.count,
            completedSessions: completedSessions.count,
            completionRate: completionRate,
            averageProductivityScore: averageProductivityScore,
            totalInterruptions: totalInterruptions,
            averageInterruptions: sessions.isEmpty ? 0 : Double(totalInterruptions) / Double(sessions.count),
            mostProductiveFocusType: focusTypeName(for: mostProductiveFocusType(for: sessions)),
            bestTimeOfDay: mostProductiveHour(for: sessions)
        )
    }

    nonisolated private static func makeProductivityTrendData(context: ModelContext, days: Int) -> [ProductivityDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        var dataPoints: [ProductivityDataPoint] = []

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let descriptor = FetchDescriptor<FocusSession>(
                predicate: #Predicate { session in
                    session.startTime >= dayStart && session.startTime < dayEnd
                }
            )
            let sessions = (try? context.fetch(descriptor)) ?? []
            let score = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)

            dataPoints.append(
                ProductivityDataPoint(
                    date: date,
                    score: score,
                    sessions: sessions.count,
                    focusTime: sessions.reduce(0) { $0 + $1.actualDuration }
                )
            )
        }

        return dataPoints
    }

    nonisolated private static func makeHabitCompletionData(habits: [Habit], days: Int) -> [HabitCompletionData] {
        habits.prefix(10).map { habit in
            HabitCompletionData(
                name: habit.title,
                completionRate: habitCompletionRate(for: habit, days: days),
                streak: habit.currentStreak,
                color: habitColor(for: habit.title)
            )
        }
    }

    nonisolated private static func makeTimeDistributionData(context: ModelContext, days: Int) -> [TimeDistributionData] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let timeEntries = fetchTimeEntries(context: context, startDate: startDate, endDate: endDate)
        var categoryTotals: [String: TimeInterval] = [:]
        for entry in timeEntries {
            categoryTotals[entry.category, default: 0] += entry.actualDuration
        }

        let totalTime = categoryTotals.values.reduce(0, +)

        return categoryTotals.map { category, time in
            TimeDistributionData(
                category: category,
                hours: time / 3600,
                percentage: totalTime > 0 ? (time / totalTime) * 100 : 0,
                color: categoryColor(for: category)
            )
        }
        .sorted { $0.hours > $1.hours }
    }

    nonisolated private static func mostProductiveHour(for sessions: [FocusSession]) -> Int {
        var hourlyProductivity: [Int: Double] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyProductivity[hour, default: 0] += session.productivityScore
        }
        return hourlyProductivity.max { $0.value < $1.value }?.key ?? 9
    }

    nonisolated private static func mostProductiveFocusType(for sessions: [FocusSession]) -> FocusType {
        var typeProductivity: [FocusType: Double] = [:]
        for session in sessions {
            typeProductivity[session.focusType, default: 0] += session.productivityScore
        }
        return typeProductivity.max { $0.value < $1.value }?.key ?? .work
    }

    nonisolated private static func mostActiveDay(for entries: [TimeEntry]) -> String {
        var dailyTime: [String: TimeInterval] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        for entry in entries {
            dailyTime[formatter.string(from: entry.startTime), default: 0] += entry.actualDuration
        }

        return dailyTime.max { $0.value < $1.value }?.key ?? "Monday"
    }

    nonisolated private static func habitCompletionRate(for habit: Habit, days: Int) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return 0
        }

        let recentEntries = habit.entries?.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        } ?? []

        return Double(recentEntries.count) / Double(days)
    }

    nonisolated private static func overallHabitCompletionRate(for habits: [Habit]) -> Double {
        let habitsWithEntries = habits.filter { !($0.entries?.isEmpty ?? true) }
        guard !habitsWithEntries.isEmpty else { return 0 }

        let totalPossibleCompletions = habitsWithEntries.count * 7
        let actualCompletions = habitsWithEntries.reduce(0) { total, habit in
            total + min(habit.entries?.count ?? 0, 7)
        }

        return Double(actualCompletions) / Double(totalPossibleCompletions)
    }

    nonisolated private static func habitColor(for title: String) -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return colors[abs(title.hashValue) % colors.count]
    }

    nonisolated private static func categoryColor(for category: String) -> String {
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

    nonisolated private static func focusTypeName(for focusType: FocusType) -> String {
        switch focusType {
        case .work: return "Work"
        case .study: return "Study"
        case .reading: return "Reading"
        case .exercise: return "Exercise"
        case .meditation: return "Meditation"
        case .creative: return "Creative"
        case .personal: return "Personal"
        case .custom: return "Custom"
        }
    }
}

extension AIInsightTimeframe: Sendable {}
