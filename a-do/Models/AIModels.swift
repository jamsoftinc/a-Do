//
//  AIModels.swift
//  a-do
//
//  AI-powered features and insights models
//

import Foundation
import SwiftData

// MARK: - AI Suggestion
@Model
final class AISuggestion {
    var id: UUID = UUID()
    var typeRaw: String = AISuggestionType.dueDateOptimization.rawValue
    var title: String = ""
    var aiDescription: String = ""
    var confidence: Double = 0.0 // 0.0 to 1.0
    var priorityRaw: String = AISuggestionPriority.medium.rawValue
    var statusRaw: String = AISuggestionStatus.pending.rawValue
    var createdAt: Date = Date()
    var appliedAt: Date?
    var dismissedAt: Date?
    var expiresAt: Date?
    
    var type: AISuggestionType {
        get { AISuggestionType(rawValue: typeRaw) ?? .dueDateOptimization }
        set { typeRaw = newValue.rawValue }
    }
    
    var priority: AISuggestionPriority {
        get { AISuggestionPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
    
    var status: AISuggestionStatus {
        get { AISuggestionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    // Context data
    var contextData: Data? // JSON encoded context information
    var targetReminderID: UUID?
    var targetHabitID: UUID?
    var targetListID: UUID?
    
    // User feedback
    var userRating: Int? // 1-5 stars
    var userFeedback: String = ""
    var wasHelpful: Bool?
    
    @Relationship(deleteRule: .nullify) var targetReminder: Reminder?
    @Relationship(deleteRule: .nullify) var targetHabit: Habit?
    
    init(type: AISuggestionType, title: String, description: String, confidence: Double) {
        self.typeRaw = type.rawValue
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = max(0.0, min(1.0, confidence))
        self.createdAt = Date()
        
        // Set expiration based on type
        self.expiresAt = Calendar.current.date(byAdding: .day, value: type.defaultExpirationDays, to: Date())
    }
    
    // MARK: - Status Management
    
    func apply() {
        status = .applied
        appliedAt = Date()
    }
    
    func dismiss() {
        status = .dismissed
        dismissedAt = Date()
    }
    
    func expire() {
        status = .expired
    }
    
    func provideFeedback(rating: Int, feedback: String, wasHelpful: Bool) {
        self.userRating = max(1, min(5, rating))
        self.userFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wasHelpful = wasHelpful
    }
    
    // MARK: - Context Data Helpers
    
    func setContextData<T: Codable>(_ data: T) {
        contextData = try? JSONEncoder().encode(data)
    }
    
    func getContextData<T: Codable>(as type: T.Type) -> T? {
        guard let contextData = contextData else { return nil }
        return try? JSONDecoder().decode(type, from: contextData)
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var isActive: Bool {
        return status == .pending && !isExpired
    }
}

// MARK: - AI Suggestion Type
enum AISuggestionType: String, CaseIterable, Codable {
    // Due date and scheduling
    case dueDateOptimization = "due_date_optimization"
    case scheduleConflictResolution = "schedule_conflict_resolution"
    case optimalTaskTiming = "optimal_task_timing"
    case deadlineWarning = "deadline_warning"
    
    // Task management
    case taskBreakdown = "task_breakdown"
    case priorityAdjustment = "priority_adjustment"
    case taskConsolidation = "task_consolidation"
    case dependencyDetection = "dependency_detection"
    
    // Productivity insights
    case productivityPattern = "productivity_pattern"
    case focusTimeRecommendation = "focus_time_recommendation"
    case breakSuggestion = "break_suggestion"
    case workloadBalance = "workload_balance"
    
    // Habit optimization
    case habitTiming = "habit_timing"
    case habitStacking = "habit_stacking"
    case habitDifficulty = "habit_difficulty"
    case habitStreak = "habit_streak"
    
    // Collaboration
    case delegationSuggestion = "delegation_suggestion"
    case collaborationOpportunity = "collaboration_opportunity"
    case teamWorkload = "team_workload"
    
    // Content and organization
    case tagSuggestion = "tag_suggestion"
    case listOrganization = "list_organization"
    case templateRecommendation = "template_recommendation"
    case duplicateDetection = "duplicate_detection"
    
    // Health and wellness
    case burnoutPrevention = "burnout_prevention"
    case workLifeBalance = "work_life_balance"
    case stressReduction = "stress_reduction"
    
    var displayName: String {
        switch self {
        case .dueDateOptimization: return "Due Date Optimization"
        case .scheduleConflictResolution: return "Schedule Conflict Resolution"
        case .optimalTaskTiming: return "Optimal Task Timing"
        case .deadlineWarning: return "Deadline Warning"
        case .taskBreakdown: return "Task Breakdown"
        case .priorityAdjustment: return "Priority Adjustment"
        case .taskConsolidation: return "Task Consolidation"
        case .dependencyDetection: return "Dependency Detection"
        case .productivityPattern: return "Productivity Pattern"
        case .focusTimeRecommendation: return "Focus Time Recommendation"
        case .breakSuggestion: return "Break Suggestion"
        case .workloadBalance: return "Workload Balance"
        case .habitTiming: return "Habit Timing"
        case .habitStacking: return "Habit Stacking"
        case .habitDifficulty: return "Habit Difficulty"
        case .habitStreak: return "Habit Streak"
        case .delegationSuggestion: return "Delegation Suggestion"
        case .collaborationOpportunity: return "Collaboration Opportunity"
        case .teamWorkload: return "Team Workload"
        case .tagSuggestion: return "Tag Suggestion"
        case .listOrganization: return "List Organization"
        case .templateRecommendation: return "Template Recommendation"
        case .duplicateDetection: return "Duplicate Detection"
        case .burnoutPrevention: return "Burnout Prevention"
        case .workLifeBalance: return "Work-Life Balance"
        case .stressReduction: return "Stress Reduction"
        }
    }
    
    var icon: String {
        switch self {
        case .dueDateOptimization, .scheduleConflictResolution: return "calendar.badge.clock"
        case .optimalTaskTiming: return "clock.badge.checkmark"
        case .deadlineWarning: return "exclamationmark.triangle"
        case .taskBreakdown: return "list.bullet.rectangle"
        case .priorityAdjustment: return "arrow.up.arrow.down"
        case .taskConsolidation: return "square.stack"
        case .dependencyDetection: return "link"
        case .productivityPattern: return "chart.line.uptrend.xyaxis"
        case .focusTimeRecommendation: return "target"
        case .breakSuggestion: return "pause.circle"
        case .workloadBalance: return "scale.3d"
        case .habitTiming: return "clock.arrow.circlepath"
        case .habitStacking: return "square.stack.3d.up"
        case .habitDifficulty: return "gauge"
        case .habitStreak: return "flame"
        case .delegationSuggestion: return "person.badge.plus"
        case .collaborationOpportunity: return "person.2.badge.gearshape"
        case .teamWorkload: return "person.3"
        case .tagSuggestion: return "tag"
        case .listOrganization: return "folder.badge.gearshape"
        case .templateRecommendation: return "doc.text.magnifyingglass"
        case .duplicateDetection: return "doc.on.doc"
        case .burnoutPrevention: return "heart.circle"
        case .workLifeBalance: return "scale"
        case .stressReduction: return "leaf"
        }
    }
    
    var defaultExpirationDays: Int {
        switch self {
        case .dueDateOptimization, .scheduleConflictResolution, .deadlineWarning: return 1
        case .taskBreakdown, .priorityAdjustment: return 3
        case .productivityPattern, .focusTimeRecommendation: return 7
        case .habitTiming, .habitStacking: return 14
        case .burnoutPrevention, .workLifeBalance: return 30
        default: return 7
        }
    }
}

// MARK: - AI Suggestion Priority
enum AISuggestionPriority: String, CaseIterable, Codable {
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
    
    var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#FF9500"
        case .high: return "#FF3B30"
        case .critical: return "#8E8E93"
        }
    }
}

// MARK: - AI Suggestion Status
enum AISuggestionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case applied = "applied"
    case dismissed = "dismissed"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .applied: return "Applied"
        case .dismissed: return "Dismissed"
        case .expired: return "Expired"
        }
    }
}

