//
//  RecurringModels.swift
//  a-do
//
//  Recurring reminders and templates models
//

import Foundation
import SwiftData

// MARK: - Recurrence Pattern
enum RecurrencePattern: String, CaseIterable, Codable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .none: return "No Repeat"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "circle"
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.badge.plus"
        case .yearly: return "calendar.badge.exclamationmark"
        case .weekdays: return "briefcase"
        case .weekends: return "house"
        case .custom: return "gearshape"
        }
    }
}

// MARK: - Recurrence Rule
@Model
final class RecurrenceRule {
    var id: UUID = UUID()
    var patternRaw: String = RecurrencePattern.none.rawValue
    var interval: Int = 1 // Every X days/weeks/months
    var endDate: Date?
    var maxOccurrences: Int?
    var daysOfWeek: Data? // JSON encoded [Int] - 1-7 for Sunday-Saturday
    var dayOfMonth: Int? // For monthly recurrence
    var monthOfYear: Int? // For yearly recurrence
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    // Custom recurrence settings
    var customDays: Data? // JSON encoded [Int] - Custom days for complex patterns
    var skipWeekends: Bool = false
    var skipHolidays: Bool = false
    
    // Relationships
    @Relationship(deleteRule: .nullify) var recurringReminder: RecurringReminder?
    
    // Computed property for pattern
    var pattern: RecurrencePattern {
        get { RecurrencePattern(rawValue: patternRaw) ?? .none }
        set { patternRaw = newValue.rawValue }
    }
    
    
    init(pattern: RecurrencePattern = .none, interval: Int = 1) {
        self.patternRaw = pattern.rawValue
        self.interval = max(1, interval)
        self.createdAt = Date()
    }
    
    // MARK: - Next Occurrence Calculation
    
    func nextOccurrence(after date: Date) -> Date? {
        guard isActive else { return nil }
        
        let calendar = Calendar.current
        var nextDate = date
        
        switch pattern {
        case .none:
            return nil
            
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: interval, to: date) ?? date
            
        case .weekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
            
        case .monthly:
            if let dayOfMonth = dayOfMonth {
                var components = calendar.dateComponents([.year, .month], from: date)
                components.day = dayOfMonth
                if let monthDate = calendar.date(from: components), monthDate > date {
                    nextDate = monthDate
                } else {
                    components.month = (components.month ?? 1) + interval
                    nextDate = calendar.date(from: components) ?? date
                }
            } else {
                nextDate = calendar.date(byAdding: .month, value: interval, to: date) ?? date
            }
            
        case .yearly:
            nextDate = calendar.date(byAdding: .year, value: interval, to: date) ?? date
            
        case .weekdays:
            nextDate = nextWeekday(after: date)
            
        case .weekends:
            nextDate = nextWeekend(after: date)
            
        case .custom:
            nextDate = nextCustomOccurrence(after: date)
        }
        
        // Check end conditions
        if let endDate = endDate, nextDate > endDate {
            return nil
        }
        
