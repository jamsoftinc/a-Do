//
//  BehavioralLearningManager.swift
//  a-do
//
//  Behavioral learning system that tracks user actions and improves AI suggestions
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class BehavioralLearningManager {
    static let shared = BehavioralLearningManager()
    
    private let logger = Logger(subsystem: "a-do", category: "BehavioralLearning")
    private let mlPatternManager = MLPatternRecognitionManager.shared

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Learning state
    var isLearningEnabled: Bool = true
    var learningProgress: Double = 0.0
    private var actionBuffer: [UserAction] = []
    private var feedbackBuffer: [UserFeedback] = []
    private var lastProcessingDate: Date = Date.distantPast
    
    private init() {
        setupPeriodicProcessing()
    }
    
    // MARK: - User Action Tracking

    func trackAction(_ action: UserActionType, context: [String: Any] = [:], modelContext: ModelContext) {
        guard isProEnabled else {
            logger.warning("Behavioral learning is a Pro feature")
            return
        }

        guard isLearningEnabled else { return }
        
        let userAction = UserAction(
            type: action,
            timestamp: Date(),
            context: context,
            sessionId: getCurrentSessionId()
        )
        
        actionBuffer.append(userAction)
        
        // Store in SwiftData for persistence
        let learningData = AILearningData(
            dataType: .userBehavior,
            userId: getCurrentUserId(),
            sessionId: getCurrentSessionId()
        )
        learningData.setEventData(userAction)
        modelContext.insert(learningData)
        
        // Process immediately for critical actions
        if action.isCritical {
            Task { [weak self] in
                await self?.processActionImmediately(userAction, context: modelContext)
            }
        }
        
        logger.info("Tracked user action: \(action.rawValue)")
        
        // Trigger batch processing if buffer is full
        if actionBuffer.count >= 50 {
            Task { [weak self] in
                await self?.processBatchedActions(context: modelContext)
            }
        }
    }
    
    func trackSuggestionInteraction(
        suggestion: AISuggestion,
        interaction: SuggestionInteraction,
        modelContext: ModelContext
    ) {
        let context: [String: Any] = [
            "suggestionId": suggestion.id.uuidString,
            "suggestionType": suggestion.type.rawValue,
            "confidence": suggestion.confidence,
            "interaction": interaction.rawValue
        ]
        
        trackAction(.suggestionInteraction, context: context, modelContext: modelContext)
        
        // Update suggestion feedback immediately
        updateSuggestionFeedback(suggestion: suggestion, interaction: interaction, modelContext: modelContext)
    }
    
    func trackHabitCompletion(
        habit: Habit,
        completed: Bool,
        timing: HabitTiming,
        modelContext: ModelContext
    ) {
        let context: [String: Any] = [
            "habitId": habit.id.uuidString,
            "habitTitle": habit.title,
            "completed": completed,
            "timing": timing.rawValue,
            "currentStreak": habit.currentStreak
        ]
        
        trackAction(.habitCompletion, context: context, modelContext: modelContext)
        
        // Learn from habit completion patterns
        Task { [weak self] in
            await self?.learnFromHabitCompletion(habit: habit, completed: completed, timing: timing, context: modelContext)
        }
    }
    
    func trackTaskCompletion(
        reminder: Reminder,
        completedOnTime: Bool,
        actualTime: TimeInterval?,
        modelContext: ModelContext
    ) {
        let context: [String: Any] = [
            "reminderId": reminder.uuid.uuidString,
            "reminderTitle": reminder.title,
            "priority": reminder.priority.rawValue,
            "completedOnTime": completedOnTime,
            "actualTime": actualTime ?? 0,
            "hadDueDate": reminder.dueDate != nil
        ]
        
        trackAction(.taskCompletion, context: context, modelContext: modelContext)
        
        // Learn from task completion patterns
        Task { [weak self] in
            await self?.learnFromTaskCompletion(reminder: reminder, onTime: completedOnTime, context: modelContext)
        }
    }
    
    func trackFocusSession(
        session: FocusSession,
        effectiveness: Double,
        modelContext: ModelContext
    ) {
        let context: [String: Any] = [
            "sessionId": session.id.uuidString,
            "focusType": session.focusType.rawValue,
            "plannedDuration": session.plannedDuration,
            "actualDuration": session.actualDuration,
            "effectiveness": effectiveness,
            "interruptionCount": session.interruptionCount
        ]
        
        trackAction(.focusSessionComplete, context: context, modelContext: modelContext)
    }
    
    // MARK: - Feedback Collection
    
    func collectExplicitFeedback(
        suggestion: AISuggestion,
        rating: Int,
        feedback: String,
        wasHelpful: Bool,
        modelContext: ModelContext
    ) {
        let userFeedback = UserFeedback(
            suggestionId: suggestion.id,
            rating: rating,
            feedback: feedback,
            wasHelpful: wasHelpful,
            timestamp: Date()
        )
        
        feedbackBuffer.append(userFeedback)
        
        // Store feedback in suggestion
        suggestion.provideFeedback(rating: rating, feedback: feedback, wasHelpful: wasHelpful)
        
        // Learn from feedback immediately
        Task { [weak self] in
            await self?.learnFromExplicitFeedback(userFeedback, suggestion: suggestion, context: modelContext)
        }
        
        logger.info("Collected feedback for suggestion: \(suggestion.title)")
    }
    
    func collectImplicitFeedback(
        suggestion: AISuggestion,
        action: ImplicitFeedbackAction,
        context: [String: Any] = [:],
        modelContext: ModelContext
    ) {
        let implicitFeedback = ImplicitFeedback(
            suggestionId: suggestion.id,
            action: action,
            context: context,
            timestamp: Date()
        )
        
        // Store in learning data
        let learningData = AILearningData(
            dataType: .userBehavior,
            userId: getCurrentUserId(),
            sessionId: getCurrentSessionId()
        )
        learningData.setEventData(implicitFeedback)
        modelContext.insert(learningData)
        
        // Process implicit feedback
        Task { [weak self] in
            await self?.processImplicitFeedback(implicitFeedback, suggestion: suggestion, context: modelContext)
        }
    }
    
    // MARK: - Learning Processing
    
    private func processActionImmediately(_ action: UserAction, context: ModelContext) async {
        logger.info("Processing critical action immediately: \(action.type.rawValue)")
        
        switch action.type {
        case .suggestionApplied:
            await handleSuggestionApplied(action, context: context)
        case .suggestionDismissed:
            await handleSuggestionDismissed(action, context: context)
        case .taskRescheduled:
            await handleTaskRescheduled(action, context: context)
        case .habitSkipped:
            await handleHabitSkipped(action, context: context)
        default:
            break
        }
    }
    
    private func processBatchedActions(context: ModelContext) async {
        guard !actionBuffer.isEmpty else { return }
        
        logger.info("Processing \(self.actionBuffer.count) batched actions")
        
        // Analyze patterns in the batch
        let patterns = analyzeBatchPatterns(actionBuffer)
        
        // Update learning models
        await updateLearningModels(with: patterns, context: context)
        
        // Generate new insights
        await generateLearningInsights(from: patterns, context: context)
        
        // Clear buffer
        actionBuffer.removeAll()
        lastProcessingDate = Date()
    }
    
    private func updateSuggestionFeedback(
        suggestion: AISuggestion,
        interaction: SuggestionInteraction,
        modelContext: ModelContext
    ) {
        // Update suggestion effectiveness based on interaction
        switch interaction {
        case .applied:
            // Positive feedback - increase confidence in similar suggestions
            updateSuggestionTypeReliability(suggestion.type, delta: 0.1, modelContext: modelContext)
        case .dismissed:
            // Negative feedback - decrease confidence
            updateSuggestionTypeReliability(suggestion.type, delta: -0.05, modelContext: modelContext)
        case .modified:
            // Neutral feedback - learn from modifications
            updateSuggestionTypeReliability(suggestion.type, delta: 0.02, modelContext: modelContext)
        case .ignored:
            // Implicit negative feedback
            updateSuggestionTypeReliability(suggestion.type, delta: -0.02, modelContext: modelContext)
        }
    }
    
    private func learnFromHabitCompletion(
        habit: Habit,
        completed: Bool,
        timing: HabitTiming,
        context: ModelContext
    ) async {
        // Update habit success patterns
        let habitPatterns = await mlPatternManager.analyzeUserBehaviorPatterns(context: context)
        
        // Learn optimal timing for this habit
        if completed {
            updateOptimalHabitTiming(habit: habit, timing: timing, context: context)
        }
        
        // Adjust future suggestions based on success/failure
        await adjustHabitSuggestions(habit: habit, completed: completed, patterns: habitPatterns, context: context)
    }
    
    private func learnFromTaskCompletion(
        reminder: Reminder,
        onTime: Bool,
        context: ModelContext
    ) async {
        // Learn task completion patterns
        let taskPatterns = await mlPatternManager.analyzeUserBehaviorPatterns(context: context)
        
        if onTime {
            // Reinforce successful scheduling patterns
            await reinforceSchedulingPatterns(reminder: reminder, context: context)
        } else {
            // Learn from delays and adjust future suggestions
            await adjustSchedulingSuggestions(reminder: reminder, patterns: taskPatterns, context: context)
        }
    }
    
    private func learnFromExplicitFeedback(
        _ feedback: UserFeedback,
        suggestion: AISuggestion,
        context: ModelContext
    ) async {
        // Update AI model performance metrics
        let performance = getOrCreateModelPerformance(suggestion.type, context: context)
        
        let wasCorrect = feedback.rating >= 3
        performance.totalPredictions += 1
        if wasCorrect {
            performance.correctPredictions += 1
        }
        
        performance.userSatisfactionScore = calculateAverageRating(for: suggestion.type, context: context)
        performance.updateMetrics(
            accuracy: Double(performance.correctPredictions) / Double(performance.totalPredictions),
            precision: calculatePrecision(for: suggestion.type, context: context),
            recall: calculateRecall(for: suggestion.type, context: context),
            userSatisfactionScore: performance.userSatisfactionScore,
            totalPredictions: performance.totalPredictions,
            correctPredictions: performance.correctPredictions
        )
        
        // Use feedback to improve future suggestions
        await incorporateFeedbackIntoModel(feedback, suggestion: suggestion, context: context)
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeBatchPatterns(_ actions: [UserAction]) -> [String: Any] {
        var patterns: [String: Any] = [:]
        
        // Analyze temporal patterns
        patterns["timePatterns"] = analyzeTimePatterns(actions)
        
        // Analyze action sequences
        patterns["actionSequences"] = analyzeActionSequences(actions)
        
        // Analyze success rates by type
        patterns["successRates"] = analyzeSuccessRates(actions)
        
        // Analyze user preferences
        patterns["preferences"] = analyzePreferencePatterns(actions)
        
        return patterns
    }
    
    private func analyzeTimePatterns(_ actions: [UserAction]) -> [String: Any] {
        let hourlyDistribution = Dictionary(grouping: actions) { action in
            Calendar.current.component(.hour, from: action.timestamp)
        }
        
        let dailyDistribution = Dictionary(grouping: actions) { action in
            Calendar.current.component(.weekday, from: action.timestamp)
        }
        
        return [
            "hourlyDistribution": hourlyDistribution.mapValues(\.count),
            "dailyDistribution": dailyDistribution.mapValues(\.count),
            "peakHours": hourlyDistribution.sorted { $0.value.count > $1.value.count }.prefix(3).map(\.key)
        ]
    }
    
    private func analyzeActionSequences(_ actions: [UserAction]) -> [String: Any] {
        let sequences = extractActionSequences(actions, windowSize: 5)
        let frequentSequences = findFrequentSequences(sequences, minSupport: 0.1)
        
        return [
            "sequences": sequences.map { $0.map(\.type.rawValue) },
            "frequentPatterns": frequentSequences.map { $0.map(\.type.rawValue) },
            "sequenceLength": sequences.count
        ]
    }
    
    private func analyzeSuccessRates(_ actions: [UserAction]) -> [String: Any] {
        let successfulActions = actions.filter { $0.type.isPositive }
        let totalActions = actions.count
        
        let successRateByType = Dictionary(grouping: actions, by: \.type)
            .mapValues { typeActions in
                let successful = typeActions.filter { $0.type.isPositive }.count
                return Double(successful) / Double(typeActions.count)
            }
        
        return [
            "overallSuccessRate": totalActions > 0 ? Double(successfulActions.count) / Double(totalActions) : 0,
            "successRateByType": successRateByType
        ]
    }
    
    // MARK: - Learning Updates
    
    private func updateLearningModels(with patterns: [String: Any], context: ModelContext) async {
        // Update user behavior model
        await updateUserBehaviorModel(patterns: patterns)
        
        // Update prediction confidence
        await updatePredictionConfidence(patterns: patterns, context: context)
        
        // Update feature weights
        await updateFeatureWeights(patterns: patterns)
        
        logger.info("Updated learning models with new patterns")
    }
    
    private func generateLearningInsights(from patterns: [String: Any], context: ModelContext) async {
        // Generate insights based on learned patterns
        let insights = await mlPatternManager.generatePersonalizedInsights(context: context)
        
        // Create AI insights from learning patterns
        for insight in insights.prefix(3) {
            let aiInsight = AIInsight(
                type: mapInsightCategory(insight.category),
                title: "Learning Insight: \(insight.title)",
                summary: insight.description,
                confidence: insight.confidence
            )
            
            aiInsight.detailedAnalysis = insight.actionableSteps.joined(separator: "\n")
            context.insert(aiInsight)
        }
        
        logger.info("Generated \(insights.count) learning insights")
    }
    
    // Timer for periodic processing - must be retained
    private var processingTimer: Timer?

    // MARK: - Utility Methods

    private func setupPeriodicProcessing() {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Process any remaining actions in buffer
                if !self.actionBuffer.isEmpty {
                    // Would need context here in real implementation
                    // await self.processBatchedActions(context: context)
                }
            }
        }
    }

    /// Call this method to clean up resources when the manager is no longer needed
    func cleanup() {
        processingTimer?.invalidate()
        processingTimer = nil
        actionBuffer.removeAll()
        feedbackBuffer.removeAll()
    }
    
    private func getCurrentUserId() -> String {
        return "current-user" // In real app, would get from authentication
    }
    
    private func getCurrentSessionId() -> String {
        return UUID().uuidString // In real app, would maintain session ID
    }
    
    private func updateSuggestionTypeReliability(
        _ type: AISuggestionType,
        delta: Double,
        modelContext: ModelContext
    ) {
        // Update reliability metrics for suggestion type
        // This would be stored in a dedicated model or configuration
        logger.info("Updated reliability for \(type.displayName) by \(delta)")
    }
    
    private func getOrCreateModelPerformance(
        _ suggestionType: AISuggestionType,
        context: ModelContext
    ) -> AIModelPerformance {
        let descriptor = FetchDescriptor<AIModelPerformance>(
            predicate: #Predicate { $0.modelName == suggestionType.rawValue }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let performance = AIModelPerformance(
            modelName: suggestionType.rawValue,
            modelVersion: "1.0"
        )
        context.insert(performance)
        return performance
    }
    
    // MARK: - Helper Methods (Placeholder implementations)
    
    private func handleSuggestionApplied(_ action: UserAction, context: ModelContext) async {
        // Implementation for handling applied suggestions
    }
    
    private func handleSuggestionDismissed(_ action: UserAction, context: ModelContext) async {
        // Implementation for handling dismissed suggestions
    }
    
    private func handleTaskRescheduled(_ action: UserAction, context: ModelContext) async {
        // Implementation for handling rescheduled tasks
    }
    
    private func handleHabitSkipped(_ action: UserAction, context: ModelContext) async {
        // Implementation for handling skipped habits
    }
    
    private func updateOptimalHabitTiming(habit: Habit, timing: HabitTiming, context: ModelContext) {
        // Update optimal timing patterns for the habit
    }
    
    private func adjustHabitSuggestions(
        habit: Habit,
        completed: Bool,
        patterns: UserBehaviorAnalysis,
        context: ModelContext
    ) async {
        // Adjust future habit suggestions based on completion patterns
    }
    
    private func reinforceSchedulingPatterns(reminder: Reminder, context: ModelContext) async {
        // Reinforce successful scheduling patterns
    }
    
    private func adjustSchedulingSuggestions(
        reminder: Reminder,
        patterns: UserBehaviorAnalysis,
        context: ModelContext
    ) async {
        // Adjust scheduling suggestions based on delays
    }
    
    private func processImplicitFeedback(
        _ feedback: ImplicitFeedback,
        suggestion: AISuggestion,
        context: ModelContext
    ) async {
        // Process implicit feedback from user actions
    }
    
    private func incorporateFeedbackIntoModel(
        _ feedback: UserFeedback,
        suggestion: AISuggestion,
        context: ModelContext
    ) async {
        // Incorporate explicit feedback into learning models
    }
    
    private func calculateAverageRating(for type: AISuggestionType, context: ModelContext) -> Double {
        // Calculate average rating for suggestion type
        return 3.5 // Placeholder
    }
    
    private func calculatePrecision(for type: AISuggestionType, context: ModelContext) -> Double {
        // Calculate precision for suggestion type
        return 0.75 // Placeholder
    }
    
    private func calculateRecall(for type: AISuggestionType, context: ModelContext) -> Double {
        // Calculate recall for suggestion type
        return 0.68 // Placeholder
    }
    
    private func extractActionSequences(_ actions: [UserAction], windowSize: Int) -> [[UserAction]] {
        // Extract sequences of actions within a time window
        return [] // Placeholder
    }
    
    private func findFrequentSequences(_ sequences: [[UserAction]], minSupport: Double) -> [[UserAction]] {
        // Find frequently occurring action sequences
        return [] // Placeholder
    }
    
    private func analyzePreferencePatterns(_ actions: [UserAction]) -> [String: Any] {
        // Analyze user preference patterns from actions
        return [:] // Placeholder
    }
    
    private func updateUserBehaviorModel(patterns: [String: Any]) async {
        // Update the user behavior learning model
    }
    
    private func updatePredictionConfidence(patterns: [String: Any], context: ModelContext) async {
        // Update prediction confidence based on success patterns
    }
    
    private func updateFeatureWeights(patterns: [String: Any]) async {
        // Update feature weights in learning models
    }
    
    private func mapInsightCategory(_ category: InsightCategory) -> AIInsightType {
        switch category {
        case .productivity: return .productivityTrend
        case .timeManagement: return .timeUsageAnalysis
        case .habitFormation: return .habitProgress
        case .wellness: return .burnoutRisk
        case .focus: return .focusEffectiveness
        }
    }
}

