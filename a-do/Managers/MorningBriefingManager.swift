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
            
            // 2. Generate Content using selected AI provider
            let content = try await generateAIContent(from: data, context: context)
            
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
        let temperature: String
        let weatherIcon: String
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
        let weather = await fetchWeatherDetails()
        
        // Calculate real productivity score
        let productivityScore = await calculateProductivityScore(context: context)
        
        return UserContextData(
            name: profile?.displayName ?? "Traveler",
            level: profile?.level ?? 1,
            streak: bestHabit?.currentStreak ?? 0,
            tasksDueToday: dueTasks.count,
            tasksOverdue: overdueTasks.count,
            topPriorityTask: dueTasks.first?.title,
            weatherCondition: weather.condition,
            temperature: weather.temperature,
            weatherIcon: weather.icon,
            productivityScore: productivityScore
        )
    }
    
    // MARK: - Weather Integration (WeatherKit)
    
    private struct WeatherDetails {
        let condition: String
        let temperature: String
        let icon: String
    }
    
    private func fetchWeatherDetails() async -> WeatherDetails {
        logger.info("Starting weather detail fetch...")
        do {
            // Get user's current location
            guard let location = await LocationManager.shared.getCurrentLocation() else {
                let status = LocationManager.shared.authorizationStatus.rawValue
                logger.error("Could not get location for weather. Auth status: \(status)")
                return WeatherDetails(condition: "Clear", temperature: "--", icon: "sun.max.fill")
            }
            
            logger.info("Found location: \(location.coordinate.latitude), \(location.coordinate.longitude). Requesting WeatherKit data...")
            
            // Use WeatherKit to fetch current weather
            let weatherService = WeatherService.shared
            
            do {
                let weather = try await weatherService.weather(for: location)
                
                // Get current condition description
                let condition = weather.currentWeather.condition
                let temperature = weather.currentWeather.temperature
                
                // Get user's preferred temperature unit (from UserDefaults for quick access)
                let preferredUnit = UserDefaults.standard.string(forKey: "temperatureUnit") ?? "fahrenheit"
                
                // Convert and format temperature as a rounded whole number
                let tempValue: Double
                let unitSymbol: String
                
                if preferredUnit == "celsius" {
                    // Convert to Celsius if needed
                    tempValue = temperature.converted(to: .celsius).value
                    unitSymbol = "°C"
                } else {
                    // Fahrenheit (default)
                    tempValue = temperature.converted(to: .fahrenheit).value
                    unitSymbol = "°F"
                }
                
                let roundedTemp = Int(tempValue.rounded())
                let tempFormatted = "\(roundedTemp)\(unitSymbol)"
                
                // Map condition to SF Symbol
                let iconName = mapWeatherConditionToIcon(condition)
                
                logger.info("Successfully fetched weather: \(condition.description), \(tempFormatted)")
                
                return WeatherDetails(
                    condition: condition.description,
                    temperature: tempFormatted,
                    icon: iconName
                )
            } catch {
                logger.error("WeatherKit service failed: \(error.localizedDescription)")
                // Re-throw to be caught by outer block for unified fallback logic
                throw error
            }
            
        } catch {
            logger.error("Top-level weather fetch error: \(error.localizedDescription)")
            return WeatherDetails(condition: "Clear", temperature: "--", icon: "sun.max.fill")
        }
    }
    
    private func mapWeatherConditionToIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return "sun.max.fill"
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return "cloud.fill"
        case .rain, .heavyRain, .drizzle, .sunShowers:
            return "cloud.rain.fill"
        case .snow, .heavySnow, .flurries, .sunFlurries:
            return "cloud.snow.fill"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms:
            return "cloud.bolt.rain.fill"
        case .windy, .breezy:
            return "wind"
        case .foggy, .haze, .smoky:
            return "cloud.fog.fill"
        default:
            return "sun.max.fill"
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

    private func generateAIContent(from data: UserContextData, context _: ModelContext) async throws -> BriefingContent {
        let userId = SecurityUtils.getCurrentUserID()
        let provider = AIManager.shared.provider(for: .morningBriefing, userId: userId)

        if provider == .googleGemini3 {
            do {
                return try await generateGeminiContent(from: data)
            } catch {
                logger.error("Gemini briefing generation failed: \(error.localizedDescription). Falling back to Apple on-device model.")
            }
        }

        return try await generateFoundationModelContent(from: data)
    }

    private func generateFoundationModelContent(from data: UserContextData) async throws -> BriefingContent {
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

        Structure the response as JSON with keys: 'greeting', 'focus', 'motivation', 'weatherIcon', 'temperature', 'condition'.
        - greeting: Warm welcome. Mention THEIR NAME. IMPORTANT: Specifically mention that it's \(data.weatherCondition) and \(data.temperature) outside.
        - focus: Summary of tasks (mention count and top priority).
        - motivation: Encouragement based on level/streak.
        - weatherIcon: Use exactly this string: "\(data.weatherIcon)".
        - temperature: Use exactly this string: "\(data.temperature)".
        - condition: Use exactly this string: "\(data.weatherCondition)".
        
        Keep it concise and punchy.
        """

        // Use guided generation to get structured output
        let response = try await session.respond(to: prompt, generating: BriefingContent.self)

        return response.content
    }

    private func generateGeminiContent(from data: UserContextData) async throws -> BriefingContent {
        let dataJSON = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
        You are a helpful, encouraging assistant for a productivity app.
        Generate a morning briefing from this data:
        \(dataJSON)

        Return ONLY valid JSON with keys:
        - greeting (String): Include the user's name and explicitly mention weather condition and temperature.
        - focus (String): Mention tasks due today and top priority task.
        - motivation (String): Encouraging line tied to level/streak.
        - weatherIcon (String): Use this exact icon: "\(data.weatherIcon)".
        - temperature (String): Use this exact value: "\(data.temperature)".
        - condition (String): Use this exact value: "\(data.weatherCondition)".
        """

        return try await GeminiManager.shared.generateStructuredResponse(
            prompt: prompt,
            as: BriefingContent.self,
            temperature: 0.2,
            maxOutputTokens: 512
        )
    }
    
    private func generateFallbackContent(from data: UserContextData?) -> BriefingContent {
        guard let data = data else {
            return BriefingContent(
                greeting: "Good Morning!",
                focus: "Let's check your tasks.",
                motivation: "You've got this!",
                weatherIcon: "sun.max.fill",
                temperature: "--",
                condition: "Clear"
            )
        }
        
        return BriefingContent(
            greeting: "Good Morning, \(data.name).",
            focus: "You have \(data.tasksDueToday) items due today. Top priority: \(data.topPriorityTask ?? "Clear input").",
            motivation: "Keep up the momentum!",
            weatherIcon: data.weatherIcon,
            temperature: data.temperature,
            condition: data.weatherCondition
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
    /// SF Symbol name for the weather
    let weatherIcon: String
    /// Formatted temperature string
    let temperature: String
    /// Current weather condition description
    let condition: String
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
