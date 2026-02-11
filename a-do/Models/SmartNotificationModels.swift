//
//  SmartNotificationModels.swift
//  a-do
//
//  Smart notification system models
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Smart Notification Configuration
@Model
final class SmartNotificationConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var isEnabled: Bool = true
    var adaptiveTimingEnabled: Bool = true
    var contextAwareEnabled: Bool = true
    var intelligentGroupingEnabled: Bool = true
    var quietHoursEnabled: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var weekendQuietHours: Bool = false
    var locationBasedEnabled: Bool = true
    var activityBasedEnabled: Bool = true
    var priorityFilteringRaw: String = NotificationPriorityLevel.medium.rawValue
    
    var priorityFiltering: NotificationPriorityLevel {
        get { NotificationPriorityLevel(rawValue: priorityFilteringRaw) ?? .medium }
        set { priorityFilteringRaw = newValue.rawValue }
    }
    var maxNotificationsPerHour: Int = 5
    var batchSimilarNotifications: Bool = true
    var learningEnabled: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateSettings() {
        updatedAt = Date()
    }
    
    var isInQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's weekend and weekend quiet hours are disabled
        if !weekendQuietHours && calendar.isDateInWeekend(now) {
            return false
        }
        
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startTime = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endTime = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        
        if startMinutes < endMinutes {
            // Same day quiet hours
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight quiet hours
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}

// MARK: - Notification Priority Level
enum NotificationPriorityLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var urgencyScore: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Smart Notification
@Model
final class SmartNotification {
    var id: UUID = UUID()
    var userId: String = ""
    var typeRaw: String = SmartNotificationType.reminder.rawValue
    
    var type: SmartNotificationType {
        get { SmartNotificationType(rawValue: typeRaw) ?? .reminder }
        set { typeRaw = newValue.rawValue }
    }
    var title: String = ""
    var body: String = ""
    var scheduledDate: Date = Date()
    var actualDeliveryDate: Date?
    var priorityRaw: String = NotificationPriorityLevel.medium.rawValue
    var contextRaw: String = NotificationContext.general.rawValue
    var statusRaw: String = NotificationStatus.scheduled.rawValue
    
