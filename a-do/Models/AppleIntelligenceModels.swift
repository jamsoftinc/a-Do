//
//  AppleIntelligenceModels.swift
//  a-do
//
//  Models for Apple Intelligence integration including:
//  - Generable models for Foundation Models structured output
//  - Visual Intelligence data models
//  - Writing Tools configuration
//
//  Requires: iOS 26+
//

import Foundation
import FoundationModels

// MARK: - Reminder Parsing Models

/// Structured output for parsing natural language reminder text
/// Use with Foundation Models to extract structured data from user input
@Generable
public struct AIReminderParseResult: Codable, Sendable, Hashable {
    /// The cleaned task title without date/time/location info
    public let title: String

    /// Extracted due date in ISO 8601 format or relative ("tomorrow", "next week")
    public let dueDate: String?

    /// Extracted due time in HH:mm format
    public let dueTime: String?

    /// Priority level extracted from keywords (high, medium, low)
    public let priority: String?

    /// Tags/categories extracted from the text
    public let tags: [String]

    /// Whether the reminder should repeat
    public let isRecurring: Bool

    /// Recurrence pattern if applicable (daily, weekly, monthly, yearly)
    public let recurringPattern: String?

    /// Location name or address if mentioned
    public let location: String?

    /// Additional notes or details extracted
    public let notes: String?

    /// Confidence score for the parsing (0.0 to 1.0)
    public let confidence: Double

    public init(
        title: String,
        dueDate: String? = nil,
        dueTime: String? = nil,
        priority: String? = nil,
        tags: [String] = [],
        isRecurring: Bool = false,
        recurringPattern: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        confidence: Double = 0.8
    ) {
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = priority
        self.tags = tags
        self.isRecurring = isRecurring
        self.recurringPattern = recurringPattern
        self.location = location
        self.notes = notes
        self.confidence = confidence
    }
}

// MARK: - Task Breakdown Models

/// A single subtask suggestion from AI task breakdown
@Generable
public struct AISubtask: Codable, Sendable, Hashable {
    /// The subtask title
    public let title: String

    /// Estimated time to complete in minutes
    public let estimatedMinutes: Int

    /// Order in the sequence (1-based)
    public let order: Int

    /// Optional dependencies on other subtasks (by order number)
    public let dependsOn: [Int]?

    /// Suggested priority for this subtask
    public let priority: String?

    public init(
        title: String,
        estimatedMinutes: Int,
        order: Int,
        dependsOn: [Int]? = nil,
        priority: String? = nil
    ) {
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.order = order
        self.dependsOn = dependsOn
        self.priority = priority
    }
}

/// Result of AI-powered task breakdown
@Generable
public struct AITaskBreakdown: Codable, Sendable, Hashable {
    /// List of suggested subtasks
    public let subtasks: [AISubtask]

    /// Total estimated time in minutes
    public let estimatedTotalMinutes: Int

    /// Complexity assessment: "simple", "moderate", "complex", or "very_complex"
    public let complexity: String

    /// Reasoning for the breakdown approach
    public let reasoning: String

    /// Suggested approach for tackling the task
    public let approach: String?

    public init(
        subtasks: [AISubtask],
        estimatedTotalMinutes: Int,
        complexity: String,
        reasoning: String,
        approach: String? = nil
    ) {
        self.subtasks = subtasks
        self.estimatedTotalMinutes = estimatedTotalMinutes
        self.complexity = complexity
        self.reasoning = reasoning
        self.approach = approach
    }

    /// Computed property to get the complexity as an enum
    public var complexityLevel: AIComplexityLevel {
        AIComplexityLevel(rawValue: complexity) ?? .moderate
    }
}

/// Task complexity levels
public enum AIComplexityLevel: String, Codable, Sendable, CaseIterable {
    case simple
    case moderate
    case complex
    case veryComplex = "very_complex"

    public var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        case .veryComplex: return "Very Complex"
        }
    }

    public var estimatedMultiplier: Double {
        switch self {
        case .simple: return 1.0
        case .moderate: return 1.5
        case .complex: return 2.0
        case .veryComplex: return 3.0
        }
    }
}

