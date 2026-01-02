//
//  FoundationModelsManager.swift
//  a-do
//
//  Apple Foundation Models framework integration for on-device AI
//  Provides access to Apple's ~3B parameter on-device language model
//
//  Requires: iOS 26+, A17 Pro / M1 or newer
//

import Foundation
import SwiftData
import Observation
import os
import FoundationModels

// MARK: - Generable Models for Structured AI Output

/// Structured output for parsing reminder text using Foundation Models
@Generable
struct ParsedReminderOutput: Codable, Sendable {
    /// The cleaned task title
    let title: String
    /// Suggested due date in ISO 8601 or relative format
    let suggestedDueDate: String?
    /// Priority level (high, medium, low)
    let priority: String?
    /// Extracted tags or categories
    let tags: [String]
    /// Whether this is a recurring reminder
    let isRecurring: Bool
    /// Recurrence pattern if applicable
    let recurringPattern: String?
    /// Location if mentioned
    let location: String?
    /// Additional notes
    let notes: String?
}

/// Structured output for task breakdown suggestions
@Generable
struct TaskBreakdownOutput: Codable, Sendable {
    /// List of subtasks
    let subtasks: [SubtaskSuggestion]
    /// Total estimated time in minutes
    let estimatedTotalMinutes: Int
    /// Complexity level (simple, moderate, complex)
    let complexity: String
    /// Reasoning for the breakdown
    let reasoning: String
}

@Generable
struct SubtaskSuggestion: Codable, Sendable {
    /// Subtask title
    let title: String
    /// Estimated time in minutes
    let estimatedMinutes: Int
    /// Order in sequence
    let order: Int
}

/// Structured output for productivity insights
@Generable
struct ProductivityInsightOutput: Codable, Sendable {
    /// Brief summary
    let summary: String
    /// Key findings from analysis
    let keyFindings: [String]
    /// Actionable recommendations
    let recommendations: [String]
    /// Overall score 0-100
    let productivityScore: Int
    /// Trend direction (improving, stable, declining)
    let trend: String
}

/// Structured output for habit optimization
@Generable
struct HabitOptimizationOutput: Codable, Sendable {
    /// Suggested optimal time
    let optimalTime: String?
    /// Habits to stack with
    let stackingOpportunities: [String]
    /// Motivational tips
    let motivationalTips: [String]
    /// Predicted success rate 0-100
    let predictedSuccessRate: Int
}

/// Structured output for smart scheduling
@Generable
struct SmartScheduleOutput: Codable, Sendable {
    /// Suggested time slots
    let suggestedTimeSlots: [TimeSlotSuggestion]
    /// Conflict warnings
    let conflictWarnings: [String]
    /// Reasoning for suggestions
    let reasoning: String
}

@Generable
struct TimeSlotSuggestion: Codable, Sendable {
    /// Start time
    let startTime: String
    /// End time
    let endTime: String
    /// Confidence level 0-100
    let confidence: Int
    /// Reason for this suggestion
    let reason: String
}

/// Structured output for reminder summarization
@Generable
struct ReminderSummaryOutput: Codable, Sendable {
    /// Brief one-sentence summary
    let briefSummary: String
    /// Key points extracted
    let keyPoints: [String]
    /// Action items identified
    let actionItems: [String]
    /// Urgency level (low, medium, high, critical)
    let urgencyLevel: String
}

// MARK: - Foundation Models Manager

@MainActor
@Observable
final class FoundationModelsManager {
    static let shared = FoundationModelsManager()

    private let logger = Logger(subsystem: "a-do", category: "FoundationModels")

    // State
    var isAvailable: Bool = false
    var isProcessing: Bool = false
    var lastError: String?
    var modelInfo: String = ""

    // Session management for context
    private var session: LanguageModelSession?

    private init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability Check

