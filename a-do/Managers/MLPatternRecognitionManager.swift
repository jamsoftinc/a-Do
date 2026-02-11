//
//  MLPatternRecognitionManager.swift
//  a-do
//
//  Enhanced ML pattern recognition for behavioral analysis and predictions
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class MLPatternRecognitionManager {
    static let shared = MLPatternRecognitionManager()
    
    private let logger = Logger(subsystem: "a-do", category: "MLPatternRecognition")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    private init() {}
    
    // MARK: - Pattern Analysis
    
    func analyzeUserBehaviorPatterns(context: ModelContext) async -> UserBehaviorAnalysis {
        guard isProEnabled else {
            logger.warning("ML pattern recognition is a Pro feature")
            return UserBehaviorAnalysis(
                taskCompletionPatterns: TaskCompletionPatterns(
                    optimalCompletionHours: [],
                    optimalCompletionDays: [],
                    completionRateByPriority: [:],
                    procrastinationScore: 0,
                    averageCompletionDelay: 0
                ),
                timeUsagePatterns: TimeUsagePatterns(
                    categoryDistribution: [:],
                    peakProductivityHours: [],
                    averageSessionLength: 0,
                    optimalSessionLength: 0,
                    consistencyScore: 0
                ),
                productivityPatterns: ProductivityPatterns(
                    dailyScoreTrends: [:],
                    focusTypeEffectiveness: [:],
                    interruptionPatterns: InterruptionPatterns(commonTypes: [], peakTimes: [], averageRecoveryTime: 0),
                    optimalWorkingHours: [],
                    burnoutRiskScore: 0
                ),
                habitPatterns: HabitPatterns(
                    successRates: [:],
                    streakPatterns: [],
                    habitClusters: [],
                    optimalFormationTime: 0
                ),
                contextualPatterns: ContextualPatterns(
                    timeOfDayEffects: [:],
                    dayOfWeekEffects: [:],
                    seasonalEffects: [:]
                ),
                overallScore: 0
            )
        }

        logger.info("Starting user behavior pattern analysis")

        // Collect comprehensive data
        let behaviorData = await collectBehaviorData(context: context)
        
        // Analyze patterns using different models
        let taskCompletionPatterns = await analyzeTaskCompletionPatterns(behaviorData.taskData)
        let timeUsagePatterns = await analyzeTimeUsagePatterns(behaviorData.timeData)
        let productivityPatterns = await analyzeProductivityPatterns(behaviorData.productivityData)
        let habitPatterns = await analyzeHabitPatterns(behaviorData.habitData)
        let contextualPatterns = await analyzeContextualPatterns(behaviorData.contextualData)
        
        return UserBehaviorAnalysis(
            taskCompletionPatterns: taskCompletionPatterns,
            timeUsagePatterns: timeUsagePatterns,
            productivityPatterns: productivityPatterns,
            habitPatterns: habitPatterns,
            contextualPatterns: contextualPatterns,
            overallScore: calculateOverallBehaviorScore(
                taskCompletionPatterns,
                timeUsagePatterns,
                productivityPatterns,
                habitPatterns,
                contextualPatterns
            )
        )
    }
    
    func predictOptimalScheduling(for reminder: Reminder, context: ModelContext) async -> SchedulingPrediction {
        guard isProEnabled else {
            logger.warning("ML scheduling prediction is a Pro feature")
            return SchedulingPrediction(optimalTimes: [], confidence: 0, reasoningFactors: [])
        }

        logger.info("Predicting optimal scheduling for reminder: \(reminder.title)")

        // Analyze historical patterns
        let userPatterns = await getUserSchedulingPatterns(context: context)
        let similarTasks = await findSimilarTasks(reminder: reminder, context: context)
        let contextualFactors = await getContextualFactors(for: reminder, context: context)
        
        // Calculate optimal times based on multiple factors
        let timeRecommendations = await calculateOptimalTimes(
            userPatterns: userPatterns,
            similarTasks: similarTasks,
            contextualFactors: contextualFactors,
            reminder: reminder
        )
        
        return SchedulingPrediction(
            optimalTimes: timeRecommendations,
            confidence: calculatePredictionConfidence(timeRecommendations),
            reasoningFactors: generateReasoningFactors(userPatterns, similarTasks, contextualFactors)
        )
    }
    
    func predictHabitSuccess(habit: Habit, context: ModelContext) async -> HabitSuccessPrediction {
        guard isProEnabled else {
            logger.warning("ML habit prediction is a Pro feature")
            return HabitSuccessPrediction(successProbability: 0, riskFactors: [], optimizationSuggestions: [], confidence: 0)
        }

        logger.info("Predicting habit success for: \(habit.title)")

        let habitHistory = await getHabitHistory(habit: habit, context: context)
        let userHabitPatterns = await getUserHabitPatterns(context: context)
        let environmentalFactors = await getEnvironmentalFactors(for: habit, context: context)
        
        let successProbability = await calculateHabitSuccessProbability(
            habit: habit,
            history: habitHistory,
            patterns: userHabitPatterns,
            environment: environmentalFactors
        )
        
        let riskFactors = identifyHabitRiskFactors(
            habit: habit,
            history: habitHistory,
            patterns: userHabitPatterns
        )
        
        let optimizationSuggestions = generateHabitOptimizationSuggestions(
            habit: habit,
            successProbability: successProbability,
            riskFactors: riskFactors
        )
        
        return HabitSuccessPrediction(
            successProbability: successProbability,
            riskFactors: riskFactors,
            optimizationSuggestions: optimizationSuggestions,
            confidence: calculateHabitPredictionConfidence(habitHistory, userHabitPatterns)
        )
    }
    
    func detectProductivityAnomalies(context: ModelContext) async -> [ProductivityAnomaly] {
        guard isProEnabled else {
            logger.warning("ML anomaly detection is a Pro feature")
            return []
        }

        logger.info("Detecting productivity anomalies")

        let recentData = await getRecentProductivityData(context: context, days: 30)
        let historicalBaseline = await calculateProductivityBaseline(context: context)
        
        var anomalies: [ProductivityAnomaly] = []
        
        // Detect different types of anomalies
        anomalies.append(contentsOf: detectTaskCompletionAnomalies(recentData, baseline: historicalBaseline))
        anomalies.append(contentsOf: detectTimeUsageAnomalies(recentData, baseline: historicalBaseline))
        anomalies.append(contentsOf: detectFocusAnomalies(recentData, baseline: historicalBaseline))
        anomalies.append(contentsOf: detectHabitAnomalies(recentData, baseline: historicalBaseline))
        
        // Sort by severity and confidence
        return anomalies.sorted { $0.severity > $1.severity }
    }
    
    func generatePersonalizedInsights(context: ModelContext) async -> [PersonalizedInsight] {
        guard isProEnabled else {
            logger.warning("ML personalized insights is a Pro feature")
            return []
        }

        logger.info("Generating personalized insights")

        let behaviorAnalysis = await analyzeUserBehaviorPatterns(context: context)
        let productivityTrends = await analyzeProductivityTrends(context: context)
        let habitInsights = await analyzeHabitInsights(context: context)
        
        var insights: [PersonalizedInsight] = []
        
        // Generate different types of insights
        insights.append(contentsOf: generateProductivityInsights(from: behaviorAnalysis, trends: productivityTrends))
        insights.append(contentsOf: generateHabitInsights(from: habitInsights))
        insights.append(contentsOf: generateTimeManagementInsights(from: behaviorAnalysis))
        insights.append(contentsOf: generateWellnessInsights(from: behaviorAnalysis))
        
        // Filter and rank insights by relevance and actionability
        return insights
            .filter { $0.confidence > 0.6 }
            .sorted { $0.importance > $1.importance }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Data Collection
    
    private func collectBehaviorData(context: ModelContext) async -> BehaviorDataCollection {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: endDate)!
        
        // Fetch comprehensive data
        let reminders = await fetchReminders(from: startDate, to: endDate, context: context)
        let timeEntries = await fetchTimeEntries(from: startDate, to: endDate, context: context)
        let focusSessions = await fetchFocusSessions(from: startDate, to: endDate, context: context)
        let habits = await fetchHabits(context: context)
        
        return BehaviorDataCollection(
            taskData: TaskData(reminders: reminders),
            timeData: TimeData(entries: timeEntries),
            productivityData: ProductivityData(sessions: focusSessions),
            habitData: HabitData(habits: habits),
            contextualData: ContextualData(
                timeOfDay: extractTimeOfDayPatterns(reminders, timeEntries, focusSessions),
                dayOfWeek: extractDayOfWeekPatterns(reminders, timeEntries, focusSessions),
                seasonality: extractSeasonalityPatterns(reminders, timeEntries, focusSessions)
            )
        )
    }
    
    // MARK: - Pattern Analysis Methods
    
    private func analyzeTaskCompletionPatterns(_ taskData: TaskData) async -> TaskCompletionPatterns {
        let completionTimes = taskData.reminders.compactMap { reminder -> (reminder: Reminder, completionTime: Date)? in
            guard let completedAt = reminder.completedAt else { return nil }
            return (reminder, completedAt)
        }
        
        // Analyze completion time patterns
        let hourlyDistribution = Dictionary(grouping: completionTimes) { (_, completionTime) in
            Calendar.current.component(.hour, from: completionTime)
        }
        
        let dailyDistribution = Dictionary(grouping: completionTimes) { (_, completionTime) in
            Calendar.current.component(.weekday, from: completionTime)
        }
        
        // Calculate completion rate by priority
        let completionRateByPriority = Dictionary(grouping: taskData.reminders, by: \.priority)
            .mapValues { reminders in
                let completed = reminders.filter(\.isCompleted).count
                return Double(completed) / Double(reminders.count)
            }
        
        // Identify procrastination patterns
        let procrastinationScore = calculateProcrastinationScore(taskData.reminders)
        
        return TaskCompletionPatterns(
            optimalCompletionHours: findOptimalHours(from: hourlyDistribution),
            optimalCompletionDays: findOptimalDays(from: dailyDistribution),
            completionRateByPriority: completionRateByPriority,
            procrastinationScore: procrastinationScore,
            averageCompletionDelay: calculateAverageCompletionDelay(taskData.reminders)
        )
    }
    
    private func analyzeTimeUsagePatterns(_ timeData: TimeData) async -> TimeUsagePatterns {
        let entries = timeData.entries
        
        // Category time distribution
        let categoryDistribution = Dictionary(grouping: entries, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.actualDuration } }
        
        // Peak productivity hours
        let hourlyProductivity = Dictionary(grouping: entries) { entry in
            Calendar.current.component(.hour, from: entry.startTime)
        }.mapValues { entries in
            entries.reduce(0) { $0 + $1.actualDuration } / Double(entries.count)
        }
        
        // Session length patterns
        let sessionLengths = entries.map(\.actualDuration)
        let averageSessionLength = sessionLengths.isEmpty ? 0.0 : sessionLengths.reduce(0, +) / Double(sessionLengths.count)
        let optimalSessionLength = calculateOptimalSessionLength(sessionLengths)
        
        return TimeUsagePatterns(
            categoryDistribution: categoryDistribution,
            peakProductivityHours: findPeakHours(from: hourlyProductivity),
            averageSessionLength: averageSessionLength,
            optimalSessionLength: optimalSessionLength,
            consistencyScore: calculateTimeConsistencyScore(entries)
        )
    }
    
    private func analyzeProductivityPatterns(_ productivityData: ProductivityData) async -> ProductivityPatterns {
        let sessions = productivityData.sessions
        
        // Productivity score trends
        let scoresByDay = Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }.mapValues { sessions in
            sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        }
        
        // Focus type effectiveness
        let effectivenessByType = Dictionary(grouping: sessions, by: \.focusType)
            .mapValues { sessions in
                sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
            }
        
        // Interruption patterns
        let interruptionPatterns = analyzeInterruptionPatterns(sessions)
        
        return ProductivityPatterns(
            dailyScoreTrends: scoresByDay,
            focusTypeEffectiveness: effectivenessByType,
            interruptionPatterns: interruptionPatterns,
            optimalWorkingHours: findOptimalWorkingHours(sessions),
            burnoutRiskScore: calculateBurnoutRisk(sessions)
        )
    }
    
    private func analyzeHabitPatterns(_ habitData: HabitData) async -> HabitPatterns {
        let habits = habitData.habits
        
        // Success rate patterns
        let successRates = habits.compactMap { habit -> (habit: Habit, rate: Double)? in
            guard let entries = habit.entries, !entries.isEmpty else { return nil }
            let rate = Double(entries.count) / Double(max(1, habit.daysSinceCreation))
            return (habit, rate)
        }
        
        // Streak analysis
        let streakPatterns = habits.map { habit in
            StreakPattern(
                habit: habit,
                currentStreak: habit.currentStreak,
                longestStreak: habit.longestStreak,
                averageStreakLength: calculateAverageStreakLength(habit)
            )
        }
        
        // Habit clustering (similar habits)
        let habitClusters = clusterSimilarHabits(habits)
        
        return HabitPatterns(
            successRates: Dictionary(uniqueKeysWithValues: successRates.map { ($0.habit.title, $0.rate) }),
            streakPatterns: streakPatterns,
            habitClusters: habitClusters,
            optimalFormationTime: calculateOptimalHabitFormationTime(habits)
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallBehaviorScore(
        _ taskPatterns: TaskCompletionPatterns,
        _ timePatterns: TimeUsagePatterns,
        _ productivityPatterns: ProductivityPatterns,
        _ habitPatterns: HabitPatterns,
        _ contextualPatterns: ContextualPatterns
    ) -> Double {
        let taskScore = 1.0 - taskPatterns.procrastinationScore
        let timeScore = timePatterns.consistencyScore
        let productivityScore = 1.0 - min(1.0, productivityPatterns.burnoutRiskScore)
        let values: [Double] = Array(habitPatterns.successRates.values)
        let habitScore = values.isEmpty ? 0.0 : values.reduce(0.0, +) / Double(values.count)
        
        return (taskScore + timeScore + productivityScore + habitScore) / 4.0
    }
    
    private func calculateProcrastinationScore(_ reminders: [Reminder]) -> Double {
        let remindersWithDueDates = reminders.filter { $0.dueDate != nil && $0.completedAt != nil }
        guard !remindersWithDueDates.isEmpty else { return 0 }
        
        let delays = remindersWithDueDates.compactMap { reminder -> TimeInterval? in
            guard let dueDate = reminder.dueDate,
                  let completedAt = reminder.completedAt else { return nil }
            return max(0, completedAt.timeIntervalSince(dueDate))
        }
        
        let averageDelay = delays.reduce(0, +) / Double(delays.count)
        return min(1.0, averageDelay / (24 * 3600)) // Normalize to days
    }
    
    private func calculateTimeConsistencyScore(_ entries: [TimeEntry]) -> Double {
        // Calculate consistency based on regular patterns in time usage
        let dailyTotals = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.startTime)
        }.mapValues { $0.reduce(0) { $0 + $1.actualDuration } }
        
        let values = Array(dailyTotals.values)
        guard values.count > 1 else { return 1.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        // Lower standard deviation = higher consistency
        let coefficientOfVariation = mean > 0 ? standardDeviation / mean : 0
        return max(0, 1.0 - coefficientOfVariation)
    }
    
    private func findOptimalHours(from distribution: [Int: [(Reminder, Date)]]) -> [Int] {
        distribution
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map(\.key)
    }
    
    private func findOptimalDays(from distribution: [Int: [(Reminder, Date)]]) -> [Int] {
        distribution
            .sorted { $0.value.count > $1.value.count }
            .prefix(2)
            .map(\.key)
    }
    
    // MARK: - Data Fetching
    
    private func fetchReminders(from startDate: Date, to endDate: Date, context: ModelContext) async -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                (reminder.createdAt >= startDate && reminder.createdAt <= endDate) ||
                (reminder.completedAt != nil && reminder.completedAt! >= startDate && reminder.completedAt! <= endDate)
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchTimeEntries(from startDate: Date, to endDate: Date, context: ModelContext) async -> [TimeEntry] {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= startDate && entry.startTime <= endDate
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchFocusSessions(from startDate: Date, to endDate: Date, context: ModelContext) async -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchHabits(context: ModelContext) async -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Data Structures

struct BehaviorDataCollection {
    let taskData: TaskData
    let timeData: TimeData
    let productivityData: ProductivityData
    let habitData: HabitData
    let contextualData: ContextualData
}

struct TaskData {
    let reminders: [Reminder]
}

struct TimeData {
    let entries: [TimeEntry]
}

struct ProductivityData {
    let sessions: [FocusSession]
}

struct HabitData {
    let habits: [Habit]
}

struct ContextualData {
    let timeOfDay: [Int: Double]
    let dayOfWeek: [Int: Double]
    let seasonality: [String: Double]
}

// MARK: - Analysis Results

struct UserBehaviorAnalysis {
    let taskCompletionPatterns: TaskCompletionPatterns
    let timeUsagePatterns: TimeUsagePatterns
    let productivityPatterns: ProductivityPatterns
    let habitPatterns: HabitPatterns
    let contextualPatterns: ContextualPatterns
    let overallScore: Double
}

struct TaskCompletionPatterns {
    let optimalCompletionHours: [Int]
    let optimalCompletionDays: [Int]
    let completionRateByPriority: [Priority: Double]
    let procrastinationScore: Double
    let averageCompletionDelay: TimeInterval
}

struct TimeUsagePatterns {
    let categoryDistribution: [String: TimeInterval]
    let peakProductivityHours: [Int]
    let averageSessionLength: TimeInterval
    let optimalSessionLength: TimeInterval
    let consistencyScore: Double
}

struct ProductivityPatterns {
    let dailyScoreTrends: [Date: Double]
    let focusTypeEffectiveness: [FocusType: Double]
    let interruptionPatterns: InterruptionPatterns
    let optimalWorkingHours: [Int]
    let burnoutRiskScore: Double
}

struct HabitPatterns {
    let successRates: [String: Double]
    let streakPatterns: [StreakPattern]
    let habitClusters: [[Habit]]
    let optimalFormationTime: TimeInterval
}

struct ContextualPatterns {
    let timeOfDayEffects: [Int: Double]
    let dayOfWeekEffects: [Int: Double]
    let seasonalEffects: [String: Double]
}

struct SchedulingPrediction {
    let optimalTimes: [OptimalTime]
    let confidence: Double
    let reasoningFactors: [String]
}

struct OptimalTime {
    let time: Date
    let confidence: Double
    let reasoning: String
}

struct HabitSuccessPrediction {
    let successProbability: Double
    let riskFactors: [RiskFactor]
    let optimizationSuggestions: [OptimizationSuggestion]
    let confidence: Double
}

struct RiskFactor {
    let type: RiskFactorType
    let severity: Double
    let description: String
}

enum RiskFactorType {
    case timeConflict
    case lowMotivation
    case environmentalBarrier
    case habitStackingIssue
}

struct OptimizationSuggestion {
    let type: OptimizationType
    let suggestion: String
    let expectedImpact: Double
}

enum OptimizationType {
    case timing
    case environment
    case motivation
    case habitStacking
}

struct ProductivityAnomaly {
    let type: AnomalyType
    let severity: Double
    let description: String
    let detectedAt: Date
    let suggestedActions: [String]
}

enum AnomalyType {
    case productivityDrop
    case unusualTaskPattern
    case focusDeterioration
    case habitDisruption
}

struct PersonalizedInsight {
    let title: String
    let description: String
    let category: InsightCategory
    let confidence: Double
    let importance: Double
    let actionableSteps: [String]
}

enum InsightCategory {
    case productivity
    case timeManagement
    case habitFormation
    case wellness
    case focus
}

struct StreakPattern {
    let habit: Habit
    let currentStreak: Int
    let longestStreak: Int
    let averageStreakLength: Double
}

struct InterruptionPatterns {
    let commonTypes: [InterruptionReason]
    let peakTimes: [Int]
    let averageRecoveryTime: TimeInterval
}

extension MLPatternRecognitionManager {
    private func extractTimeOfDayPatterns(_ reminders: [Reminder], _ timeEntries: [TimeEntry], _ sessions: [FocusSession]) -> [Int: Double] {
        let calendar = Calendar.current
        var weightedCounts: [Int: Double] = [:]
        
        for reminder in reminders {
            let referenceDate = reminder.completedAt ?? reminder.dueDate ?? reminder.createdAt
            let hour = calendar.component(.hour, from: referenceDate)
            weightedCounts[hour, default: 0] += reminder.isCompleted ? 1.2 : 0.5
        }
        
        for entry in timeEntries {
            let hour = calendar.component(.hour, from: entry.startTime)
            let hoursSpent = max(0.1, entry.actualDuration / 3600)
            weightedCounts[hour, default: 0] += min(hoursSpent, 3.0)
        }
        
        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            let sessionWeight = max(0.2, session.productivityScore / 100.0)
            weightedCounts[hour, default: 0] += sessionWeight
        }
        
        return normalizeDistribution(weightedCounts)
    }
    
    private func extractDayOfWeekPatterns(_ reminders: [Reminder], _ timeEntries: [TimeEntry], _ sessions: [FocusSession]) -> [Int: Double] {
        let calendar = Calendar.current
        var weightedCounts: [Int: Double] = [:]
        
        for reminder in reminders {
            let referenceDate = reminder.completedAt ?? reminder.dueDate ?? reminder.createdAt
            let weekday = calendar.component(.weekday, from: referenceDate)
            weightedCounts[weekday, default: 0] += reminder.isCompleted ? 1.2 : 0.5
        }
        
        for entry in timeEntries {
            let weekday = calendar.component(.weekday, from: entry.startTime)
            weightedCounts[weekday, default: 0] += max(0.1, entry.actualDuration / 3600)
        }
        
        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.startTime)
            weightedCounts[weekday, default: 0] += max(0.2, session.productivityScore / 100.0)
        }
        
        return normalizeDistribution(weightedCounts)
    }
    
    private func extractSeasonalityPatterns(_ reminders: [Reminder], _ timeEntries: [TimeEntry], _ sessions: [FocusSession]) -> [String: Double] {
        let calendar = Calendar.current
        var seasonalCounts: [String: Double] = [:]
        
        func season(for date: Date) -> String {
            let month = calendar.component(.month, from: date)
            switch month {
            case 12, 1, 2: return "winter"
            case 3, 4, 5: return "spring"
            case 6, 7, 8: return "summer"
            default: return "autumn"
            }
        }
        
        for reminder in reminders {
            let key = season(for: reminder.completedAt ?? reminder.createdAt)
            seasonalCounts[key, default: 0] += reminder.isCompleted ? 1.0 : 0.4
        }
        
        for entry in timeEntries {
            let key = season(for: entry.startTime)
            seasonalCounts[key, default: 0] += max(0.1, entry.actualDuration / 3600)
        }
        
        for session in sessions {
            let key = season(for: session.startTime)
            seasonalCounts[key, default: 0] += max(0.2, session.productivityScore / 100.0)
        }
        
        return normalizeDistribution(seasonalCounts)
    }
    
    private func analyzeContextualPatterns(_ contextualData: ContextualData) async -> ContextualPatterns {
        return ContextualPatterns(
            timeOfDayEffects: contextualData.timeOfDay,
            dayOfWeekEffects: contextualData.dayOfWeek,
            seasonalEffects: contextualData.seasonality
        )
    }
    
    private func getUserSchedulingPatterns(context: ModelContext) async -> [String: Any] {
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let completed = reminders.filter { $0.isCompleted && $0.completedAt != nil }
        
        let onTimeCompletions = completed.filter { reminder in
            guard let completedAt = reminder.completedAt, let dueDate = reminder.dueDate else { return false }
            return completedAt <= dueDate
        }.count
        
        let onTimeRate = completed.isEmpty ? 0.0 : Double(onTimeCompletions) / Double(completed.count)
        let averageDelayHours = calculateAverageCompletionDelay(completed) / 3600
        
        let completionHours = Dictionary(grouping: completed) { reminder in
            Calendar.current.component(.hour, from: reminder.completedAt ?? reminder.createdAt)
        }
        .mapValues { $0.count }
        
        let optimalHours = completionHours
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map(\.key)
        
        return [
            "on_time_rate": onTimeRate,
            "average_delay_hours": averageDelayHours,
            "optimal_hours": optimalHours
        ]
    }
    
    private func findSimilarTasks(reminder: Reminder, context: ModelContext) async -> [Reminder] {
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let referenceTokens = tokenize(reminder.title + " " + (reminder.details ?? ""))
        
        return reminders
            .filter { $0.uuid != reminder.uuid }
            .filter { candidate in
                let candidateTokens = tokenize(candidate.title + " " + (candidate.details ?? ""))
                return jaccardSimilarity(referenceTokens, candidateTokens) >= 0.25
            }
    }
    
    private func getContextualFactors(for reminder: Reminder, context: ModelContext) async -> [String: Any] {
        let daysUntilDue: Double = {
            guard let dueDate = reminder.dueDate else { return 7.0 }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 7
            return Double(days)
        }()
        
        return [
            "priority_weight": Double(reminder.priority.rawValue) / 3.0,
            "urgency": max(0.0, min(1.0, 1.0 - daysUntilDue / 7.0)),
            "has_due_date": reminder.dueDate != nil,
            "has_location": reminder.locationTrigger != nil,
            "has_details": !(reminder.details?.isEmpty ?? true)
        ]
    }
    
    private func calculateOptimalTimes(
        userPatterns: [String: Any],
        similarTasks: [Reminder],
        contextualFactors: [String: Any],
        reminder: Reminder
    ) async -> [OptimalTime] {
        let calendar = Calendar.current
        let now = Date()
        
        let userHours = (userPatterns["optimal_hours"] as? [Int]) ?? []
        let similarTaskHours = similarTasks.compactMap { task -> Int? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.component(.hour, from: completedAt)
        }
        
        let combinedHours = Array(Set((userHours + similarTaskHours))).sorted()
        let fallbackHours = [9, 11, 14, 16]
        let targetHours = (combinedHours.isEmpty ? fallbackHours : combinedHours).prefix(5)
        
        let urgency = (contextualFactors["urgency"] as? Double) ?? 0.0
        let priorityWeight = (contextualFactors["priority_weight"] as? Double) ?? 0.0
        let onTimeRate = (userPatterns["on_time_rate"] as? Double) ?? 0.5
        
        var recommendations: [OptimalTime] = []
        
        for hour in targetHours {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            dateComponents.hour = hour
            dateComponents.minute = 0
            let candidateBase = calendar.date(from: dateComponents) ?? now
            let candidate = candidateBase < now ? calendar.date(byAdding: .day, value: 1, to: candidateBase) ?? candidateBase : candidateBase
            
            let confidence = max(
                0.2,
                min(1.0, (onTimeRate * 0.5) + (priorityWeight * 0.2) + ((1.0 - urgency) * 0.3))
            )
            
            recommendations.append(
                OptimalTime(
                    time: candidate,
                    confidence: confidence,
                    reasoning: "Aligned with your strong completion window around \(hour):00"
                )
            )
        }
        
        return recommendations.sorted { $0.confidence > $1.confidence }
    }
    
    private func calculatePredictionConfidence(_ recommendations: [OptimalTime]) -> Double {
        guard !recommendations.isEmpty else { return 0.0 }
        let average = recommendations.reduce(0) { $0 + $1.confidence } / Double(recommendations.count)
        return max(0.0, min(1.0, average))
    }
    
    private func generateReasoningFactors(
        _ userPatterns: [String: Any],
        _ similarTasks: [Reminder],
        _ contextualFactors: [String: Any]
    ) -> [String] {
        var reasons: [String] = []
        
        if let optimalHours = userPatterns["optimal_hours"] as? [Int], !optimalHours.isEmpty {
            reasons.append("Your most successful completion hours are \(optimalHours.map(String.init).joined(separator: ", "))")
        }
        
        if !similarTasks.isEmpty {
            reasons.append("Detected \(similarTasks.count) similar tasks with comparable timing patterns")
        }
        
        if let urgency = contextualFactors["urgency"] as? Double, urgency > 0.7 {
            reasons.append("High urgency detected due to close due date")
        }
        
        if reasons.isEmpty {
            reasons.append("Not enough historical data; using balanced scheduling defaults")
        }
        
        return reasons
    }
    
    private func getHabitHistory(habit: Habit, context: ModelContext) async -> [HabitEntry] {
        return (habit.entries ?? []).sorted { $0.date < $1.date }
    }
    
    private func getUserHabitPatterns(context: ModelContext) async -> [String: Any] {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let activeHabits = habits.filter(\.isActive)
        
        let averageCompletionRate = activeHabits.isEmpty
            ? 0.0
            : activeHabits.reduce(0) { $0 + $1.completionRate } / Double(activeHabits.count)
        
        let averageStreak = activeHabits.isEmpty
            ? 0.0
            : Double(activeHabits.reduce(0) { $0 + $1.currentStreak }) / Double(activeHabits.count)
        
        return [
            "average_completion_rate": averageCompletionRate,
            "average_streak": averageStreak,
            "active_habit_count": activeHabits.count
        ]
    }
    
    private func getEnvironmentalFactors(for habit: Habit, context: ModelContext) async -> [String: Any] {
        let entries = habit.entries ?? []
        let weekdayCompletions = entries.filter { !Calendar.current.isDateInWeekend($0.date) }.count
        let weekendCompletions = entries.count - weekdayCompletions
        
        let weekdayBias = entries.isEmpty ? 0.5 : Double(weekdayCompletions) / Double(entries.count)
        let weekendBias = entries.isEmpty ? 0.5 : Double(weekendCompletions) / Double(entries.count)
        
        return [
            "weekday_bias": weekdayBias,
            "weekend_bias": weekendBias,
            "has_time_tracking": !(habit.timeEntries?.isEmpty ?? true)
        ]
    }
    
    private func calculateHabitSuccessProbability(
        habit: Habit,
        history: [HabitEntry],
        patterns: [String: Any],
        environment: [String: Any]
    ) async -> Double {
        let baseRate = habit.completionRate
        let globalRate = (patterns["average_completion_rate"] as? Double) ?? 0.5
        let streakFactor = min(1.0, Double(habit.currentStreak) / 14.0)
        let weekdayBias = (environment["weekday_bias"] as? Double) ?? 0.5
        
        let probability = (baseRate * 0.45) + (globalRate * 0.2) + (streakFactor * 0.25) + (weekdayBias * 0.1)
        return max(0.0, min(1.0, probability))
    }
    
    private func identifyHabitRiskFactors(habit: Habit, history: [HabitEntry], patterns: [String: Any]) -> [RiskFactor] {
        var risks: [RiskFactor] = []
        
        if habit.currentStreak == 0 {
            risks.append(
                RiskFactor(
                    type: .lowMotivation,
                    severity: 0.7,
                    description: "Current streak is broken, increasing drop-off risk."
                )
            )
        }
        
        if habit.completionRate < 0.4 {
            risks.append(
                RiskFactor(
                    type: .habitStackingIssue,
                    severity: 0.6,
                    description: "Completion rate is below 40%, suggesting inconsistent routine anchoring."
                )
            )
        }
        
        if habit.targetCount > 1 {
            risks.append(
                RiskFactor(
                    type: .timeConflict,
                    severity: 0.5,
                    description: "Higher daily target may conflict with available time."
                )
            )
        }
        
        if risks.isEmpty {
            risks.append(
                RiskFactor(
                    type: .environmentalBarrier,
                    severity: 0.2,
                    description: "No significant risk factors detected."
                )
            )
        }
        
        return risks
    }
    
    private func generateHabitOptimizationSuggestions(
        habit: Habit,
        successProbability: Double,
        riskFactors: [RiskFactor]
    ) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        if successProbability < 0.5 {
            suggestions.append(
                OptimizationSuggestion(
                    type: .timing,
                    suggestion: "Reduce friction by scheduling \(habit.title) at a fixed time window each day.",
                    expectedImpact: 0.25
                )
            )
        }
        
        for risk in riskFactors {
            switch risk.type {
            case .timeConflict:
                suggestions.append(
                    OptimizationSuggestion(
                        type: .timing,
                        suggestion: "Move this habit to a lower-conflict window and set a reminder trigger.",
                        expectedImpact: 0.2
                    )
                )
            case .lowMotivation:
                suggestions.append(
                    OptimizationSuggestion(
                        type: .motivation,
                        suggestion: "Use a tiny-version fallback (2-minute rule) to restore streak momentum.",
                        expectedImpact: 0.22
                    )
                )
            case .environmentalBarrier:
                suggestions.append(
                    OptimizationSuggestion(
                        type: .environment,
                        suggestion: "Prepare your environment ahead of time so starting requires one tap or one step.",
                        expectedImpact: 0.15
                    )
                )
            case .habitStackingIssue:
                suggestions.append(
                    OptimizationSuggestion(
                        type: .habitStacking,
                        suggestion: "Attach this habit to an existing routine anchor (for example after coffee).",
                        expectedImpact: 0.2
                    )
                )
            }
        }
        
        return Array(suggestions.prefix(4))
    }
    
    private func calculateHabitPredictionConfidence(_ history: [HabitEntry], _ patterns: [String: Any]) -> Double {
        let historyScore = min(1.0, Double(history.count) / 30.0)
        let patternScore = patterns.isEmpty ? 0.3 : 0.8
        return max(0.0, min(1.0, historyScore * 0.7 + patternScore * 0.3))
    }
    
    private func getRecentProductivityData(context: ModelContext, days: Int) async -> [String: Any] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -max(1, days), to: endDate) ?? endDate
        return collectProductivityMetrics(context: context, startDate: startDate, endDate: endDate)
    }
    
    private func calculateProductivityBaseline(context: ModelContext) async -> [String: Any] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let startDate = calendar.date(byAdding: .day, value: -120, to: Date()) ?? endDate
        return collectProductivityMetrics(context: context, startDate: startDate, endDate: endDate)
    }
    
    private func detectTaskCompletionAnomalies(_ data: [String: Any], baseline: [String: Any]) -> [ProductivityAnomaly] {
        let recentCompletionRate = (data["completion_rate"] as? Double) ?? 0
        let baselineCompletionRate = (baseline["completion_rate"] as? Double) ?? 0
        
        guard baselineCompletionRate > 0 else { return [] }
        
        let delta = baselineCompletionRate - recentCompletionRate
        guard delta > 0.2 else { return [] }
        
        return [
            ProductivityAnomaly(
                type: .unusualTaskPattern,
                severity: min(1.0, delta),
                description: "Task completion rate dropped by \(Int(delta * 100))% versus your baseline.",
                detectedAt: Date(),
                suggestedActions: [
                    "Reduce in-flight tasks and prioritize top 3 outcomes daily.",
                    "Reschedule low-priority tasks to avoid overload."
                ]
            )
        ]
    }
    
    private func detectTimeUsageAnomalies(_ data: [String: Any], baseline: [String: Any]) -> [ProductivityAnomaly] {
        let recentFocusHours = (data["avg_daily_focus_hours"] as? Double) ?? 0
        let baselineFocusHours = (baseline["avg_daily_focus_hours"] as? Double) ?? 0
        
        guard baselineFocusHours > 0 else { return [] }
        let drop = (baselineFocusHours - recentFocusHours) / baselineFocusHours
        guard drop > 0.25 else { return [] }
        
        return [
            ProductivityAnomaly(
                type: .productivityDrop,
                severity: min(1.0, drop),
                description: "Average daily focus hours decreased significantly.",
                detectedAt: Date(),
                suggestedActions: [
                    "Schedule two protected deep-work blocks per day.",
                    "Mute non-essential notifications during focus blocks."
                ]
            )
        ]
    }
    
    private func detectFocusAnomalies(_ data: [String: Any], baseline: [String: Any]) -> [ProductivityAnomaly] {
        let recentScore = (data["avg_focus_score"] as? Double) ?? 0
        let baselineScore = (baseline["avg_focus_score"] as? Double) ?? 0
        let recentInterruptions = (data["avg_interruptions_per_session"] as? Double) ?? 0
        let baselineInterruptions = (baseline["avg_interruptions_per_session"] as? Double) ?? 0
        
        var anomalies: [ProductivityAnomaly] = []
        
        if baselineScore > 0, baselineScore - recentScore > 12 {
            let severity = min(1.0, (baselineScore - recentScore) / 30.0)
            anomalies.append(
                ProductivityAnomaly(
                    type: .focusDeterioration,
                    severity: severity,
                    description: "Focus session quality has declined compared with historical performance.",
                    detectedAt: Date(),
                    suggestedActions: [
                        "Shorten session length temporarily and rebuild consistency.",
                        "Review interruption sources and tighten focus settings."
                    ]
                )
            )
        }
        
        if recentInterruptions - baselineInterruptions > 1.0 {
            let severity = min(1.0, (recentInterruptions - baselineInterruptions) / 4.0)
            anomalies.append(
                ProductivityAnomaly(
                    type: .focusDeterioration,
                    severity: severity,
                    description: "Interruptions per session are meaningfully above baseline.",
                    detectedAt: Date(),
                    suggestedActions: [
                        "Use Focus Mode allow-list rules.",
                        "Capture interruptions to identify repeat causes."
                    ]
                )
            )
        }
        
        return anomalies
    }
    
    private func detectHabitAnomalies(_ data: [String: Any], baseline: [String: Any]) -> [ProductivityAnomaly] {
        let recentHabitRate = (data["habit_completion_rate"] as? Double) ?? 0
        let baselineHabitRate = (baseline["habit_completion_rate"] as? Double) ?? 0
        
        guard baselineHabitRate > 0 else { return [] }
        let drop = baselineHabitRate - recentHabitRate
        guard drop > 0.2 else { return [] }
        
        return [
            ProductivityAnomaly(
                type: .habitDisruption,
                severity: min(1.0, drop),
                description: "Habit completion dropped versus your longer-term baseline.",
                detectedAt: Date(),
                suggestedActions: [
                    "Temporarily reduce target counts for fragile habits.",
                    "Stack habits onto a stable daily anchor."
                ]
            )
        ]
    }
    
    private func analyzeProductivityTrends(context: ModelContext) async -> [String: Any] {
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let recentSessions = sessions.sorted { $0.startTime < $1.startTime }.suffix(30)
        
        guard !recentSessions.isEmpty else {
            return ["trend_direction": "stable", "weekly_change": 0.0, "average_score": 0.0]
        }
        
        let scores = recentSessions.map(\.productivityScore)
        let averageScore = scores.reduce(0, +) / Double(scores.count)
        let firstHalf = Array(scores.prefix(max(1, scores.count / 2)))
        let secondHalf = Array(scores.suffix(max(1, scores.count / 2)))
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let weeklyChange = secondAverage - firstAverage
        
        let direction: String
        if weeklyChange > 5 {
            direction = "up"
        } else if weeklyChange < -5 {
            direction = "down"
        } else {
            direction = "stable"
        }
        
        return [
            "trend_direction": direction,
            "weekly_change": weeklyChange,
            "average_score": averageScore
        ]
    }
    
    private func analyzeHabitInsights(context: ModelContext) async -> [String: Any] {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let activeHabits = habits.filter(\.isActive)
        
        guard !activeHabits.isEmpty else {
            return ["total_habits": 0]
        }
        
        let bestHabit = activeHabits.max { $0.completionRate < $1.completionRate }
        let weakestHabit = activeHabits.min { $0.completionRate < $1.completionRate }
        let averageRate = activeHabits.reduce(0) { $0 + $1.completionRate } / Double(activeHabits.count)
        
        return [
            "total_habits": activeHabits.count,
            "average_completion_rate": averageRate,
            "best_habit": bestHabit?.title ?? "",
            "weakest_habit": weakestHabit?.title ?? "",
            "average_streak": Double(activeHabits.reduce(0) { $0 + $1.currentStreak }) / Double(activeHabits.count)
        ]
    }
    
    private func generateProductivityInsights(from analysis: UserBehaviorAnalysis, trends: [String: Any]) -> [PersonalizedInsight] {
        var insights: [PersonalizedInsight] = []
        
        if let trendDirection = trends["trend_direction"] as? String {
            switch trendDirection {
            case "up":
                insights.append(
                    PersonalizedInsight(
                        title: "Productivity Momentum Is Improving",
                        description: "Your recent focus trend is moving upward. Preserve what is currently working.",
                        category: .productivity,
                        confidence: 0.84,
                        importance: 0.75,
                        actionableSteps: [
                            "Keep your current highest-performing session windows.",
                            "Protect at least one deep-work block daily."
                        ]
                    )
                )
            case "down":
                insights.append(
                    PersonalizedInsight(
                        title: "Productivity Trend Is Slipping",
                        description: "Recent sessions are underperforming compared with your baseline.",
                        category: .productivity,
                        confidence: 0.8,
                        importance: 0.9,
                        actionableSteps: [
                            "Reduce workload in the next 48 hours.",
                            "Prioritize high-impact tasks only."
                        ]
                    )
                )
            default:
                break
            }
        }
        
        if analysis.taskCompletionPatterns.procrastinationScore > 0.45 {
            insights.append(
                PersonalizedInsight(
                    title: "Procrastination Pattern Detected",
                    description: "A significant share of tasks are completed late relative to due dates.",
                    category: .timeManagement,
                    confidence: 0.78,
                    importance: 0.88,
                    actionableSteps: [
                        "Schedule tasks in your best completion hours.",
                        "Split high-friction tasks into smaller steps."
                    ]
                )
            )
        }
        
        return insights
    }
    
    private func generateHabitInsights(from insights: [String: Any]) -> [PersonalizedInsight] {
        guard let totalHabits = insights["total_habits"] as? Int, totalHabits > 0 else {
            return []
        }
        
        var generated: [PersonalizedInsight] = []
        
        let averageCompletionRate = (insights["average_completion_rate"] as? Double) ?? 0
        if averageCompletionRate < 0.5, let weakestHabit = insights["weakest_habit"] as? String, !weakestHabit.isEmpty {
            generated.append(
                PersonalizedInsight(
                    title: "Strengthen \(weakestHabit)",
                    description: "This habit has the lowest completion consistency and is holding back streak momentum.",
                    category: .habitFormation,
                    confidence: 0.76,
                    importance: 0.82,
                    actionableSteps: [
                        "Lower the daily target temporarily.",
                        "Attach the habit to a reliable trigger."
                    ]
                )
            )
        }
        
        if let bestHabit = insights["best_habit"] as? String, !bestHabit.isEmpty {
            generated.append(
                PersonalizedInsight(
                    title: "\(bestHabit) Is Your Most Stable Habit",
                    description: "Use this routine as an anchor to stack additional habits.",
                    category: .habitFormation,
                    confidence: 0.7,
                    importance: 0.65,
                    actionableSteps: [
                        "Pair one weaker habit immediately after this one.",
                        "Track consistency for seven days."
                    ]
                )
            )
        }
        
        return generated
    }
    
    private func generateTimeManagementInsights(from analysis: UserBehaviorAnalysis) -> [PersonalizedInsight] {
        var insights: [PersonalizedInsight] = []
        
        if analysis.timeUsagePatterns.averageSessionLength < 20 * 60 {
            insights.append(
                PersonalizedInsight(
                    title: "Sessions Are Too Fragmented",
                    description: "Your average session length is short, which can reduce deep-focus output.",
                    category: .timeManagement,
                    confidence: 0.72,
                    importance: 0.8,
                    actionableSteps: [
                        "Target 30-minute minimum focus blocks.",
                        "Batch low-effort tasks into one slot."
                    ]
                )
            )
        }
        
        if !analysis.timeUsagePatterns.peakProductivityHours.isEmpty {
            let hours = analysis.timeUsagePatterns.peakProductivityHours.map(String.init).joined(separator: ", ")
            insights.append(
                PersonalizedInsight(
                    title: "Use Peak Hours More Intentionally",
                    description: "Your strongest productivity windows are around \(hours):00.",
                    category: .timeManagement,
                    confidence: 0.78,
                    importance: 0.76,
                    actionableSteps: [
                        "Reserve peak windows for demanding work.",
                        "Move admin tasks outside peak windows."
                    ]
                )
            )
        }
        
        return insights
    }
    
    private func generateWellnessInsights(from analysis: UserBehaviorAnalysis) -> [PersonalizedInsight] {
        var insights: [PersonalizedInsight] = []
        
        if analysis.productivityPatterns.burnoutRiskScore > 0.6 {
            insights.append(
                PersonalizedInsight(
                    title: "Burnout Risk Is Elevated",
                    description: "Session and interruption patterns indicate growing cognitive load.",
                    category: .wellness,
                    confidence: 0.82,
                    importance: 0.95,
                    actionableSteps: [
                        "Reduce session length for the next two days.",
                        "Schedule recovery breaks proactively."
                    ]
                )
            )
        }
        
        if analysis.productivityPatterns.interruptionPatterns.averageRecoveryTime > 10 * 60 {
            insights.append(
                PersonalizedInsight(
                    title: "Recovery After Interruptions Is Slow",
                    description: "Interruptions are causing long focus-recovery cycles.",
                    category: .focus,
                    confidence: 0.74,
                    importance: 0.78,
                    actionableSteps: [
                        "Capture interruptions quickly and return to one next step.",
                        "Use stricter focus notifications settings."
                    ]
                )
            )
        }
        
        return insights
    }
    
    private func calculateAverageCompletionDelay(_ reminders: [Reminder]) -> TimeInterval {
        let delays = reminders.compactMap { reminder -> TimeInterval? in
            guard let dueDate = reminder.dueDate, let completedAt = reminder.completedAt else { return nil }
            return max(0, completedAt.timeIntervalSince(dueDate))
        }
        
        guard !delays.isEmpty else { return 0.0 }
        return delays.reduce(0, +) / Double(delays.count)
    }
    
    private func findPeakHours(from distribution: [Int: Double]) -> [Int] {
        return distribution
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }
    
    private func calculateOptimalSessionLength(_ lengths: [TimeInterval]) -> TimeInterval {
        let validLengths = lengths.filter { $0 > 0 }
        guard !validLengths.isEmpty else { return 0 }
        
        let sorted = validLengths.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
    
    private func analyzeInterruptionPatterns(_ sessions: [FocusSession]) -> InterruptionPatterns {
        let interruptions = sessions.flatMap { $0.interruptions ?? [] }
        
        let byReason = Dictionary(grouping: interruptions, by: \.reason)
            .mapValues(\.count)
        
        let commonTypes = byReason
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        
        let byHour = Dictionary(grouping: interruptions) { interruption in
            Calendar.current.component(.hour, from: interruption.timestamp)
        }
        .mapValues(\.count)
        
        let peakTimes = byHour
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        
        let durations = interruptions.map(\.duration).filter { $0 > 0 }
        let averageRecovery = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        
        return InterruptionPatterns(
            commonTypes: commonTypes,
            peakTimes: peakTimes,
            averageRecoveryTime: averageRecovery
        )
    }
    
    private func findOptimalWorkingHours(_ sessions: [FocusSession]) -> [Int] {
        let byHour = Dictionary(grouping: sessions) { session in
            Calendar.current.component(.hour, from: session.startTime)
        }
        .mapValues { sessions in
            sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        }
        
        return byHour
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map(\.key)
    }
    
    private func calculateBurnoutRisk(_ sessions: [FocusSession]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }
        
        let averageDuration = sessions.reduce(0) { $0 + $1.actualDuration } / Double(sessions.count)
        let averageInterruptions = Double(sessions.reduce(0) { $0 + $1.interruptionCount }) / Double(sessions.count)
        let averageProductivity = sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        
        let durationRisk = min(1.0, max(0.0, (averageDuration - 45 * 60) / (60 * 60)))
        let interruptionRisk = min(1.0, averageInterruptions / 5.0)
        let productivityRisk = max(0.0, min(1.0, (70.0 - averageProductivity) / 70.0))
        
        return max(0.0, min(1.0, durationRisk * 0.35 + interruptionRisk * 0.35 + productivityRisk * 0.3))
    }
    
    private func calculateAverageStreakLength(_ habit: Habit) -> Double {
        let entries = (habit.entries ?? [])
            .sorted { $0.date < $1.date }
        
        guard !entries.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        var streaks: [Int] = []
        var currentStreak = 0
        var lastDate: Date?
        
        for entry in entries {
            let normalizedDate = calendar.startOfDay(for: entry.date)
            let completed = entry.count >= habit.targetCount
            
            if !completed {
                if currentStreak > 0 {
                    streaks.append(currentStreak)
                    currentStreak = 0
                }
                lastDate = normalizedDate
                continue
            }
            
            if let lastDate {
                let gap = calendar.dateComponents([.day], from: lastDate, to: normalizedDate).day ?? 0
                if gap == 1 {
                    currentStreak += 1
                } else if gap > 1 {
                    if currentStreak > 0 {
                        streaks.append(currentStreak)
                    }
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = normalizedDate
        }
        
        if currentStreak > 0 {
            streaks.append(currentStreak)
        }
        
        guard !streaks.isEmpty else { return 0.0 }
        return Double(streaks.reduce(0, +)) / Double(streaks.count)
    }
    
    private func clusterSimilarHabits(_ habits: [Habit]) -> [[Habit]] {
        var clusters: [[Habit]] = []
        var unvisited = habits
        
        while let seed = unvisited.first {
            let seedTokens = tokenize(seed.title + " " + seed.habitDescription)
            var cluster: [Habit] = [seed]
            
            unvisited.removeAll { habit in
                guard habit.id != seed.id else { return true }
                let similarity = jaccardSimilarity(seedTokens, tokenize(habit.title + " " + habit.habitDescription))
                if similarity >= 0.3 {
                    cluster.append(habit)
                    return true
                }
                return false
            }
            
            if cluster.count > 1 {
                clusters.append(cluster)
            }
        }
        
        return clusters
    }
    
    private func calculateOptimalHabitFormationTime(_ habits: [Habit]) -> TimeInterval {
        let allEntries = habits.flatMap { $0.entries ?? [] }
        guard !allEntries.isEmpty else { return 0 }
        
        let byHour = Dictionary(grouping: allEntries) { entry in
            Calendar.current.component(.hour, from: entry.date)
        }
        .mapValues(\.count)
        
        let bestHour = byHour.max { $0.value < $1.value }?.key ?? 9
        return TimeInterval(bestHour * 3600)
    }
    
    private func collectProductivityMetrics(context: ModelContext, startDate: Date, endDate: Date) -> [String: Any] {
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                reminder.createdAt >= startDate && reminder.createdAt <= endDate
            }
        )
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        let completionRate = reminders.isEmpty
            ? 0.0
            : Double(reminders.filter(\.isCompleted).count) / Double(reminders.count)
        
        let focusDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        let sessions = (try? context.fetch(focusDescriptor)) ?? []
        
        let averageFocusScore = sessions.isEmpty
            ? 0.0
            : sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        
        let averageInterruptions = sessions.isEmpty
            ? 0.0
            : Double(sessions.reduce(0) { $0 + $1.interruptionCount }) / Double(sessions.count)
        
        let focusHours = sessions.reduce(0) { $0 + $1.actualDuration } / 3600
        let numberOfDays = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        let avgDailyFocusHours = focusHours / Double(numberOfDays)
        
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let activeHabits = habits.filter(\.isActive)
        let habitCompletionRate = activeHabits.isEmpty
            ? 0.0
            : activeHabits.reduce(0) { $0 + $1.completionRate } / Double(activeHabits.count)
        
        return [
            "completion_rate": completionRate,
            "avg_focus_score": averageFocusScore,
            "avg_interruptions_per_session": averageInterruptions,
            "avg_daily_focus_hours": avgDailyFocusHours,
            "habit_completion_rate": habitCompletionRate
        ]
    }
    
    private func normalizeDistribution<K: Hashable>(_ distribution: [K: Double]) -> [K: Double] {
        guard let maxValue = distribution.values.max(), maxValue > 0 else {
            return distribution
        }
        
        return distribution.mapValues { $0 / maxValue }
    }
    
    private func tokenize(_ text: String) -> Set<String> {
        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )
    }
    
    private func jaccardSimilarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0.0 }
        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        return union == 0 ? 0.0 : Double(intersection) / Double(union)
    }
}
