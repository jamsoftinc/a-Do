//
//  TimeTrackingModels.swift
//  a-do
//
//  Enhanced time tracking and analytics models
//

import Foundation
import SwiftData

// MARK: - Time Entry Model
@Model
final class TimeEntry {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var duration: TimeInterval = 0
    var category: String = "Work"
    var notes: String = ""
    var isActive: Bool = false
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    @Relationship(deleteRule: .nullify) var habit: Habit?
    @Relationship(deleteRule: .nullify) var timeCategory: TimeCategory?
    
    init(startTime: Date = Date(), category: String = "Work", reminder: Reminder? = nil, habit: Habit? = nil) {
        self.startTime = startTime
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reminder = reminder
        self.habit = habit
        self.isActive = true
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var actualDuration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else if isActive {
            return Date().timeIntervalSince(startTime)
        }
        return duration
    }
    
    var formattedDuration: String {
        let duration = actualDuration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var isRunning: Bool {
        return isActive && endTime == nil
    }
    
    // MARK: - Methods
    
    func stop() {
        guard isActive else { return }
        endTime = Date()
        duration = actualDuration
        isActive = false
    }
    
    func pause() {
        guard isActive else { return }
        duration += Date().timeIntervalSince(startTime)
        isActive = false
    }
    
    func resume() {
        guard !isActive else { return }
        startTime = Date()
        isActive = true
    }
}

// MARK: - Time Category Model
@Model
final class TimeCategory {
    var name: String = ""
    var colorHex: String = "#007AFF"
    var icon: String = "clock.fill"
    var targetHoursPerDay: Double = 0
    var targetHoursPerWeek: Double = 0
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade) var entries: [TimeEntry]? = []
    
    
    init(name: String, colorHex: String = "#007AFF", icon: String = "clock.fill") {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = Date()
    }
    
    // MARK: - Analytics
    
    func totalTimeToday() -> TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return 0
        }

        return (entries ?? []).filter { entry in
            entry.startTime >= today && entry.startTime < tomorrow
        }.reduce(0) { $0 + $1.actualDuration }
    }
    
    func totalTimeThisWeek() -> TimeInterval {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date())
        
        guard let startOfWeek = weekInterval?.start,
              let endOfWeek = weekInterval?.end else { return 0 }
        
        return (entries ?? []).filter { entry in
            entry.startTime >= startOfWeek && entry.startTime < endOfWeek
        }.reduce(0) { $0 + $1.actualDuration }
    }
    
    func averageTimePerDay(days: Int = 7) -> TimeInterval {
        // Guard against invalid days parameter
        guard days > 0 else { return 0 }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return 0
        }

        let totalTime = (entries ?? []).filter { entry in
            entry.startTime >= startDate && entry.startTime <= endDate
        }.reduce(0) { $0 + $1.actualDuration }

        return totalTime / Double(days)
    }
}

// MARK: - Productivity Analytics
struct ProductivityAnalytics {
    let totalTimeTracked: TimeInterval
    let mostProductiveHour: Int
    let mostProductiveDay: String
    let averageFocusSession: TimeInterval
    let categoriesBreakdown: [String: TimeInterval]
    let weeklyTrend: [Double]
    let completionRate: Double
    let streakDays: Int
    
    static let empty = ProductivityAnalytics(
        totalTimeTracked: 0,
        mostProductiveHour: 9,
        mostProductiveDay: "Monday",
        averageFocusSession: 0,
        categoriesBreakdown: [:],
        weeklyTrend: [],
        completionRate: 0,
        streakDays: 0
    )
}