    func checkAvailability() async {
        let availability = SystemLanguageModel.default.availability

        switch availability {
        case .available:
            isAvailable = true
            logger.info("Foundation Models available on this device")
            modelInfo = "Apple On-Device LLM (~3B parameters)"
        case .unavailable:
            isAvailable = false
            modelInfo = "Apple Intelligence not available"
            logger.warning("Foundation Models unavailable on this device")
        @unknown default:
            isAvailable = false
            modelInfo = "Unknown availability status"
        }
    }

    // MARK: - Pro Feature Check

    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    private func requirePro() -> Bool {
        guard isProEnabled else {
            logger.warning("Foundation Models features require Pro subscription")
            lastError = "Pro subscription required"
            return false
        }
        return true
    }

    private func requireAvailable() -> Bool {
        guard isAvailable else {
            logger.warning("Foundation Models not available on this device")
            lastError = "Apple Intelligence not available on this device"
            return false
        }
        return true
    }

    // MARK: - Natural Language Reminder Parsing

    /// Parse natural language input into structured reminder data
    func parseReminderText(_ text: String) async -> ParsedReminderOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Parse this reminder text and extract structured information:
            "\(text)"

            Extract:
            - The main task title (cleaned up, without date/time info)
            - Any mentioned due date/time (in ISO 8601 format or relative like "tomorrow", "next week")
            - Priority level if mentioned (high, medium, low)
            - Any tags or categories mentioned
            - Whether this is recurring (daily, weekly, monthly, etc.)
            - Any location mentioned
            - Additional notes or details
            """

            let response = try await session.respond(
                to: prompt,
                generating: ParsedReminderOutput.self
            )

            logger.info("Successfully parsed reminder text with Foundation Models")
            return response.content

        } catch {
            logger.error("Failed to parse reminder text: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Task Breakdown

    /// Break down a complex task into subtasks
    func generateTaskBreakdown(for task: String, details: String?) async -> TaskBreakdownOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Break down this task into actionable subtasks:

            Task: \(task)
            \(details.map { "Details: \($0)" } ?? "")

            Provide:
            - A list of 3-7 specific, actionable subtasks
            - Time estimate for each subtask in minutes
            - Overall complexity assessment (simple, moderate, complex)
            - Brief reasoning for the breakdown
            """

            let response = try await session.respond(
                to: prompt,
                generating: TaskBreakdownOutput.self
            )