// MARK: - AI Insight
@Model
final class AIInsight {
    var id: UUID = UUID()
    var typeRaw: String = AIInsightType.productivityTrend.rawValue
    
    var type: AIInsightType {
        get { AIInsightType(rawValue: typeRaw) ?? .productivityTrend }
        set { typeRaw = newValue.rawValue }
    }
    var title: String = ""
    var summary: String = ""
    var detailedAnalysis: String = ""
    var confidence: Double = 0.0
    var timeframeRaw: String = AIInsightTimeframe.week.rawValue
    
    var timeframe: AIInsightTimeframe {
        get { AIInsightTimeframe(rawValue: timeframeRaw) ?? .week }
        set { timeframeRaw = newValue.rawValue }
    }
    var createdAt: Date = Date()
    var isRead: Bool = false
    var isBookmarked: Bool = false
    
    // Data and metrics
    var metricsData: Data? // JSON encoded metrics
    var visualizationTypeRaw: String = AIVisualizationType.lineChart.rawValue
    
    var visualizationType: AIVisualizationType {
        get { AIVisualizationType(rawValue: visualizationTypeRaw) ?? .lineChart }
        set { visualizationTypeRaw = newValue.rawValue }
    }
    var actionableRecommendations: Data? // JSON encoded [String]
    
