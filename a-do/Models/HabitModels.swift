//
//  HabitModels.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import Foundation
import SwiftData

// MARK: - Habit Model
@Model
final class Habit {
    var id: UUID = UUID()
    var title: String = ""
    var habitDescription: String = ""
    var icon: String = "star.fill"
    var color: String = "#007AFF"
    var frequency: HabitFrequency?
    var targetCount: Int = 1
    var unit: String = "times"
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var entries: [HabitEntry]? = []
    @Relationship var tags: [Tag]? = []
    @Relationship(deleteRule: .cascade) var timeEntries: [TimeEntry]? = []
    
    init(title: String, description: String = "", icon: String = "star.fill", color: String = "#007AFF", frequency: HabitFrequency? = .daily, targetCount: Int = 1, unit: String = "times") {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.habitDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.color = color
        self.frequency = frequency
        self.targetCount = max(1, targetCount)
        self.unit = unit
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        // Sort entries by date (most recent first)
        let sortedEntries = (entries ?? []).sorted { $0.date > $1.date }
        
        for entry in sortedEntries {
            let entryDate = calendar.startOfDay(for: entry.date)
            
            if entryDate == currentDate {
                // Check if target was met for this day
                if entry.count >= targetCount {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else if entryDate < currentDate {
                // Skip to the entry date
                currentDate = entryDate
                if entry.count >= targetCount {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            }
        }
        
        return streak
    }
    
    var longestStreak: Int {
        let calendar = Calendar.current
        let sortedEntries = (entries ?? []).sorted { $0.date < $1.date }
        var maxStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for entry in sortedEntries {
            let entryDate = calendar.startOfDay(for: entry.date)
            
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entryDate).day ?? 0
                
                if daysBetween == 1 {
                    // Consecutive day
                    if entry.count >= targetCount {
                        currentStreak += 1
                    } else {
                        maxStreak = max(maxStreak, currentStreak)
                        currentStreak = 0
                    }
                } else if daysBetween > 1 {
                    // Gap in days, reset streak
                    maxStreak = max(maxStreak, currentStreak)
                    currentStreak = entry.count >= targetCount ? 1 : 0
                }
            } else {
                // First entry
                currentStreak = entry.count >= targetCount ? 1 : 0
            }
            
            lastDate = entryDate
        }
        
        return max(maxStreak, currentStreak)
    }
    
    var completionRate: Double {
        guard let entries = entries, !entries.isEmpty else { return 0.0 }
        
        let completedDays = entries.filter { $0.count >= targetCount }.count
        return Double(completedDays) / Double(entries.count)
    }
    
    var todayEntry: HabitEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return entries?.first { calendar.isDate($0.date, inSameDayAs: today) }
    }
    
    var isCompletedToday: Bool {
        guard let todayEntry = todayEntry else { return false }
        return todayEntry.count >= targetCount
    }
    
    var progressToday: Double {
        guard let todayEntry = todayEntry else { return 0.0 }
        return min(1.0, Double(todayEntry.count) / Double(targetCount))
    }
}

// MARK: - Habit Entry Model
@Model
final class HabitEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var count: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .nullify) var habit: Habit?
    
    init(date: Date = Date(), count: Int = 0, notes: String = "", habit: Habit? = nil) {
        self.date = date
        self.count = max(0, count)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.habit = habit
        self.createdAt = Date()
    }
}

// MARK: - Habit Frequency Enum
enum HabitFrequency: String, CaseIterable, Codable {
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
    
    var icon: String {
        switch self {
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.badge.plus"
        }
    }
}

// MARK: - Habit Statistics
struct HabitStatistics {
    let totalHabits: Int
    let activeHabits: Int
    let completedToday: Int
    let totalStreak: Int
    let averageCompletionRate: Double
    
    static let empty = HabitStatistics(
        totalHabits: 0,
        activeHabits: 0,
        completedToday: 0,
        totalStreak: 0,
        averageCompletionRate: 0.0
    )
}

// MARK: - Habit Extensions
extension Habit {
    func addEntry(count: Int, notes: String = "", date: Date = Date()) {
        let calendar = Calendar.current
        let entryDate = calendar.startOfDay(for: date)
        
        // Check if entry already exists for this date
        if let existingEntry = entries?.first(where: { calendar.isDate($0.date, inSameDayAs: entryDate) }) {
            existingEntry.count = max(0, count)
            existingEntry.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            existingEntry.createdAt = Date()
        } else {
            let newEntry = HabitEntry(date: entryDate, count: max(0, count), notes: notes, habit: self)
            entries?.append(newEntry)
        }
        
        updatedAt = Date()
    }
    
    func incrementToday() {
        let currentCount = todayEntry?.count ?? 0
        addEntry(count: currentCount + 1)
    }
    
    func decrementToday() {
        let currentCount = todayEntry?.count ?? 0
        addEntry(count: max(0, currentCount - 1))
    }
    
    func getEntriesForWeek(containing date: Date = Date()) -> [HabitEntry] {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)
        
        guard let startOfWeek = weekInterval?.start,
              let endOfWeek = weekInterval?.end else { return [] }
        
        return (entries ?? []).filter { entry in
            entry.date >= startOfWeek && entry.date < endOfWeek
        }.sorted { $0.date < $1.date }
    }
    
    func getEntriesForMonth(containing date: Date = Date()) -> [HabitEntry] {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)
        
        guard let startOfMonth = monthInterval?.start,
              let endOfMonth = monthInterval?.end else { return [] }
        
        return (entries ?? []).filter { entry in
            entry.date >= startOfMonth && entry.date < endOfMonth
        }.sorted { $0.date < $1.date }
    }
}
