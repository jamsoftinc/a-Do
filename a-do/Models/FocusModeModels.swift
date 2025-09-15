//
//  FocusModeModels.swift
//  a-do
//
//  Focus mode integration models
//

import Foundation
import SwiftData

// MARK: - Focus Session
@Model
final class FocusSession {
    var id: UUID = UUID()
    var name: String = ""
    var sessionDescription: String = ""
    var startTime: Date = Date()
    var endTime: Date?
    var plannedDuration: TimeInterval = 1800 // 30 minutes default
    var actualDuration: TimeInterval = 0
    var isActive: Bool = false
    var wasCompleted: Bool = false
    var wasInterrupted: Bool = false
    var interruptionCount: Int = 0
    
    // Focus settings
    var focusType: FocusType = FocusType.work
    var allowNotifications: Bool = false
    var allowCalls: Bool = false
    var allowMessages: Bool = false
    var muteAllSounds: Bool = true
    var dimScreen: Bool = false
    var hideDistractions: Bool = true
    
    // Productivity metrics
    var tasksCompleted: Int = 0
    var tasksStarted: Int = 0
    var timeSpentOnTasks: TimeInterval = 0
    var productivityScore: Double = 0.0
    
    // Break settings
    var includeBreaks: Bool = true
    var breakDuration: TimeInterval = 300 // 5 minutes
    var longBreakDuration: TimeInterval = 900 // 15 minutes
    var longBreakInterval: Int = 4 // Every 4 sessions
    
    @Relationship(deleteRule: .cascade) var focusedReminders: [Reminder] = []
    @Relationship(deleteRule: .cascade) var completedReminders: [Reminder] = []
    @Relationship(deleteRule: .cascade) var interruptions: [FocusInterruption] = []
    @Relationship(deleteRule: .cascade) var breaks: [FocusBreak] = []
    
    init(name: String, focusType: FocusType = .work, duration: TimeInterval = 1800) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.focusType = focusType
        self.plannedDuration = duration
        self.startTime = Date()
    }
    
    // MARK: - Session Management
    
    func start() {
        isActive = true
        startTime = Date()
        wasCompleted = false
        wasInterrupted = false
        interruptionCount = 0
        tasksCompleted = 0
        tasksStarted = 0
        timeSpentOnTasks = 0
    }
    
    func pause() {
        guard isActive else { return }
        isActive = false
        actualDuration += Date().timeIntervalSince(startTime)
    }
    
    func resume() {
        guard !isActive else { return }
        isActive = true
        startTime = Date()
    }
    
    func complete() {
        guard isActive else { return }
        isActive = false
        endTime = Date()
        actualDuration += Date().timeIntervalSince(startTime)
        wasCompleted = true
        calculateProductivityScore()
    }
    
    func interrupt(reason: InterruptionReason) {
        let interruption = FocusInterruption(reason: reason, session: self)
        interruptions.append(interruption)
        interruptionCount += 1
        wasInterrupted = true
    }
    
    func addBreak(type: BreakType, duration: TimeInterval) {
        let focusBreak = FocusBreak(type: type, duration: duration, session: self)
        breaks.append(focusBreak)
    }
    
    // MARK: - Productivity Calculation
    
    private func calculateProductivityScore() {
        guard plannedDuration > 0 else { return }
        
        // Base score from time completion
        let timeScore = min(1.0, actualDuration / plannedDuration)
        
        // Task completion bonus
        let taskScore = tasksCompleted > 0 ? min(1.0, Double(tasksCompleted) / Double(focusedReminders.count)) : 0.0
        
        // Interruption penalty
        let interruptionPenalty = min(0.5, Double(interruptionCount) * 0.1)
        
        // Final score (0-100)
        productivityScore = max(0.0, (timeScore * 0.4 + taskScore * 0.6 - interruptionPenalty) * 100)
    }
    
    // MARK: - Computed Properties
    
    var remainingTime: TimeInterval {
        guard isActive else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime) + actualDuration
        return max(0, plannedDuration - elapsed)
    }
    
    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        let elapsed = isActive ? Date().timeIntervalSince(startTime) + actualDuration : actualDuration
        return min(1.0, elapsed / plannedDuration)
    }
    
    var isOvertime: Bool {
        let elapsed = isActive ? Date().timeIntervalSince(startTime) + actualDuration : actualDuration
        return elapsed > plannedDuration
    }
    
    var effectiveProductivity: Double {
        guard actualDuration > 0 else { return 0 }
        return timeSpentOnTasks / actualDuration
    }
}