// MARK: - Supporting Types

struct UserAction {
    let type: UserActionType
    let timestamp: Date
    let context: [String: Any]
    let sessionId: String
}

enum UserActionType: String, CaseIterable {
    case suggestionApplied = "suggestion_applied"
    case suggestionDismissed = "suggestion_dismissed"
    case suggestionModified = "suggestion_modified"
    case suggestionInteraction = "suggestion_interaction"
    case taskCompleted = "task_completed"
    case taskRescheduled = "task_rescheduled"
    case taskDeleted = "task_deleted"
    case habitCompleted = "habit_completed"
    case habitSkipped = "habit_skipped"
    case focusSessionStarted = "focus_session_started"
    case focusSessionComplete = "focus_session_complete"
    case focusSessionInterrupted = "focus_session_interrupted"
    case settingsChanged = "settings_changed"
    case viewNavigation = "view_navigation"
    case searchPerformed = "search_performed"
    case filterApplied = "filter_applied"
    case habitCompletion = "habit_completion"
    case taskCompletion = "task_completion"
    
    var isCritical: Bool {
        switch self {
        case .suggestionApplied, .suggestionDismissed, .taskRescheduled, .habitSkipped:
            return true
        default:
            return false
        }
    }
    
    var isPositive: Bool {
        switch self {
        case .suggestionApplied, .taskCompleted, .habitCompleted, .focusSessionComplete:
            return true
        default:
            return false
        }
    }
}