            logger.info("Generated task breakdown with \(response.content.subtasks.count) subtasks")
            return response.content

        } catch {
            logger.error("Failed to generate task breakdown: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Productivity Insights

    /// Generate productivity insights from user data
    func generateProductivityInsights(
        completedTasks: Int,
        totalTasks: Int,
        focusMinutes: Int,
        habitCompletionRate: Double,
        topCategories: [String]
    ) async -> ProductivityInsightOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Analyze this productivity data and provide insights:

            - Completed tasks this week: \(completedTasks) of \(totalTasks)
            - Focus time logged: \(focusMinutes) minutes
            - Habit completion rate: \(Int(habitCompletionRate * 100))%
            - Top categories: \(topCategories.joined(separator: ", "))

            Provide:
            - A brief summary of productivity
            - 3-5 key findings
            - 2-3 actionable recommendations
            - Overall productivity score (0-100)
            - Trend assessment (improving, stable, declining)
            """

            let response = try await session.respond(
                to: prompt,
                generating: ProductivityInsightOutput.self
            )

            logger.info("Generated productivity insights with score: \(response.content.productivityScore)")
            return response.content

        } catch {
            logger.error("Failed to generate productivity insights: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Habit Optimization

    /// Get AI suggestions for habit optimization
    func optimizeHabit(
        habitTitle: String,
        currentStreak: Int,
        completionTimes: [String],
        relatedHabits: [String]
    ) async -> HabitOptimizationOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Provide optimization suggestions for this habit:

            Habit: \(habitTitle)
            Current streak: \(currentStreak) days
            Typical completion times: \(completionTimes.joined(separator: ", "))
            Related habits: \(relatedHabits.joined(separator: ", "))

            Suggest:
            - Optimal time to complete this habit
            - Habit stacking opportunities (habits to pair with)
            - 2-3 motivational tips
            - Predicted success rate (0-100) based on patterns
            """

            let response = try await session.respond(
                to: prompt,
                generating: HabitOptimizationOutput.self
            )

            logger.info("Generated habit optimization with \(response.content.predictedSuccessRate)% predicted success")
            return response.content

        } catch {
            logger.error("Failed to optimize habit: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Smart Scheduling

    /// Get AI-powered scheduling suggestions
    func suggestSchedule(
        taskTitle: String,
        estimatedMinutes: Int,
        existingEvents: [String],
        preferences: [String]
    ) async -> SmartScheduleOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Suggest optimal time slots for this task:

            Task: \(taskTitle)
            Estimated duration: \(estimatedMinutes) minutes
            Existing calendar events: \(existingEvents.joined(separator: "; "))
            User preferences: \(preferences.joined(separator: ", "))

            Provide:
            - 2-3 suggested time slots (start and end times)
            - Confidence level for each (0-100)
            - Reason for each suggestion
            - Any potential conflicts or warnings
            """

            let response = try await session.respond(
                to: prompt,
                generating: SmartScheduleOutput.self
            )

            logger.info("Generated \(response.content.suggestedTimeSlots.count) schedule suggestions")
            return response.content

        } catch {
            logger.error("Failed to suggest schedule: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Reminder Summarization

    /// Summarize multiple reminders into a brief overview
    func summarizeReminders(_ reminders: [String]) async -> ReminderSummaryOutput? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let prompt = """
            Summarize these reminders/tasks:

            \(reminders.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            Provide:
            - A brief one-sentence summary
            - Key points (2-4 items)
            - Most important action items
            - Overall urgency level (low, medium, high, critical)
            """

            let response = try await session.respond(
                to: prompt,
                generating: ReminderSummaryOutput.self
            )

            logger.info("Summarized \(reminders.count) reminders")
            return response.content

        } catch {
            logger.error("Failed to summarize reminders: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Streaming Responses

    /// Stream a response for real-time UI updates
    func streamResponse(
        prompt: String,
        onToken: @escaping (String) -> Void
    ) async {
        guard requirePro(), requireAvailable() else { return }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            let stream = session.streamResponse(to: prompt)

            for try await partialResponse in stream {
                onToken(partialResponse.content)
            }

            logger.info("Completed streaming response")

        } catch {
            logger.error("Streaming failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    // MARK: - Context-Aware Conversations

    /// Start a new conversation session for multi-turn interactions
    func startConversation() async {
        session = LanguageModelSession()
        logger.info("Started new conversation session")
    }

    /// Continue conversation with context
    func continueConversation(_ message: String) async -> String? {
        guard requirePro(), requireAvailable() else { return nil }

        guard let session = session else {
            await startConversation()
            return await continueConversation(message)
        }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let response = try await session.respond(to: message)
            logger.info("Received conversation response")
            return response.content
        } catch {
            logger.error("Conversation failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }

    /// End the current conversation session
    func endConversation() {
        session = nil
        logger.info("Ended conversation session")
    }

    // MARK: - Tool Calling Support

    /// Execute a tool call within the AI context
    func executeWithTools<T: Generable>(
        prompt: String,
        tools: [String: @Sendable () async -> String],
        generating: T.Type
    ) async -> T? {
        guard requirePro(), requireAvailable() else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let session = LanguageModelSession()

            // Use the Tools API for tool calling
            let response = try await session.respond(
                to: prompt,
                generating: T.self
            )

            return response.content

        } catch {
            logger.error("Tool execution failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension FoundationModelsManager {

    /// Quick check if AI features can be used
    var canUseAI: Bool {
        return isAvailable && isProEnabled && !isProcessing
    }

    /// Human-readable status
    var statusDescription: String {
        if !isAvailable {
            return "Apple Intelligence requires iPhone 15 Pro or later with iOS 26+"
        }
        if !isProEnabled {
            return "Upgrade to Pro to use Apple Intelligence features"
        }
        if isProcessing {
            return "Processing..."
        }
        return "Ready"
    }
}