// MARK: - Focus Type
enum FocusType: String, CaseIterable, Codable {
    case work = "work"
    case study = "study"
    case creative = "creative"
    case personal = "personal"
    case exercise = "exercise"
    case meditation = "meditation"
    case reading = "reading"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .creative: return "Creative"
        case .personal: return "Personal"
        case .exercise: return "Exercise"
        case .meditation: return "Meditation"
        case .reading: return "Reading"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .personal: return "person.fill"
        case .exercise: return "figure.run"
        case .meditation: return "brain.head.profile"
        case .reading: return "text.book.closed.fill"
        case .custom: return "gear"
        }
    }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .work: return 3600 // 1 hour
        case .study: return 2700 // 45 minutes
        case .creative: return 5400 // 1.5 hours
        case .personal: return 1800 // 30 minutes
        case .exercise: return 2700 // 45 minutes
        case .meditation: return 1200 // 20 minutes
        case .reading: return 3600 // 1 hour
        case .custom: return 1800 // 30 minutes
        }
    }
    
    var suggestedBreakDuration: TimeInterval {
        switch self {
        case .work, .study: return 300 // 5 minutes
        case .creative: return 600 // 10 minutes
        case .personal: return 180 // 3 minutes
        case .exercise: return 120 // 2 minutes
        case .meditation: return 60 // 1 minute
        case .reading: return 300 // 5 minutes
        case .custom: return 300 // 5 minutes
        }
    }
}

// MARK: - Focus Interruption
@Model
final class FocusInterruption {
    var id: UUID = UUID()
    var reason: InterruptionReason = InterruptionReason.notification
    var timestamp: Date = Date()
    var duration: TimeInterval = 0 // How long the interruption lasted
    var wasHandled: Bool = false
    var notes: String = ""
    
    @Relationship(deleteRule: .nullify) var session: FocusSession?
    
    init(reason: InterruptionReason, session: FocusSession) {
        self.reason = reason
        self.session = session
        self.timestamp = Date()
    }
    
    func resolve(duration: TimeInterval, notes: String = "") {
        self.duration = duration
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wasHandled = true
    }
}

// MARK: - Interruption Reason
enum InterruptionReason: String, CaseIterable, Codable {
    case notification = "notification"
    case call = "call"
    case message = "message"
    case email = "email"
    case meeting = "meeting"
    case bathroom = "bathroom"
    case snack = "snack"
    case distraction = "distraction"
    case emergency = "emergency"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .notification: return "Notification"
        case .call: return "Phone Call"
        case .message: return "Message"
        case .email: return "Email"
        case .meeting: return "Meeting"
        case .bathroom: return "Bathroom Break"
        case .snack: return "Snack Break"
        case .distraction: return "Distraction"
        case .emergency: return "Emergency"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .notification: return "bell"
        case .call: return "phone"
        case .message: return "message"
        case .email: return "envelope"
        case .meeting: return "person.2"
        case .bathroom: return "figure.walk"
        case .snack: return "cup.and.saucer"
        case .distraction: return "eye"
        case .emergency: return "exclamationmark.triangle"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Focus Break
@Model
final class FocusBreak {
    var id: UUID = UUID()
    var type: BreakType = BreakType.short
    var startTime: Date = Date()
    var endTime: Date?
    var plannedDuration: TimeInterval = 300
    var actualDuration: TimeInterval = 0
    var activity: BreakActivity = BreakActivity.rest
    var notes: String = ""
    var wasSkipped: Bool = false
    