    // User interaction
    var viewCount: Int = 0
    var lastViewedAt: Date?
    var userRating: Int?
    var userNotes: String = ""
    
    init(type: AIInsightType, title: String, summary: String, confidence: Double) {
        self.typeRaw = type.rawValue
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = max(0.0, min(1.0, confidence))
        self.createdAt = Date()
    }
    
    func markAsRead() {
        isRead = true
        viewCount += 1
        lastViewedAt = Date()
    }
    
    func toggleBookmark() {
        isBookmarked.toggle()
    }
    
    func addUserNotes(_ notes: String) {
        userNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func setMetrics<T: Codable>(_ metrics: T) {
        metricsData = try? JSONEncoder().encode(metrics)
    }
    
    func getMetrics<T: Codable>(as type: T.Type) -> T? {
        guard let metricsData = metricsData else { return nil }
        return try? JSONDecoder().decode(type, from: metricsData)
    }
}

// MARK: - AI Insight Type
enum AIInsightType: String, CaseIterable, Codable {
    case productivityTrend = "productivity_trend"
    case completionPattern = "completion_pattern"
    case timeUsageAnalysis = "time_usage_analysis"
    case habitProgress = "habit_progress"
    case focusEffectiveness = "focus_effectiveness"
    case collaborationMetrics = "collaboration_metrics"
    case burnoutRisk = "burnout_risk"
    case goalProgress = "goal_progress"
    case workloadDistribution = "workload_distribution"
    case procrastinationPattern = "procrastination_pattern"
    
    var displayName: String {
        switch self {
        case .productivityTrend: return "Productivity Trend"
        case .completionPattern: return "Completion Pattern"
        case .timeUsageAnalysis: return "Time Usage Analysis"
        case .habitProgress: return "Habit Progress"
        case .focusEffectiveness: return "Focus Effectiveness"
        case .collaborationMetrics: return "Collaboration Metrics"
        case .burnoutRisk: return "Burnout Risk"
        case .goalProgress: return "Goal Progress"
        case .workloadDistribution: return "Workload Distribution"
        case .procrastinationPattern: return "Procrastination Pattern"
        }
    }
}

// MARK: - AI Insight Timeframe
enum AIInsightTimeframe: String, CaseIterable, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .quarter: return "Quarterly"
        case .year: return "Yearly"
        }
    }
}

// MARK: - AI Visualization Type
enum AIVisualizationType: String, CaseIterable, Codable {
    case lineChart = "line_chart"
    case barChart = "bar_chart"
    case pieChart = "pie_chart"
    case heatmap = "heatmap"
    case scatter = "scatter"
    case gauge = "gauge"
    case timeline = "timeline"
    
    var displayName: String {
        switch self {
        case .lineChart: return "Line Chart"
        case .barChart: return "Bar Chart"
        case .pieChart: return "Pie Chart"
        case .heatmap: return "Heatmap"
        case .scatter: return "Scatter Plot"
        case .gauge: return "Gauge"
        case .timeline: return "Timeline"
        }
    }
}

// MARK: - AI Learning Data
@Model
final class AILearningData {
    var id: UUID = UUID()
    var dataTypeRaw: String = AILearningDataType.userBehavior.rawValue
    
    var dataType: AILearningDataType {
        get { AILearningDataType(rawValue: dataTypeRaw) ?? .userBehavior }
        set { dataTypeRaw = newValue.rawValue }
    }
    var timestamp: Date = Date()
    var userId: String = ""
    var sessionId: String = ""
    var eventData: Data? // JSON encoded event data
    var context: String = ""
    var isProcessed: Bool = false
    var processingVersion: String = "1.0"
    
    init(dataType: AILearningDataType, userId: String, sessionId: String) {
        self.dataType = dataType
        self.userId = userId
        self.sessionId = sessionId
        self.timestamp = Date()
    }
    
    func setEventData<T: Codable>(_ data: T) {
        eventData = try? JSONEncoder().encode(data)
    }
    
    func getEventData<T: Codable>(as type: T.Type) -> T? {
        guard let eventData = eventData else { return nil }
        return try? JSONDecoder().decode(type, from: eventData)
    }
    
    func markAsProcessed(version: String = "1.0") {
        isProcessed = true
        processingVersion = version
    }
}

