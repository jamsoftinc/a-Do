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
    
    @Relationship(deleteRule: .cascade) var entries: [TimeEntry] = []
    
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
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return entries.filter { entry in
            entry.startTime >= today && entry.startTime < tomorrow
        }.reduce(0) { $0 + $1.actualDuration }
    }
    
    func totalTimeThisWeek() -> TimeInterval {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date())
        
        guard let startOfWeek = weekInterval?.start,
              let endOfWeek = weekInterval?.end else { return 0 }
        
        return entries.filter { entry in
            entry.startTime >= startOfWeek && entry.startTime < endOfWeek
        }.reduce(0) { $0 + $1.actualDuration }
    }
    
    func averageTimePerDay(days: Int = 7) -> TimeInterval {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let totalTime = entries.filter { entry in
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
    var frequency: TimeGoalFrequency?
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    init(title: String, targetDuration: TimeInterval, category: String, frequency: TimeGoalFrequency? = .daily) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetDuration = targetDuration
        self.category = category
        self.frequency = frequency
        self.createdAt = Date()
    }
    
    func progressToday(entries: [TimeEntry]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let todayTime = entries.filter { entry in
            entry.category == category &&
            entry.startTime >= today &&
            entry.startTime < tomorrow
        }.reduce(0) { $0 + $1.actualDuration }
        
        return min(1.0, todayTime / targetDuration)
    }
    
    var currentProgress: Double {
        // For now, return a default progress value
        // In a real implementation, this would calculate based on actual time entries
        return 0.5
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

// MARK: - Extensions

extension Reminder {
    var totalTimeSpent: TimeInterval {
        // This would need to be computed by querying TimeEntry objects
        // For now, return 0 as a placeholder
        return 0
    }
    
    var averageCompletionTime: TimeInterval {
        // This would need to be computed by querying TimeEntry objects
        // For now, return 0 as a placeholder
        return 0
    }
}

extension Habit {
    var averageTimePerEntry: TimeInterval {
        // This would need to be computed by querying TimeEntry objects related to this habit
        // For now, return 0 as a placeholder
        return 0
    }
    
    var totalTimeInvested: TimeInterval {
        // This would need to be computed by querying TimeEntry objects related to this habit
        // For now, return 0 as a placeholder
        return 0
    }
}