    @Relationship(deleteRule: .nullify) var session: FocusSession?
    
    init(type: BreakType, duration: TimeInterval, session: FocusSession) {
        self.type = type
        self.plannedDuration = duration
        self.session = session
        self.startTime = Date()
    }
    
    func complete() {
        endTime = Date()
        actualDuration = Date().timeIntervalSince(startTime)
    }
    
    func skip() {
        wasSkipped = true
        endTime = Date()
        actualDuration = 0
    }
}

// MARK: - Break Type
enum BreakType: String, CaseIterable, Codable {
    case short = "short"
    case long = "long"
    case meal = "meal"
    case exercise = "exercise"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .short: return "Short Break"
        case .long: return "Long Break"
        case .meal: return "Meal Break"
        case .exercise: return "Exercise Break"
        case .custom: return "Custom Break"
        }
    }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .short: return 300 // 5 minutes
        case .long: return 900 // 15 minutes
        case .meal: return 1800 // 30 minutes
        case .exercise: return 600 // 10 minutes
        case .custom: return 300 // 5 minutes
        }
    }
}

// MARK: - Break Activity
enum BreakActivity: String, CaseIterable, Codable {
    case rest = "rest"
    case walk = "walk"
    case stretch = "stretch"
    case snack = "snack"
    case hydrate = "hydrate"
    case socialize = "socialize"
    case meditate = "meditate"
    case exercise = "exercise"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .rest: return "Rest"
        case .walk: return "Walk"
        case .stretch: return "Stretch"
        case .snack: return "Snack"
        case .hydrate: return "Hydrate"
        case .socialize: return "Socialize"
        case .meditate: return "Meditate"
        case .exercise: return "Exercise"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .rest: return "bed.double"
        case .walk: return "figure.walk"
        case .stretch: return "figure.flexibility"
        case .snack: return "cup.and.saucer"
        case .hydrate: return "drop"
        case .socialize: return "person.2"
        case .meditate: return "brain.head.profile"
        case .exercise: return "figure.run"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Focus Template
@Model
final class FocusTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var templateDescription: String = ""
    var focusType: FocusType = FocusType.work
    var duration: TimeInterval = 1800
    var includeBreaks: Bool = true
    var breakDuration: TimeInterval = 300
    var longBreakDuration: TimeInterval = 900
    var longBreakInterval: Int = 4
    var isActive: Bool = true
    var usageCount: Int = 0
    var lastUsed: Date?
    
    // Notification settings
    var allowNotifications: Bool = false
    var allowCalls: Bool = false
    var allowMessages: Bool = false
    var muteAllSounds: Bool = true
    
    // Reminder filters
    var includeHighPriority: Bool = true
    var includeDueToday: Bool = true
    var includeOverdue: Bool = true
    var includeSpecificTags: [String] = []
    var includeSpecificLists: [String] = []
    var maxReminders: Int = 10
    
    init(name: String, focusType: FocusType = .work, duration: TimeInterval = 1800) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.focusType = focusType
        self.duration = duration
        self.breakDuration = focusType.suggestedBreakDuration
    }
    
    func createSession() -> FocusSession {
        let session = FocusSession(name: name, focusType: focusType, duration: duration)
        session.sessionDescription = templateDescription
        session.allowNotifications = allowNotifications
        session.allowCalls = allowCalls
        session.allowMessages = allowMessages
        session.muteAllSounds = muteAllSounds
        session.includeBreaks = includeBreaks
        session.breakDuration = breakDuration
        session.longBreakDuration = longBreakDuration
        session.longBreakInterval = longBreakInterval
        
        // Update usage statistics
        usageCount += 1
        lastUsed = Date()
        
        return session
    }
}

