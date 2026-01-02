//
//  MorningBriefingManager.swift
//  a-do
//
//  Created for iOS 26+ Morning Briefing Feature
//

import Foundation
import SwiftData
import Observation
import os
import FoundationModels
import WeatherKit
import CoreLocation

@MainActor
@Observable
final class MorningBriefingManager {
    static let shared = MorningBriefingManager()
    
    private let logger = Logger(subsystem: "a-do", category: "MorningBriefing")
    
    // State
    var isGenerating: Bool = false
    var currentBriefing: BriefingContent?
    var lastGeneratedDate: Date? {
        get { UserDefaults.standard.object(forKey: "LastBriefingDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "LastBriefingDate") }
    }
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }
    
    // MARK: - Generation
    
    func generateBriefing(context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("Morning Briefing is a Pro feature")
            return
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // 1. Aggregate Data
            let data = try await aggregateUserData(context: context)
            
            // 2. Generate Content using FoundationModels
            let content = try await generateAIContent(from: data)
            
            self.currentBriefing = content
            self.lastGeneratedDate = Date()
            
            logger.info("Successfully generated morning briefing")
            
        } catch {
            logger.error("Failed to generate briefing: \(error.localizedDescription)")
            // Fallback to template if AI fails
            self.currentBriefing = generateFallbackContent(from: try? await aggregateUserData(context: context))
        }
    }
    
    func markBriefingAsRead() {
        // Logic to dismiss or mark as read
        currentBriefing = nil
    }
    
    // MARK: - Data Aggregation
    
    private struct UserContextData: Codable {
        let name: String
        let level: Int
        let streak: Int
        let tasksDueToday: Int
        let tasksOverdue: Int
        let topPriorityTask: String?
        let weatherCondition: String
        let productivityScore: Int?
    }
    