// MARK: - AI Learning Data Type
enum AILearningDataType: String, CaseIterable, Codable {
    case userBehavior = "user_behavior"
    case taskCompletion = "task_completion"
    case timeTracking = "time_tracking"
    case habitExecution = "habit_execution"
    case focusSession = "focus_session"
    case collaboration = "collaboration"
    case appUsage = "app_usage"
    case notification = "notification"
    case contextSwitch = "context_switch"
    case errorEvent = "error_event"
}

// MARK: - AI Model Performance
@Model
final class AIModelPerformance {
    var id: UUID = UUID()
    var modelName: String = ""
    var modelVersion: String = ""
    var evaluationDate: Date = Date()
    var accuracy: Double = 0.0
    var precision: Double = 0.0
    var recall: Double = 0.0
    var f1Score: Double = 0.0
    var userSatisfactionScore: Double = 0.0
    var totalPredictions: Int = 0
    var correctPredictions: Int = 0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
    
    // Performance metrics by category
    var categoryMetrics: Data? // JSON encoded category-specific metrics
    
    init(modelName: String, modelVersion: String) {
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.evaluationDate = Date()
    }
    
    func updateMetrics(
        accuracy: Double,
        precision: Double,
        recall: Double,
        userSatisfactionScore: Double,
        totalPredictions: Int,
        correctPredictions: Int
    ) {
        self.accuracy = accuracy
        self.precision = precision
        self.recall = recall
        self.f1Score = 2 * (precision * recall) / (precision + recall)
        self.userSatisfactionScore = userSatisfactionScore
        self.totalPredictions = totalPredictions
        self.correctPredictions = correctPredictions
        self.evaluationDate = Date()
    }
    
    var overallScore: Double {
        return (accuracy + precision + recall + userSatisfactionScore) / 4.0
    }
}

// MARK: - AI Configuration
@Model
final class AIConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var isAIEnabled: Bool = true
    var suggestionFrequencyRaw: String = AISuggestionFrequency.daily.rawValue
    var insightFrequencyRaw: String = AIInsightFrequency.weekly.rawValue
    var privacyLevelRaw: String = AIPrivacyLevel.balanced.rawValue
    
    var suggestionFrequency: AISuggestionFrequency {
        get { AISuggestionFrequency(rawValue: suggestionFrequencyRaw) ?? .daily }
        set { suggestionFrequencyRaw = newValue.rawValue }
    }
    
    var insightFrequency: AIInsightFrequency {
        get { AIInsightFrequency(rawValue: insightFrequencyRaw) ?? .weekly }
        set { insightFrequencyRaw = newValue.rawValue }
    }
    
    var privacyLevel: AIPrivacyLevel {
        get { AIPrivacyLevel(rawValue: privacyLevelRaw) ?? .balanced }
        set { privacyLevelRaw = newValue.rawValue }
    }
    var learningEnabled: Bool = true
    var personalizedRecommendations: Bool = true
    var proactiveNotifications: Bool = true
    var minimumConfidenceThreshold: Double = 0.7
    var maxSuggestionsPerDay: Int = 5
    var preferredInsightTypes: [AIInsightType] = []
    var disabledSuggestionTypes: [AISuggestionType] = []
    var lastUpdated: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.lastUpdated = Date()
    }
    
    func updateSettings(
        isEnabled: Bool? = nil,
        suggestionFrequency: AISuggestionFrequency? = nil,
        insightFrequency: AIInsightFrequency? = nil,
        privacyLevel: AIPrivacyLevel? = nil,
        confidenceThreshold: Double? = nil
    ) {
        if let isEnabled = isEnabled { self.isAIEnabled = isEnabled }
        if let frequency = suggestionFrequency { self.suggestionFrequency = frequency }
        if let insightFreq = insightFrequency { self.insightFrequency = insightFreq }
        if let privacy = privacyLevel { self.privacyLevel = privacy }
        if let threshold = confidenceThreshold { 
            self.minimumConfidenceThreshold = max(0.0, min(1.0, threshold))
        }
        
        self.lastUpdated = Date()
    }
}

// MARK: - AI Configuration Enums
enum AISuggestionFrequency: String, CaseIterable, Codable {
    case realtime = "realtime"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .realtime: return "Real-time"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .manual: return "Manual Only"
        }
    }
}

enum AIInsightFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .manual: return "Manual Only"
        }
    }
}

enum AIPrivacyLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case balanced = "balanced"
    case full = "full"
    
    var displayName: String {
        switch self {
        case .minimal: return "Minimal (Local Only)"
        case .balanced: return "Balanced (Anonymous)"
        case .full: return "Full (Personalized)"
        }
    }
    
    var description: String {
        switch self {
        case .minimal: return "AI processing happens only on your device"
        case .balanced: return "Anonymous data used to improve suggestions"
        case .full: return "Full personalization with cloud-based AI"
        }
    }
}