// MARK: - Focus Statistics
struct FocusStatistics {
    let totalSessions: Int
    let totalFocusTime: TimeInterval
    let averageSessionLength: TimeInterval
    let completionRate: Double
    let averageProductivityScore: Double
    let totalInterruptions: Int
    let mostProductiveTimeOfDay: Int
    let mostProductiveFocusType: FocusType
    let streakDays: Int
    let totalBreakTime: TimeInterval
    
    static let empty = FocusStatistics(
        totalSessions: 0,
        totalFocusTime: 0,
        averageSessionLength: 0,
        completionRate: 0,
        averageProductivityScore: 0,
        totalInterruptions: 0,
        mostProductiveTimeOfDay: 9,
        mostProductiveFocusType: .work,
        streakDays: 0,
        totalBreakTime: 0
    )
}

// MARK: - System Focus Mode Integration
@Model
final class SystemFocusMode {
    var id: UUID = UUID()
    var systemIdentifier: String = "" // iOS Focus mode identifier
    var name: String = ""
    var isLinked: Bool = false
    var linkedTemplate: FocusTemplate?
    var autoStartSession: Bool = false
    var autoSelectReminders: Bool = true
    var createdAt: Date = Date()
    
    init(systemIdentifier: String, name: String) {
        self.systemIdentifier = systemIdentifier
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
}

// MARK: - Focus Goal
@Model
final class FocusGoal {
    var id: UUID = UUID()
    var title: String = ""
    var targetType: FocusGoalType = FocusGoalType.dailyTime
    var targetValue: Double = 3600 // 1 hour default
    var currentValue: Double = 0
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var isCompleted: Bool = false
    var completedAt: Date?
    
    // Tracking
    var streak: Int = 0
    var bestStreak: Int = 0
    var lastUpdated: Date = Date()
    
    init(title: String, targetType: FocusGoalType, targetValue: Double) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetType = targetType
        self.targetValue = targetValue
        self.startDate = Date()
        self.lastUpdated = Date()
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }
    
    func updateProgress(value: Double) {
        currentValue = value
        lastUpdated = Date()
        
        if currentValue >= targetValue && !isCompleted {
            complete()
        }
    }
    
    func complete() {
        isCompleted = true
        completedAt = Date()
        streak += 1
        bestStreak = max(bestStreak, streak)
    }
    
    func reset() {
        currentValue = 0
        isCompleted = false
        completedAt = nil
        lastUpdated = Date()
    }
}

// MARK: - Focus Goal Type
enum FocusGoalType: String, CaseIterable, Codable {
    case dailyTime = "daily_time"
    case weeklyTime = "weekly_time"
    case dailySessions = "daily_sessions"
    case weeklySessions = "weekly_sessions"
    case productivityScore = "productivity_score"
    case streakDays = "streak_days"
    case completionRate = "completion_rate"
    
    var displayName: String {
        switch self {
        case .dailyTime: return "Daily Focus Time"
        case .weeklyTime: return "Weekly Focus Time"
        case .dailySessions: return "Daily Sessions"
        case .weeklySessions: return "Weekly Sessions"
        case .productivityScore: return "Productivity Score"
        case .streakDays: return "Streak Days"
        case .completionRate: return "Completion Rate"
        }
    }
    
    var unit: String {
        switch self {
        case .dailyTime, .weeklyTime: return "hours"
        case .dailySessions, .weeklySessions: return "sessions"
        case .productivityScore: return "score"
        case .streakDays: return "days"
        case .completionRate: return "%"
        }
    }
    
    var defaultTarget: Double {
        switch self {
        case .dailyTime: return 2.0 // 2 hours
        case .weeklyTime: return 10.0 // 10 hours
        case .dailySessions: return 3 // 3 sessions
        case .weeklySessions: return 15 // 15 sessions
        case .productivityScore: return 80.0 // 80 score
        case .streakDays: return 7 // 7 days
        case .completionRate: return 90.0 // 90%
        }
    }
}