// MARK: - Productivity Analysis Models

/// AI-generated productivity insights
@Generable
public struct AIProductivityInsight: Codable, Sendable, Hashable {
    /// Brief summary of productivity status
    public let summary: String

    /// Key findings from the analysis
    public let keyFindings: [String]

    /// Actionable recommendations
    public let recommendations: [String]

    /// Overall productivity score (0-100)
    public let productivityScore: Int

    /// Trend direction: "improving", "stable", or "declining"
    public let trend: String

    /// Time of day with highest productivity
    public let peakProductivityTime: String?

    /// Areas needing improvement
    public let areasToImprove: [String]?

    public init(
        summary: String,
        keyFindings: [String],
        recommendations: [String],
        productivityScore: Int,
        trend: String,
        peakProductivityTime: String? = nil,
        areasToImprove: [String]? = nil
    ) {
        self.summary = summary
        self.keyFindings = keyFindings
        self.recommendations = recommendations
        self.productivityScore = productivityScore
        self.trend = trend
        self.peakProductivityTime = peakProductivityTime
        self.areasToImprove = areasToImprove
    }

    /// Computed property to get the trend as an enum
    public var trendType: AITrend {
        AITrend(rawValue: trend) ?? .stable
    }
}

/// Trend direction for metrics
public enum AITrend: String, Codable, Sendable, CaseIterable {
    case improving
    case stable
    case declining

    public var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    public var color: String {
        switch self {
        case .improving: return "#34C759"
        case .stable: return "#FF9500"
        case .declining: return "#FF3B30"
        }
    }
}

// MARK: - Habit Optimization Models

/// AI suggestions for habit optimization
@Generable
public struct AIHabitOptimization: Codable, Sendable, Hashable {
    /// Suggested optimal time to complete the habit
    public let optimalTime: String?

    /// Habits that could be stacked with this one
    public let stackingOpportunities: [AIHabitStack]

    /// Motivational tips specific to this habit
    public let motivationalTips: [String]

    /// Predicted success rate based on patterns (0-100)
    public let predictedSuccessRate: Int

    /// Suggested adjustments to make the habit easier
    public let suggestedAdjustments: [String]?

    public init(
        optimalTime: String? = nil,
        stackingOpportunities: [AIHabitStack] = [],
        motivationalTips: [String] = [],
        predictedSuccessRate: Int = 50,
        suggestedAdjustments: [String]? = nil
    ) {
        self.optimalTime = optimalTime
        self.stackingOpportunities = stackingOpportunities
        self.motivationalTips = motivationalTips
        self.predictedSuccessRate = predictedSuccessRate
        self.suggestedAdjustments = suggestedAdjustments
    }
}

/// A habit stacking suggestion
@Generable
public struct AIHabitStack: Codable, Sendable, Hashable {
    /// The habit to stack with
    public let habitName: String

    /// Whether to do before or after ("before" or "after")
    public let timing: String

    /// Why this stacking would work
    public let reasoning: String

    public init(habitName: String, timing: String, reasoning: String) {
        self.habitName = habitName
        self.timing = timing
        self.reasoning = reasoning
    }
}

// MARK: - Smart Scheduling Models

/// AI-suggested time slot for a task
@Generable
public struct AITimeSlot: Codable, Sendable, Hashable {
    /// Start time in ISO 8601 or relative format
    public let startTime: String

    /// End time in ISO 8601 or relative format
    public let endTime: String

    /// Confidence in this suggestion (0-100)
    public let confidence: Int

    /// Reason for suggesting this time
    public let reason: String

    public init(startTime: String, endTime: String, confidence: Int, reason: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.reason = reason
    }
}

/// AI-generated smart schedule suggestions
@Generable
public struct AISmartSchedule: Codable, Sendable, Hashable {
    /// Suggested time slots, ordered by preference
    public let suggestedTimeSlots: [AITimeSlot]

    /// Warnings about potential conflicts
    public let conflictWarnings: [String]

    /// Overall reasoning for the schedule
    public let reasoning: String

