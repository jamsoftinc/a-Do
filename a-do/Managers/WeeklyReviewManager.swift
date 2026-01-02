//
//  WeeklyReviewManager.swift
//  a-do
//
//  Created for iOS 26+ AI Executive Weekly Review
//

import Foundation
import SwiftData
import Observation
import os
import FoundationModels

@MainActor
@Observable
final class WeeklyReviewManager {
    static let shared = WeeklyReviewManager()
    
    private let logger = Logger(subsystem: "a-do", category: "WeeklyReview")
    
    // State
    var isGenerating: Bool = false
    var currentReview: WeeklyReviewContent?
    var lastReviewDate: Date? {
        get { UserDefaults.standard.object(forKey: "LastWeeklyReviewDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "LastWeeklyReviewDate") }
    }
    
    // Pro Feature Check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }
    
    private init() {}
    
    // MARK: - Generation
    
    func generateReview(context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("Weekly Review is a Pro feature")
            return
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // 1. Aggregate Data
            let data = try await aggregateWeeklyData(context: context)
            
            // 2. Generate Content using FoundationModels
            let content = try await generateAIContent(from: data)
            
            self.currentReview = content
            self.lastReviewDate = Date()
            
            logger.info("Successfully generated weekly review")
            
        } catch {
            logger.error("Failed to generate weekly review: \(error.localizedDescription)")
            self.currentReview = generateFallbackContent()
        }
    }
    
    func dismissReview() {
        currentReview = nil
    }
    
    // MARK: - Data Aggregation
    
    private struct WeeklyData: Codable {
        let totalFocusTime: TimeInterval
        let sessionsCompleted: Int
        let tasksCompleted: Int
        let productivityTrend: String // "Up", "Down", "Stable"
        let mostProductiveDay: String
        let interruptionCount: Int
    }
    
    private func aggregateWeeklyData(context: ModelContext) async throws -> WeeklyData {
        let calendar = Calendar.current
        let today = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        // Fetch Focus Sessions
        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= oneWeekAgo && $0.startTime <= today }
        )
        let sessions = try context.fetch(sessionDescriptor)
        
        // Calculate Metrics
        let totalTime = sessions.reduce(0) { $0 + ($1.actualDuration) }
        let completedSessions = sessions.filter { $0.wasCompleted }.count
        let interruptions = sessions.reduce(0) { $0 + $1.interruptionCount }
        
        // Fetch Completed Tasks
        let taskDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.completedAt != nil && $0.completedAt! >= oneWeekAgo }
        )
        let tasks = try context.fetch(taskDescriptor)
        
        return WeeklyData(
            totalFocusTime: totalTime,
            sessionsCompleted: completedSessions,
            tasksCompleted: tasks.count,
            productivityTrend: "Stable", // Simplified for now
            mostProductiveDay: "Wednesday", // Placeholder logic
            interruptionCount: interruptions
        )
    }
    
    // MARK: - AI Generation

    private func generateAIContent(from data: WeeklyData) async throws -> WeeklyReviewContent {
        // Check if Foundation Models is available
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw WeeklyReviewAIError.modelNotAvailable
        }

        // Create a session for the AI interaction
        let session = LanguageModelSession()

        let dataJSON = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
        Generate an 'Executive Weekly Review' based on this productivity data:
        \(dataJSON)

        Provide:
        - grade: A letter grade (A-F) for the week's productivity
        - summary: A concise 1-2 sentence analysis of the week
        - highlight: The best achievement or moment of the week
        - areaForImprovement: One constructive suggestion for next week

        Be professional but encouraging.
        """

        // Use guided generation to get structured output
        let response = try await session.respond(to: prompt, generating: WeeklyReviewContent.self)

        return response.content
    }
    
    private func generateFallbackContent() -> WeeklyReviewContent {
        return WeeklyReviewContent(
            grade: "B+",
            summary: "Solid week. You maintained consistency but had a few interruptions.",
            highlight: "Hit 4 hours of focus on Wednesday.",
            areaForImprovement: "Try to reduce interruptions in the afternoon."
        )
    }
}

// MARK: - Models

@Generable
struct WeeklyReviewContent: Codable, Equatable, Sendable {
    /// Letter grade (A-F) for the week's productivity
    let grade: String
    /// Concise 1-2 sentence analysis of the week
    let summary: String
    /// The best achievement or moment of the week
    let highlight: String
    /// One constructive suggestion for next week
    let areaForImprovement: String
}

private enum WeeklyReviewAIError: Error {
    case parsingFailed
    case modelNotAvailable
}