        return nextDate
    }
    
    private func nextWeekday(after date: Date) -> Date {
        let calendar = Calendar.current
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        while calendar.isDateInWeekend(nextDate) {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func nextWeekend(after date: Date) -> Date {
        let calendar = Calendar.current
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        while !calendar.isDateInWeekend(nextDate) {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func nextCustomOccurrence(after date: Date) -> Date {
        let calendar = Calendar.current
        
        if let daysOfWeekData = daysOfWeek, let daysOfWeekArray = try? JSONDecoder().decode([Int].self, from: daysOfWeekData), !daysOfWeekArray.isEmpty {
            // Find next occurrence based on days of week
            var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let maxDays = 14 // Look ahead 2 weeks maximum
            
            for _ in 0..<maxDays {
                let weekday = calendar.component(.weekday, from: nextDate)
                if daysOfWeekArray.contains(weekday) {
                    return nextDate
                }
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
        }
        
        // Fallback to daily interval
        return calendar.date(byAdding: .day, value: interval, to: date) ?? date
    }
    
    // MARK: - Validation
    
    func isValid() -> Bool {
        switch pattern {
        case .none:
            return true
        case .daily, .weekly:
            return interval > 0
        case .monthly:
            return interval > 0 && (dayOfMonth == nil || (dayOfMonth! >= 1 && dayOfMonth! <= 31))
        case .yearly:
            return interval > 0
        case .weekdays, .weekends:
            return true
        case .custom:
            if let daysOfWeekData = daysOfWeek, let daysOfWeekArray = try? JSONDecoder().decode([Int].self, from: daysOfWeekData) {
                return !daysOfWeekArray.isEmpty || interval > 0
            }
            return interval > 0
        }
    }
}

// MARK: - Recurring Reminder
@Model
final class RecurringReminder {
    var id: UUID = UUID()
    var templateTitle: String = ""
    var templateDetails: String?
    var templatePriority: Int = 0
    var templateTags: Data? // JSON encoded [String]
    var templateCategory: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()
    var lastGenerated: Date?
    var nextDue: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var recurrenceRule: RecurrenceRule?
    @Relationship(deleteRule: .cascade) var generatedReminders: [Reminder]? = []
    @Relationship(deleteRule: .cascade) var templateNotifications: [ReminderNotification]? = []
    
    init(title: String, details: String? = nil, priority: Priority = .none, recurrenceRule: RecurrenceRule? = nil) {
        self.templateTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.templateDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.templatePriority = priority.rawValue
        self.recurrenceRule = recurrenceRule
        self.createdAt = Date()
        self.calculateNextDue()
    }
    
    var priority: Priority {
        get { Priority(rawValue: templatePriority) ?? .none }
        set { templatePriority = newValue.rawValue }
    }
    
    // MARK: - Next Due Calculation
    
    func calculateNextDue() {
        guard let rule = recurrenceRule else {
            nextDue = nil
            return
        }
        
        let baseDate = lastGenerated ?? createdAt
        nextDue = rule.nextOccurrence(after: baseDate)
    }
    
    // MARK: - Reminder Generation
    
    func shouldGenerateReminder() -> Bool {
        guard isActive, let nextDue = nextDue else { return false }
        return nextDue <= Date()
    }
    
    func generateReminder() -> Reminder? {
        guard shouldGenerateReminder() else { return nil }
        
        let reminder = Reminder(
            title: templateTitle,
            details: templateDetails,
            dueDate: nextDue,
            priority: priority
        )
        
        // Copy template notifications
        for templateNotification in templateNotifications ?? [] {
            let notification = ReminderNotification(
                leadTimeSeconds: templateNotification.leadTimeSeconds,
                customSoundName: templateNotification.customSoundName
            )
            reminder.notifications?.append(notification)
        }
        
        generatedReminders?.append(reminder)
        lastGenerated = Date()
        calculateNextDue()
        
        return reminder
    }
}

// MARK: - Reminder Template
@Model
final class ReminderTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var title: String = ""
    var details: String?
    var priority: Int = 0
    var category: String = ""
    var tags: Data? // JSON encoded [String]
    var estimatedDuration: TimeInterval?
    var defaultDueOffset: TimeInterval? // Default time from now when creating
    var icon: String = "doc.text"
    var colorHex: String = "#007AFF"
    var isActive: Bool = true
    var usageCount: Int = 0
    var createdAt: Date = Date()
    var lastUsed: Date?
    
    // Template settings
    var includeLocation: Bool = false
    var includeContacts: Bool = false
    var includeNotes: Bool = false
    var autoTextEnabled: Bool = false
    
    // Relationships
    @Relationship(deleteRule: .cascade) var templateNotifications: [ReminderNotification]? = []
    @Relationship(deleteRule: .nullify) var templateCategory: TemplateCategory?
    
    init(name: String, title: String, details: String? = nil, category: String = "", priority: Priority = .none) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.priority = priority.rawValue
        self.createdAt = Date()
    }
    
    var priorityEnum: Priority {
        get { Priority(rawValue: priority) ?? .none }
        set { priority = newValue.rawValue }
    }
    
    // MARK: - Reminder Creation
    
    func createReminder(customDueDate: Date? = nil) -> Reminder {
        let dueDate: Date?
        if let customDueDate = customDueDate {
            dueDate = customDueDate
        } else if let offset = defaultDueOffset {
            dueDate = Date().addingTimeInterval(offset)
        } else {
            dueDate = nil
        }
        
        let reminder = Reminder(
            title: title,
            details: details,
            dueDate: dueDate,
            priority: priorityEnum,
            autoTextTaggedContacts: autoTextEnabled,
            autoTextMe: autoTextEnabled
        )
        
        // Copy template notifications
        for templateNotification in templateNotifications ?? [] {
            let notification = ReminderNotification(
                leadTimeSeconds: templateNotification.leadTimeSeconds,
                customSoundName: templateNotification.customSoundName
            )
            reminder.notifications?.append(notification)
        }
        
        // Update usage statistics
        usageCount += 1
        lastUsed = Date()
        
        return reminder
    }
    
    // MARK: - Template Categories
    
    static let defaultCategories = [
        "Work", "Personal", "Health", "Finance", "Travel", "Shopping", "Learning", "Social"
    ]
    
    static func defaultTemplates() -> [ReminderTemplate] {
        return [
            ReminderTemplate(
                name: "Daily Standup",
                title: "Daily Team Standup",
                details: "Share yesterday's progress, today's goals, and any blockers",
                category: "Work",
                priority: .medium
            ),
            ReminderTemplate(
                name: "Weekly Review",
                title: "Weekly Goals Review",
                details: "Review completed goals and plan for next week",
                category: "Personal",
                priority: .high
            ),
            ReminderTemplate(
                name: "Doctor Appointment",
                title: "Doctor Appointment",
                details: "Remember to bring insurance card and list of medications",
                category: "Health",
                priority: .high
            ),
            ReminderTemplate(
                name: "Bill Payment",
                title: "Pay Monthly Bills",
                details: "Check and pay all monthly recurring bills",
                category: "Finance",
                priority: .high
            ),
            ReminderTemplate(
                name: "Grocery Shopping",
                title: "Weekly Grocery Shopping",
                details: "Check pantry and create shopping list",
                category: "Shopping",
                priority: .medium
            )
        ]
    }
}

// MARK: - Template Category
@Model
final class TemplateCategory {
    var name: String = ""
    var icon: String = "folder"
    var colorHex: String = "#007AFF"
    var order: Int = 0
    var isActive: Bool = true
    
    @Relationship(deleteRule: .nullify) var templates: [ReminderTemplate]? = []
    
    init(name: String, icon: String = "folder", colorHex: String = "#007AFF") {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.colorHex = colorHex
    }
}