    /// Alternative approaches if primary fails
    public let alternatives: [String]?

    public init(
        suggestedTimeSlots: [AITimeSlot],
        conflictWarnings: [String] = [],
        reasoning: String,
        alternatives: [String]? = nil
    ) {
        self.suggestedTimeSlots = suggestedTimeSlots
        self.conflictWarnings = conflictWarnings
        self.reasoning = reasoning
        self.alternatives = alternatives
    }
}

// MARK: - Morning Briefing Models

/// AI-generated morning briefing
@Generable
public struct AIMorningBriefing: Codable, Sendable, Hashable {
    /// Personalized greeting
    public let greeting: String

    /// Today's priority tasks
    public let priorityTasks: [String]

    /// Suggested schedule for the day
    public let suggestedSchedule: [AIScheduleBlock]

    /// Weather-based recommendations (if applicable)
    public let weatherNote: String?

    /// Motivational message
    public let motivationalMessage: String

    /// Quick stats about pending work
    public let stats: AIDayStats

    public init(
        greeting: String,
        priorityTasks: [String],
        suggestedSchedule: [AIScheduleBlock],
        weatherNote: String? = nil,
        motivationalMessage: String,
        stats: AIDayStats
    ) {
        self.greeting = greeting
        self.priorityTasks = priorityTasks
        self.suggestedSchedule = suggestedSchedule
        self.weatherNote = weatherNote
        self.motivationalMessage = motivationalMessage
        self.stats = stats
    }
}

/// A time block in the schedule
@Generable
public struct AIScheduleBlock: Codable, Sendable, Hashable {
    /// Start time in HH:mm format
    public let startTime: String
    /// End time in HH:mm format
    public let endTime: String
    /// Description of the activity
    public let activity: String
    /// Type of block: "task", "meeting", "break", or "focus"
    public let type: String

    public init(startTime: String, endTime: String, activity: String, type: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.activity = activity
        self.type = type
    }
}

/// Quick stats for the day
@Generable
public struct AIDayStats: Codable, Sendable, Hashable {
    /// Total number of tasks for the day
    public let tasksTotal: Int
    /// Number of tasks completed
    public let tasksCompleted: Int
    /// Total number of habits for the day
    public let habitsTotal: Int
    /// Number of habits completed
    public let habitsCompleted: Int
    /// Minutes of focus time planned
    public let focusMinutesPlanned: Int

    public init(
        tasksTotal: Int,
        tasksCompleted: Int,
        habitsTotal: Int,
        habitsCompleted: Int,
        focusMinutesPlanned: Int
    ) {
        self.tasksTotal = tasksTotal
        self.tasksCompleted = tasksCompleted
        self.habitsTotal = habitsTotal
        self.habitsCompleted = habitsCompleted
        self.focusMinutesPlanned = focusMinutesPlanned
    }
}

// MARK: - Text Processing Models

/// Result of AI text enhancement
public struct AITextEnhancement: Codable, Sendable, Hashable {
    /// The enhanced text
    public let enhancedText: String

    /// Changes made to the text
    public let changes: [String]

    /// Confidence in the enhancement (0.0-1.0)
    public let confidence: Double

    public init(enhancedText: String, changes: [String], confidence: Double) {
        self.enhancedText = enhancedText
        self.changes = changes
        self.confidence = confidence
    }
}

/// Result of AI summarization
@Generable
public struct AISummary: Codable, Sendable, Hashable {
    /// Brief one-sentence summary
    public let briefSummary: String

    /// Key points extracted
    public let keyPoints: [String]

    /// Action items identified
    public let actionItems: [String]

    /// Overall urgency level: "low", "medium", "high", or "critical"
    public let urgencyLevel: String

    public init(
        briefSummary: String,
        keyPoints: [String],
        actionItems: [String],
        urgencyLevel: String
    ) {
        self.briefSummary = briefSummary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.urgencyLevel = urgencyLevel
    }

    /// Computed property to get the urgency as an enum
    public var urgency: AIUrgencyLevel {
        AIUrgencyLevel(rawValue: urgencyLevel) ?? .medium
    }
}