    var priority: NotificationPriorityLevel {
        get { NotificationPriorityLevel(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
    
    var context: NotificationContext {
        get { NotificationContext(rawValue: contextRaw) ?? .general }
        set { contextRaw = newValue.rawValue }
    }
    
    var status: NotificationStatus {
        get { NotificationStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }
    var adaptiveScore: Double = 0.0
    var userEngagementRaw: String = NotificationEngagement.none.rawValue
    var deliveryMethodRaw: String = NotificationDeliveryMethod.push.rawValue
    
    var userEngagement: NotificationEngagement {
        get { NotificationEngagement(rawValue: userEngagementRaw) ?? .none }
        set { userEngagementRaw = newValue.rawValue }
    }
    
    var deliveryMethod: NotificationDeliveryMethod {
        get { NotificationDeliveryMethod(rawValue: deliveryMethodRaw) ?? .push }
        set { deliveryMethodRaw = newValue.rawValue }
    }
    var groupId: String?
    var batchId: String?
    var retryCount: Int = 0
    var maxRetries: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Contextual data
    var locationContext: String?
    var activityContext: String?
    var deviceContext: String?
    var timeContext: String?
    var socialContext: String?
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Reminder.smartNotifications) var reminder: Reminder?
    @Relationship(deleteRule: .nullify, inverse: \Habit.smartNotifications) var habit: Habit?
    @Relationship(deleteRule: .nullify, inverse: \FocusSession.smartNotifications) var focusSession: FocusSession?
    @Relationship(deleteRule: .nullify) var notificationBatch: NotificationBatch?
    
    init(
        userId: String,
        type: SmartNotificationType,
        title: String,
        body: String,
        scheduledDate: Date,
        priority: NotificationPriorityLevel = .medium
    ) {
        self.userId = userId
        self.typeRaw = type.rawValue
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scheduledDate = scheduledDate
        self.priorityRaw = priority.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func markAsDelivered() {
        status = .delivered
        actualDeliveryDate = Date()
        updatedAt = Date()
    }
    
    func markAsEngaged(engagement: NotificationEngagement) {
        userEngagement = engagement
        updatedAt = Date()
    }
    
    func reschedule(newDate: Date) {
        scheduledDate = newDate
        status = .rescheduled
        retryCount += 1
        updatedAt = Date()
    }
    
    func cancel() {
        status = .cancelled
        updatedAt = Date()
    }
    
    var shouldRetry: Bool {
        return status == .failed && retryCount < maxRetries
    }
    
    var isOverdue: Bool {
        return scheduledDate < Date() && status == .scheduled
    }
}

// MARK: - Smart Notification Type
enum SmartNotificationType: String, CaseIterable, Codable {
    case reminder = "reminder"
    case habitReminder = "habit_reminder"
    case focusBreak = "focus_break"
    case focusStart = "focus_start"
    case goalProgress = "goal_progress"
    case healthMetric = "health_metric"
    case collaboration = "collaboration"
    case aiSuggestion = "ai_suggestion"
    case backup = "backup"
    case sync = "sync"
    case achievement = "achievement"
    case streak = "streak"
    case deadline = "deadline"
    case locationArrival = "location_arrival"
    case locationDeparture = "location_departure"
    case timeBlocking = "time_blocking"
    case workloadWarning = "workload_warning"
    
    var displayName: String {
        switch self {
        case .reminder: return "Reminder"
        case .habitReminder: return "Habit Reminder"
        case .focusBreak: return "Focus Break"
        case .focusStart: return "Focus Session"
        case .goalProgress: return "Goal Progress"
        case .healthMetric: return "Health Metric"
        case .collaboration: return "Collaboration"
        case .aiSuggestion: return "AI Suggestion"
        case .backup: return "Backup"
        case .sync: return "Sync"
        case .achievement: return "Achievement"
        case .streak: return "Streak"
        case .deadline: return "Deadline"
        case .locationArrival: return "Location Arrival"
        case .locationDeparture: return "Location Departure"
        case .timeBlocking: return "Time Blocking"
        case .workloadWarning: return "Workload Warning"
        }
    }
    
    var icon: String {
        switch self {
        case .reminder: return "bell"
        case .habitReminder: return "repeat"
        case .focusBreak: return "pause.circle"
        case .focusStart: return "target"
        case .goalProgress: return "flag.checkered"
        case .healthMetric: return "heart"
        case .collaboration: return "person.2"
        case .aiSuggestion: return "lightbulb"
        case .backup: return "icloud.and.arrow.up"
        case .sync: return "arrow.triangle.2.circlepath"
        case .achievement: return "trophy"
        case .streak: return "flame"
        case .deadline: return "exclamationmark.triangle"
        case .locationArrival: return "location"
        case .locationDeparture: return "location.slash"
        case .timeBlocking: return "calendar"
        case .workloadWarning: return "exclamationmark.octagon"
        }
    }
    
    var defaultPriority: NotificationPriorityLevel {
        switch self {
        case .reminder, .habitReminder: return .medium
        case .focusBreak, .focusStart: return .high
        case .goalProgress, .healthMetric: return .low
        case .collaboration: return .medium
        case .aiSuggestion: return .low
        case .backup, .sync: return .low
        case .achievement, .streak: return .medium
        case .deadline: return .high
        case .locationArrival, .locationDeparture: return .medium
        case .timeBlocking: return .high
        case .workloadWarning: return .critical
        }
    }
}

// MARK: - Notification Context
enum NotificationContext: String, CaseIterable, Codable {
    case general = "general"
    case work = "work"
    case personal = "personal"
    case health = "health"
    case travel = "travel"
    case home = "home"
    case gym = "gym"
    case commute = "commute"
    case meeting = "meeting"
    case focus = "focus"
    case breakTime = "break"
    case sleep = "sleep"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .travel: return "Travel"
        case .home: return "Home"
        case .gym: return "Gym"
        case .commute: return "Commute"
        case .meeting: return "Meeting"
        case .focus: return "Focus"
        case .breakTime: return "Break"
        case .sleep: return "Sleep"
        }
    }
}

// MARK: - Notification Status
enum NotificationStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case delivered = "delivered"
    case failed = "failed"
    case cancelled = "cancelled"
    case rescheduled = "rescheduled"
    case suppressed = "suppressed"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .delivered: return "Delivered"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .rescheduled: return "Rescheduled"
        case .suppressed: return "Suppressed"
        }
    }
}

// MARK: - Notification Engagement
enum NotificationEngagement: String, CaseIterable, Codable {
    case none = "none"
    case viewed = "viewed"
    case tapped = "tapped"
    case dismissed = "dismissed"
    case actionTaken = "action_taken"
    case snoozed = "snoozed"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .viewed: return "Viewed"
        case .tapped: return "Tapped"
        case .dismissed: return "Dismissed"
        case .actionTaken: return "Action Taken"
        case .snoozed: return "Snoozed"
        }
    }
    
    var engagementScore: Double {
        switch self {
        case .none: return 0.0
        case .viewed: return 0.2
        case .tapped: return 0.6
        case .dismissed: return 0.1
        case .actionTaken: return 1.0
        case .snoozed: return 0.4
        }
    }
}