// MARK: - Time Goal Model
@Model
final class TimeGoal {
    var id: UUID = UUID()
    var title: String = ""
    var targetDuration: TimeInterval = 3600 // 1 hour default
    var category: String = ""
    var frequencyRaw: String?
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    // Computed property for frequency
    var frequency: TimeGoalFrequency? {
        get {
            guard let frequencyRaw = frequencyRaw else { return nil }
            return TimeGoalFrequency(rawValue: frequencyRaw)
        }
        set {
            frequencyRaw = newValue?.rawValue
        }
    }
    
    
    init(title: String, targetDuration: TimeInterval, category: String, frequency: TimeGoalFrequency? = .daily) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetDuration = targetDuration
        self.category = category
        self.frequencyRaw = frequency?.rawValue
        self.createdAt = Date()
    }
    
    func progressToday(entries: [TimeEntry]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return 0
        }

        // Guard against division by zero
        guard targetDuration > 0 else { return 0 }

        let todayTime = entries.filter { entry in
            entry.category == category &&
            entry.startTime >= today &&
            entry.startTime < tomorrow
        }.reduce(0) { $0 + $1.actualDuration }

        return min(1.0, todayTime / targetDuration)
    }
    
    /// Current progress based on goal frequency
    /// Note: This requires entries to be passed in for accurate calculation
    /// Use progressToday(entries:) or progressThisPeriod(entries:) for accurate results
    var currentProgress: Double {
        // Without context, we return 0 - use progressToday/progressThisPeriod methods with entries
        return 0.0
    }

    /// Progress for current period based on frequency
    func progressThisPeriod(entries: [TimeEntry]) -> Double {
        let calendar = Calendar.current
        let now = Date()

        let periodStart: Date
        let periodEnd: Date

        switch frequency {
        case .daily, .none:
            // Default to daily if frequency is not set
            periodStart = calendar.startOfDay(for: now)
            periodEnd = calendar.date(byAdding: .day, value: 1, to: periodStart) ?? now
        case .weekly:
            let weekday = calendar.component(.weekday, from: now)
            periodStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: now)) ?? now
            periodEnd = calendar.date(byAdding: .day, value: 7, to: periodStart) ?? now
        case .monthly:
            var components = calendar.dateComponents([.year, .month], from: now)
            periodStart = calendar.date(from: components) ?? now
            components.month = (components.month ?? 1) + 1
            periodEnd = calendar.date(from: components) ?? now
        }

        let periodTime = entries.filter { entry in
            entry.category == category &&
            entry.startTime >= periodStart &&
            entry.startTime < periodEnd
        }.reduce(0) { $0 + $1.actualDuration }

        return min(1.0, periodTime / targetDuration)
    }
}

enum TimeGoalFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Time Tracking Extensions

extension Reminder {
    /// Calculate total time spent on this reminder from time entries
    func totalTimeSpent(entries: [TimeEntry]) -> TimeInterval {
        return entries.filter { $0.reminder?.uuid == self.uuid }
            .reduce(0) { $0 + $1.actualDuration }
    }

    /// Calculate average time spent per session on this reminder
    func averageSessionTime(entries: [TimeEntry]) -> TimeInterval {
        let reminderEntries = entries.filter { $0.reminder?.uuid == self.uuid }
        guard !reminderEntries.isEmpty else { return 0 }
        let totalTime = reminderEntries.reduce(0) { $0 + $1.actualDuration }
        return totalTime / Double(reminderEntries.count)
    }
}

extension Habit {
    /// Calculate average time per habit entry from time tracking data
    func averageTimePerEntry(entries: [TimeEntry]) -> TimeInterval {
        let habitEntries = entries.filter { $0.habit?.id == self.id }
        guard !habitEntries.isEmpty else { return 0 }
        let totalTime = habitEntries.reduce(0) { $0 + $1.actualDuration }
        return totalTime / Double(habitEntries.count)
    }

    /// Calculate total time invested in this habit
    func totalTimeInvested(entries: [TimeEntry]) -> TimeInterval {
        return entries.filter { $0.habit?.id == self.id }
            .reduce(0) { $0 + $1.actualDuration }
    }

    /// Get time tracked this week for the habit
    func timeThisWeek(entries: [TimeEntry]) -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: now)) ?? now

        return entries.filter { entry in
            entry.habit?.id == self.id && entry.startTime >= weekStart
        }.reduce(0) { $0 + $1.actualDuration }
    }
}