/// Urgency levels for tasks/content
public enum AIUrgencyLevel: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical

    public var displayName: String {
        rawValue.capitalized
    }

    public var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#FF9500"
        case .high: return "#FF3B30"
        case .critical: return "#8E44AD"
        }
    }
}

// MARK: - Visual Intelligence Models

/// Result of document analysis
public struct AIDocumentAnalysis: Codable, Sendable, Hashable {
    /// Type of document detected
    public let documentType: String

    /// Main content extracted
    public let content: String

    /// Action items found in the document
    public let actionItems: [String]

    /// Dates mentioned in the document
    public let dates: [String]

    /// Contact information found
    public let contacts: [String]

    /// Confidence in the analysis (0.0-1.0)
    public let confidence: Double

    public init(
        documentType: String,
        content: String,
        actionItems: [String],
        dates: [String],
        contacts: [String],
        confidence: Double
    ) {
        self.documentType = documentType
        self.content = content
        self.actionItems = actionItems
        self.dates = dates
        self.contacts = contacts
        self.confidence = confidence
    }
}

// MARK: - Contextual Actions Models

/// AI-suggested contextual action
public struct AIContextualAction: Codable, Sendable, Hashable, Identifiable {
    /// Stable identifier for SwiftUI diffing
    public let id: UUID

    /// The action title
    public let title: String

    /// Description of what the action does
    public let description: String

    /// Icon name for the action
    public let icon: String

    /// The action type identifier
    public let actionType: String

    /// Additional parameters for the action
    public let parameters: [String: String]?

    /// Confidence in the suggestion (0-100)
    public let confidence: Int

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        icon: String,
        actionType: String,
        parameters: [String: String]? = nil,
        confidence: Int = 80
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.actionType = actionType
        self.parameters = parameters
        self.confidence = confidence
    }
}

// MARK: - Weekly Review Models

/// AI-generated weekly review
@Generable
public struct AIWeeklyReview: Codable, Sendable, Hashable {
    /// Week number and date range
    public let weekInfo: String

    /// Overall summary of the week
    public let summary: String

    /// Key accomplishments
    public let accomplishments: [String]

    /// Areas that need attention
    public let areasForImprovement: [String]

    /// Goals for next week
    public let suggestedGoals: [String]

    /// Productivity metrics
    public let metrics: AIWeeklyMetrics

    /// Personalized insights
    public let insights: [String]

    public init(
        weekInfo: String,
        summary: String,
        accomplishments: [String],
        areasForImprovement: [String],
        suggestedGoals: [String],
        metrics: AIWeeklyMetrics,
        insights: [String]
    ) {
        self.weekInfo = weekInfo
        self.summary = summary
        self.accomplishments = accomplishments
        self.areasForImprovement = areasForImprovement
        self.suggestedGoals = suggestedGoals
        self.metrics = metrics
        self.insights = insights
    }
}

/// Weekly productivity metrics
@Generable
public struct AIWeeklyMetrics: Codable, Sendable, Hashable {
    /// Number of tasks completed this week
    public let tasksCompleted: Int
    /// Number of tasks created this week
    public let tasksCreated: Int
    /// Task completion rate (0.0 to 1.0)
    public let completionRate: Double
    /// Total focus minutes for the week
    public let focusMinutes: Int
    /// Habit completion rate (0.0 to 1.0)
    public let habitsCompletionRate: Double
    /// Number of active streaks
    public let streaksActive: Int
    /// Overall productivity score (0-100)
    public let productivityScore: Int

    public init(
        tasksCompleted: Int,
        tasksCreated: Int,
        completionRate: Double,
        focusMinutes: Int,
        habitsCompletionRate: Double,
        streaksActive: Int,
        productivityScore: Int
    ) {
        self.tasksCompleted = tasksCompleted
        self.tasksCreated = tasksCreated
        self.completionRate = completionRate
        self.focusMinutes = focusMinutes
        self.habitsCompletionRate = habitsCompletionRate
        self.streaksActive = streaksActive
        self.productivityScore = productivityScore
    }
}