    private func aggregateUserData(context: ModelContext) async throws -> UserContextData {
        // Fetch User Profile
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profile = try? context.fetch(profileDescriptor).first
        
        // Fetch Reminders
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let dueDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.dueDate != nil && $0.dueDate! >= today && $0.dueDate! < tomorrow && !$0.isCompleted },
            sortBy: [SortDescriptor(\.priorityRaw, order: .reverse)]
        )
        let dueTasks = (try? context.fetch(dueDescriptor)) ?? []
        
        let overdueDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.dueDate != nil && $0.dueDate! < today && !$0.isCompleted }
        )
        let overdueTasks = (try? context.fetch(overdueDescriptor)) ?? []
        
        // Fetch Streak (assuming from Profile or Habit)
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        let bestHabit = habits.max(by: { $0.currentStreak < $1.currentStreak })
        
        // Get real weather data
        let weatherCondition = await fetchCurrentWeather()
        
        // Calculate real productivity score
        let productivityScore = await calculateProductivityScore(context: context)
        
        return UserContextData(
            name: profile?.displayName ?? "Traveler",
            level: profile?.level ?? 1,
            streak: bestHabit?.currentStreak ?? 0,
            tasksDueToday: dueTasks.count,
            tasksOverdue: overdueTasks.count,
            topPriorityTask: dueTasks.first?.title,
            weatherCondition: weatherCondition,
            productivityScore: productivityScore
        )
    }
    
    // MARK: - Weather Integration (WeatherKit)
    
    private func fetchCurrentWeather() async -> String {
        do {
            // Get user's current location
            guard let location = await LocationManager.shared.getCurrentLocation() else {
                logger.warning("Could not get location for weather")
                return "Clear"
            }
            
            // Use WeatherKit to fetch current weather
            let weatherService = WeatherService.shared
            let weather = try await weatherService.weather(for: location)
            
            // Get current condition description
            let condition = weather.currentWeather.condition
            let temperature = weather.currentWeather.temperature
            
            // Format a human-friendly weather string
            let tempFormatted = temperature.formatted(.measurement(width: .narrow))
            return "\(condition.description), \(tempFormatted)"
            
        } catch {
            logger.error("Failed to fetch weather: \(error.localizedDescription)")
            return "Clear"
        }
    }
    
    // MARK: - Productivity Score Calculation
    
    private func calculateProductivityScore(context: ModelContext) async -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        // Fetch completed tasks in the last 7 days
        let completedDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.isCompleted && $0.completedAt != nil && $0.completedAt! >= sevenDaysAgo }
        )
        let completedTasks = (try? context.fetch(completedDescriptor)) ?? []
        
        // Fetch focus sessions in the last 7 days
        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= sevenDaysAgo }
        )
        let focusSessions = (try? context.fetch(sessionDescriptor)) ?? []
        
        // Fetch active habits
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        
        // Calculate component scores (each weighted)
        
        // Task completion score (0-40 points)
        // Based on tasks completed vs overdue
        let overdueDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.dueDate != nil && $0.dueDate! < today && !$0.isCompleted }
        )
        let overdueTasks = (try? context.fetch(overdueDescriptor)) ?? []
        let taskScore: Int
        if completedTasks.isEmpty && overdueTasks.isEmpty {
            taskScore = 20 // Neutral if no data
        } else {
            let completionRatio = Double(completedTasks.count) / Double(max(1, completedTasks.count + overdueTasks.count))
            taskScore = Int(completionRatio * 40)
        }
        
        // Focus session score (0-30 points)
        // Based on average productivity from focus sessions
        let focusScore: Int
        if focusSessions.isEmpty {
            focusScore = 15 // Neutral if no data
        } else {
            let avgSessionProductivity = focusSessions.reduce(0.0) { $0 + $1.productivityScore } / Double(focusSessions.count)
            focusScore = Int((avgSessionProductivity / 100.0) * 30)
        }
        
        // Habit streak score (0-30 points)
        // Based on current streaks across all habits
        let habitScore: Int
        if habits.isEmpty {
            habitScore = 15 // Neutral if no data
        } else {
            let totalMaxStreak = habits.count * 7 // Max 7-day streak per habit
            let actualStreaks = habits.reduce(0) { $0 + min(7, $1.currentStreak) }
            habitScore = Int((Double(actualStreaks) / Double(max(1, totalMaxStreak))) * 30)
        }
        
        // Total score (0-100)
        let totalScore = min(100, max(0, taskScore + focusScore + habitScore))
        
        logger.info("Productivity score calculated: \(totalScore) (tasks: \(taskScore), focus: \(focusScore), habits: \(habitScore))")
        
        return totalScore
    }
    
    // MARK: - AI Generation (FoundationModels)

    private func generateAIContent(from data: UserContextData) async throws -> BriefingContent {
        // Check if Foundation Models is available
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw MorningBriefingAIError.modelNotAvailable
        }

        // Create a session for the AI interaction
        let session = LanguageModelSession()

        let dataJSON = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
        You are a helpful, encouraging assistant for a productivity app.
        Generate a 3-part morning briefing for the user based on this data:
        \(dataJSON)

        Structure the response as JSON with keys: 'greeting', 'focus', 'motivation'.
        - greeting: Warm welcome, mention name and weather.
        - focus: Summary of tasks (mention count and top priority).
        - motivation: Encouragement based on level/streak.
        Keep it concise and punchy.
        """

        // Use guided generation to get structured output
        let response = try await session.respond(to: prompt, generating: BriefingContent.self)

        return response.content
    }
    
    private func generateFallbackContent(from data: UserContextData?) -> BriefingContent {
        guard let data = data else {
            return BriefingContent(
                greeting: "Good Morning!",
                focus: "Let's check your tasks.",
                motivation: "You've got this!"
            )
        }
        
        return BriefingContent(
            greeting: "Good Morning, \(data.name).",
            focus: "You have \(data.tasksDueToday) items due today. Top priority: \(data.topPriorityTask ?? "Clear input").",
            motivation: "Keep up the momentum!"
        )
    }
}

// MARK: - Models

@Generable
struct BriefingContent: Codable, Equatable, Sendable {
    /// Warm welcome greeting mentioning name and weather
    let greeting: String
    /// Summary of tasks due today and top priority
    let focus: String
    /// Encouragement based on level and streak
    let motivation: String
}

private enum MorningBriefingAIError: Error {
    case parsingFailed
    case modelNotAvailable
}

extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