enum SuggestionInteraction: String {
    case applied = "applied"
    case dismissed = "dismissed"
    case modified = "modified"
    case ignored = "ignored"
}

enum HabitTiming: String {
    case early = "early"
    case onTime = "on_time"
    case late = "late"
}

struct UserFeedback {
    let suggestionId: UUID
    let rating: Int
    let feedback: String
    let wasHelpful: Bool
    let timestamp: Date
}

struct ImplicitFeedback {
    let suggestionId: UUID
    let action: ImplicitFeedbackAction
    let context: [String: Any]
    let timestamp: Date
}

enum ImplicitFeedbackAction: String {
    case viewedLong = "viewed_long"
    case viewedBrief = "viewed_brief"
    case scrolledPast = "scrolled_past"
    case clickedDetails = "clicked_details"
    case sharedSuggestion = "shared_suggestion"
    case bookmarkedSuggestion = "bookmarked_suggestion"
}

// MARK: - Extensions

extension UserActionType: Codable {}
extension SuggestionInteraction: Codable {}
extension HabitTiming: Codable {}
extension ImplicitFeedbackAction: Codable {}

extension UserAction: Codable {
    enum CodingKeys: String, CodingKey {
        case type, timestamp, sessionId
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        // Note: context is not encoded due to [String: Any] complexity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(UserActionType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        context = [:] // Would need custom decoding for context
    }
}

extension UserFeedback: Codable {}
extension ImplicitFeedback: Codable {
    enum CodingKeys: String, CodingKey {
        case suggestionId, action, timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(suggestionId, forKey: .suggestionId)
        try container.encode(action, forKey: .action)
        try container.encode(timestamp, forKey: .timestamp)
        // Note: context is not encoded due to [String: Any] complexity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        suggestionId = try container.decode(UUID.self, forKey: .suggestionId)
        action = try container.decode(ImplicitFeedbackAction.self, forKey: .action)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        context = [:] // Would need custom decoding for context
    }
}