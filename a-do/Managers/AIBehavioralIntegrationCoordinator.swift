//
//  AIBehavioralIntegrationCoordinator.swift
//  a-do
//
//  Coordinates AI systems with behavioral learning for continuous improvement
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class AIBehavioralIntegrationCoordinator {
    static let shared = AIBehavioralIntegrationCoordinator()
    
    private let logger = Logger(subsystem: "a-do", category: "AIBehavioralIntegration")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // AI Managers
    private let aiManager = AIManager.shared
    private let mlPatternRecognition = MLPatternRecognitionManager.shared
    
    // Integration state
    var isIntegrationActive: Bool = true
    var lastLearningUpdate: Date = Date.distantPast
    var learningCycleInterval: TimeInterval = 3600 // 1 hour
    
    private init() {}

    /// Call this method to clean up resources when the coordinator is no longer needed
    func cleanup() {
        isIntegrationActive = false
    }

    func runLearningCycleIfNeeded(context: ModelContext, reason: String, force: Bool = false) async {
        let isStale = Date().timeIntervalSince(lastLearningUpdate) >= learningCycleInterval
        guard force || isStale else { return }
        logger.info("Running AI behavioral learning cycle for \(reason, privacy: .public)")
        await runLearningCycle(context: context)
    }
    
    /// Runs a complete learning cycle that improves AI suggestions based on user behavior
    func runLearningCycle() async {
        guard isProEnabled else {
            logger.warning("AI behavioral learning is a Pro feature")
            return
        }

        guard isIntegrationActive else { return }
        
        guard let context = getCurrentModelContext() else {
            logger.error("AI behavioral learning skipped because no SwiftData container is available")
            return
        }
        await runLearningCycle(context: context)
    }
    
    func runLearningCycle(context: ModelContext) async {
        guard isProEnabled else { return }
        guard isIntegrationActive else { return }
        
        logger.info("Starting AI behavioral learning cycle")
        
        // Step 1: Analyze user behavior patterns
        let behaviorPatterns = await mlPatternRecognition.analyzeUserBehaviorPatterns(context: context)

        // Step 2: Generate personalized insights based on patterns
        let personalizedInsights = await mlPatternRecognition.generatePersonalizedInsights(context: context)

        // Step 3: Update AI suggestion algorithms with learned patterns
        await updateAISuggestionAlgorithms(patterns: behaviorPatterns, context: context)

        // Step 4: Refresh AI suggestions with improved algorithms
        await aiManager.generateSuggestions(userId: SecurityUtils.getCurrentUserID(), context: context)

        // Step 5: Create insights from behavioral data
        await generateBehavioralInsights(insights: personalizedInsights, context: context)

        lastLearningUpdate = Date()
        logger.info("Completed AI behavioral learning cycle")
    }
    
    // MARK: - AI Algorithm Updates
    
    private func updateAISuggestionAlgorithms(patterns: UserBehaviorAnalysis, context: ModelContext) async {
        logger.info("Updating AI algorithms with behavioral patterns")

        let peakHours = patterns.timeUsagePatterns.peakProductivityHours
        
        var successFactors: [String: Double] = [:]
        if !patterns.habitPatterns.successRates.isEmpty {
            let averageSuccess = patterns.habitPatterns.successRates.values.reduce(0, +) / Double(patterns.habitPatterns.successRates.count)
            successFactors["average_success_rate"] = averageSuccess
        } else {
            successFactors["average_success_rate"] = 0.0
        }
        successFactors["overall_behavior_score"] = patterns.overallScore
        
        let averageDelayHours = patterns.taskCompletionPatterns.averageCompletionDelay / 3600
        let taskPatterns: [String: Any] = [
            "average_delay_hours": averageDelayHours,
            "procrastination_score": patterns.taskCompletionPatterns.procrastinationScore,
            "optimal_completion_hours": patterns.taskCompletionPatterns.optimalCompletionHours
        ]
        
        var focusFactors: [String: Double] = [:]
        let focusEffectivenessValues = patterns.productivityPatterns.focusTypeEffectiveness.values
        if !focusEffectivenessValues.isEmpty {
            let averageFocusScore = focusEffectivenessValues.reduce(0, +) / Double(focusEffectivenessValues.count)
            focusFactors["average_focus_effectiveness"] = averageFocusScore
        } else {
            focusFactors["average_focus_effectiveness"] = 0.0
        }
        focusFactors["burnout_risk"] = patterns.productivityPatterns.burnoutRiskScore
        focusFactors["consistency_score"] = patterns.timeUsagePatterns.consistencyScore
        
        await updateProductivitySuggestionTiming(peakHours: peakHours, context: context)
        await updateHabitSuggestionWeights(successFactors: successFactors, context: context)
        await updateTaskSchedulingSuggestions(patterns: taskPatterns, context: context)
        await updateFocusSessionRecommendations(factors: focusFactors, context: context)
        
        logger.info("Updated AI algorithms with learned behavioral patterns")
    }
    
    private func generateBehavioralInsights(insights: [PersonalizedInsight], context: ModelContext) async {
        logger.info("Generating behavioral insights for AI system")
        
        let existingInsights = (try? context.fetch(FetchDescriptor<AIInsight>())) ?? []
        let existingTitles = Set(existingInsights.map(\.title))
        var insertedCount = 0
        
        for insight in insights {
            let title = "Behavioral Learning: \(insight.title)"
            guard !existingTitles.contains(title) else { continue }
            
            let aiInsight = AIInsight(
                type: mapInsightCategoryToAIType(insight.category),
                title: title,
                summary: insight.description,
                confidence: insight.confidence
            )
            
            aiInsight.detailedAnalysis = [
                "Based on your behavioral patterns:",
                insight.description,
                "",
                "Recommended actions:",
                insight.actionableSteps.joined(separator: "\n• ")
            ].joined(separator: "\n")
            
            // Add behavioral context to user notes instead of tags
            aiInsight.addUserNotes("Generated from behavioral learning analysis. Tags: behavioral-learning, personalized")
            
            context.insert(aiInsight)
            insertedCount += 1
        }
        
        do {
            try context.save()
            logger.info("Created \(insertedCount) behavioral insights")
        } catch {
            logger.error("Failed to save behavioral insights: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Specific Algorithm Updates
    
    private func updateProductivitySuggestionTiming(peakHours: [Int], context: ModelContext) async {
        let config = await getOrCreateAIConfiguration(context: context)
        
        if peakHours.count >= 6 {
            config.suggestionFrequency = .hourly
        } else if peakHours.count >= 3 {
            config.suggestionFrequency = .daily
        } else {
            config.suggestionFrequency = .manual
        }
        
        config.proactiveNotifications = !peakHours.isEmpty
        config.lastUpdated = Date()

        logger.info("Updated productivity peak hours: \(peakHours)")
    }

    private func updateHabitSuggestionWeights(successFactors: [String: Double], context: ModelContext) async {
        let config = await getOrCreateAIConfiguration(context: context)
        
        let averageSuccess = successFactors["average_success_rate"] ?? 0
        config.personalizedRecommendations = averageSuccess >= 0.35
        
        // Lower confidence threshold when habits are unstable so more guidance can appear.
        if averageSuccess < 0.35 {
            config.minimumConfidenceThreshold = 0.55
        } else if averageSuccess > 0.75 {
            config.minimumConfidenceThreshold = 0.75
        } else {
            config.minimumConfidenceThreshold = 0.65
        }
        
        config.lastUpdated = Date()

        logger.info("Updated habit suggestion weights for \(successFactors.count) factors")
    }

    private func updateTaskSchedulingSuggestions(patterns: [String: Any], context: ModelContext) async {
        let config = await getOrCreateAIConfiguration(context: context)
        
        let averageDelayHours = (patterns["average_delay_hours"] as? Double) ?? 0
        let procrastinationScore = (patterns["procrastination_score"] as? Double) ?? 0
        
        if averageDelayHours > 12 || procrastinationScore > 0.5 {
            config.maxSuggestionsPerDay = 7
        } else {
            config.maxSuggestionsPerDay = 4
        }
        
        config.lastUpdated = Date()

        logger.info("Updated task scheduling suggestions based on completion patterns")
    }

    private func updateFocusSessionRecommendations(factors: [String: Double], context: ModelContext) async {
        let config = await getOrCreateAIConfiguration(context: context)
        
        let burnoutRisk = factors["burnout_risk"] ?? 0
        let consistency = factors["consistency_score"] ?? 0
        
        if burnoutRisk > 0.6 {
            config.proactiveNotifications = true
            config.maxSuggestionsPerDay = max(config.maxSuggestionsPerDay, 6)
        }
        
        if consistency < 0.4 {
            config.suggestionFrequency = .realtime
        }
        
        config.lastUpdated = Date()

        logger.info("Updated focus session recommendations based on effectiveness factors")
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentModelContext() -> ModelContext? {
        guard let container = AppContainer.shared.getContainer() else { return nil }
        return ModelContext(container)
    }
    
    private func getOrCreateAIConfiguration(context: ModelContext) async -> AIConfiguration {
        let descriptor = FetchDescriptor<AIConfiguration>()
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let config = AIConfiguration(
            userId: SecurityUtils.getCurrentUserID()
        )
        context.insert(config)
        return config
    }
    
    private func mapInsightCategoryToAIType(_ category: InsightCategory) -> AIInsightType {
        switch category {
        case .productivity: return .productivityTrend
        case .timeManagement: return .timeUsageAnalysis
        case .habitFormation: return .habitProgress
        case .wellness: return .burnoutRisk
        case .focus: return .focusEffectiveness
        }
    }
}