// MARK: - Notification Delivery Method
enum NotificationDeliveryMethod: String, CaseIterable, Codable {
    case push = "push"
    case banner = "banner"
    case alert = "alert"
    case badge = "badge"
    case sound = "sound"
    case silent = "silent"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .push: return "Push Notification"
        case .banner: return "Banner"
        case .alert: return "Alert"
        case .badge: return "Badge"
        case .sound: return "Sound"
        case .silent: return "Silent"
        case .critical: return "Critical Alert"
        }
    }
}

// MARK: - Notification Pattern
@Model
final class NotificationPattern {
    var id: UUID = UUID()
    var userId: String = ""
    var patternTypeRaw: String = NotificationPatternType.timeOfDay.rawValue
    
    var patternType: NotificationPatternType {
        get { NotificationPatternType(rawValue: patternTypeRaw) ?? .timeOfDay }
        set { patternTypeRaw = newValue.rawValue }
    }
    var contextValue: String = ""
    var engagementRate: Double = 0.0
    var deliverySuccessRate: Double = 0.0
    var averageResponseTime: TimeInterval = 0
    var totalNotifications: Int = 0
    var totalEngagements: Int = 0
    var lastUpdated: Date = Date()
    var confidence: Double = 0.0
    var isActive: Bool = true
    
    init(userId: String, patternType: NotificationPatternType, contextValue: String) {
        self.userId = userId
        self.patternType = patternType
        self.contextValue = contextValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastUpdated = Date()
    }
    
    func updateMetrics(engagement: NotificationEngagement, responseTime: TimeInterval) {
        totalNotifications += 1
        
        if engagement != .none {
            totalEngagements += 1
        }
        
        engagementRate = Double(totalEngagements) / Double(totalNotifications)
        
        // Update average response time
        if responseTime > 0 {
            averageResponseTime = (averageResponseTime * Double(totalNotifications - 1) + responseTime) / Double(totalNotifications)
        }
        
        // Update confidence based on observation count and consistency
        confidence = min(1.0, Double(totalNotifications) / 50.0) * engagementRate
        
        lastUpdated = Date()
    }
}

// MARK: - Notification Pattern Type
enum NotificationPatternType: String, CaseIterable, Codable {
    case timeOfDay = "time_of_day"
    case dayOfWeek = "day_of_week"
    case location = "location"
    case activity = "activity"
    case deviceState = "device_state"
    case appUsage = "app_usage"
    case socialContext = "social_context"
    case workload = "workload"
    
    var displayName: String {
        switch self {
        case .timeOfDay: return "Time of Day"
        case .dayOfWeek: return "Day of Week"
        case .location: return "Location"
        case .activity: return "Activity"
        case .deviceState: return "Device State"
        case .appUsage: return "App Usage"
        case .socialContext: return "Social Context"
        case .workload: return "Workload"
        }
    }
}

// MARK: - Notification Batch
@Model
final class NotificationBatch {
    var id: UUID = UUID()
    var userId: String = ""
    var batchTypeRaw: String = NotificationBatchType.similar.rawValue
    
    var batchType: NotificationBatchType {
        get { NotificationBatchType(rawValue: batchTypeRaw) ?? .similar }
        set { batchTypeRaw = newValue.rawValue }
    }
    var title: String = ""
    var summary: String = ""
    var scheduledDate: Date = Date()
    var deliveredDate: Date?
    var notificationCount: Int = 0
    var priorityRaw: String = NotificationPriorityLevel.medium.rawValue
    var statusRaw: String = NotificationStatus.scheduled.rawValue
    
    var priority: NotificationPriorityLevel {
        get { NotificationPriorityLevel(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
    
    var status: NotificationStatus {
        get { NotificationStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }
    var engagementRate: Double = 0.0
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade) var notifications: [SmartNotification]? = []
    
    init(userId: String, batchType: NotificationBatchType, title: String) {
        self.userId = userId
        self.batchType = batchType
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
    
    func addNotification(_ notification: SmartNotification) {
        notifications?.append(notification)
        notification.batchId = id.uuidString
        notificationCount = notifications?.count ?? 0
        
        // Update priority to highest in batch
        if notification.priority.urgencyScore > priority.urgencyScore {
            priority = notification.priority
        }
        
        updateSummary()
    }
    
    private func updateSummary() {
        switch batchType {
        case .similar:
            summary = "\(notificationCount) similar notifications"
        case .timeGrouped:
            summary = "\(notificationCount) notifications for this time"
        case .contextGrouped:
            summary = "\(notificationCount) notifications for this context"
        case .priority:
            summary = "\(notificationCount) \(priority.displayName.lowercased()) priority notifications"
        }
    }
    
    func deliver() {
        status = .delivered
        deliveredDate = Date()
        
        for notification in notifications ?? [] {
            notification.markAsDelivered()
        }
    }
}

// MARK: - Notification Batch Type
enum NotificationBatchType: String, CaseIterable, Codable {
    case similar = "similar"
    case timeGrouped = "time_grouped"
    case contextGrouped = "context_grouped"
    case priority = "priority"
    
    var displayName: String {
        switch self {
        case .similar: return "Similar Notifications"
        case .timeGrouped: return "Time-based Group"
        case .contextGrouped: return "Context-based Group"
        case .priority: return "Priority Group"
        }
    }
}

// MARK: - Notification Analytics
@Model
final class NotificationAnalytics {
    var id: UUID = UUID()
    var userId: String = ""
    var date: Date = Date()
    var totalNotifications: Int = 0
    var deliveredNotifications: Int = 0
    var engagedNotifications: Int = 0
    var suppressedNotifications: Int = 0
    var averageDeliveryDelay: TimeInterval = 0
    var averageEngagementTime: TimeInterval = 0
    var topEngagementContext: String = ""
    var topEngagementTime: String = ""
    var deliverySuccessRate: Double = 0.0
    var engagementRate: Double = 0.0
    var optimalDeliveryScore: Double = 0.0
    
    init(userId: String, date: Date = Date()) {
        self.userId = userId
        self.date = Calendar.current.startOfDay(for: date)
    }
    
    func updateMetrics(
        total: Int,
        delivered: Int,
        engaged: Int,
        suppressed: Int,
        avgDelay: TimeInterval,
        avgEngagement: TimeInterval
    ) {
        totalNotifications = total
        deliveredNotifications = delivered
        engagedNotifications = engaged
        suppressedNotifications = suppressed
        averageDeliveryDelay = avgDelay
        averageEngagementTime = avgEngagement
        
        deliverySuccessRate = total > 0 ? Double(delivered) / Double(total) : 0.0
        engagementRate = delivered > 0 ? Double(engaged) / Double(delivered) : 0.0
        
        // Calculate optimal delivery score (combination of delivery success and engagement)
        optimalDeliveryScore = (deliverySuccessRate * 0.4 + engagementRate * 0.6)
    }
}

// MARK: - Notification Rule
@Model
final class NotificationRule {
    var id: UUID = UUID()
    var userId: String = ""
    var name: String = ""
    var ruleDescription: String = ""
    var ruleTypeRaw: String = NotificationRuleType.suppress.rawValue
    
    var ruleType: NotificationRuleType {
        get { NotificationRuleType(rawValue: ruleTypeRaw) ?? .suppress }
        set { ruleTypeRaw = newValue.rawValue }
    }
    var isActive: Bool = true
    var priority: Int = 0 // Higher number = higher priority
    var conditions: Data? // JSON encoded conditions
    var actions: Data? // JSON encoded actions
    var createdAt: Date = Date()
    var lastTriggered: Date?
    var triggerCount: Int = 0
    
    init(userId: String, name: String, ruleType: NotificationRuleType) {
        self.userId = userId
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ruleType = ruleType
        self.createdAt = Date()
    }
    
    func trigger() {
        lastTriggered = Date()
        triggerCount += 1
    }
    
    func setConditions<T: Codable>(_ conditions: T) {
        self.conditions = try? JSONEncoder().encode(conditions)
    }
    
    func getConditions<T: Codable>(as type: T.Type) -> T? {
        guard let conditions = conditions else { return nil }
        return try? JSONDecoder().decode(type, from: conditions)
    }
    
    func setActions<T: Codable>(_ actions: T) {
        self.actions = try? JSONEncoder().encode(actions)
    }
    
    func getActions<T: Codable>(as type: T.Type) -> T? {
        guard let actions = actions else { return nil }
        return try? JSONDecoder().decode(type, from: actions)
    }
}

// MARK: - Notification Rule Type
enum NotificationRuleType: String, CaseIterable, Codable {
    case suppress = "suppress"
    case delay = "delay"
    case reschedule = "reschedule"
    case batch = "batch"
    case prioritize = "prioritize"
    case redirect = "redirect"
    
    var displayName: String {
        switch self {
        case .suppress: return "Suppress"
        case .delay: return "Delay"
        case .reschedule: return "Reschedule"
        case .batch: return "Batch"
        case .prioritize: return "Prioritize"
        case .redirect: return "Redirect"
        }
    }
    
    var description: String {
        switch self {
        case .suppress: return "Prevent notification from being delivered"
        case .delay: return "Delay notification delivery"
        case .reschedule: return "Reschedule notification to better time"
        case .batch: return "Group with similar notifications"
        case .prioritize: return "Increase notification priority"
        case .redirect: return "Change delivery method or destination"
        }
    }
}
