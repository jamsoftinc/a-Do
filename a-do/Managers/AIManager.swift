//
//  AIManager.swift
//  a-do
//
//  AI-powered suggestions and insights manager
//  Enhanced with Apple Intelligence Foundation Models integration
//
//  Requires: iOS 26+
//

import Foundation
import SwiftData
import Observation
import os
import FoundationModels

@MainActor
@Observable
final class AIManager {
    static let shared = AIManager()

    private let logger = Logger(subsystem: "a-do", category: "AI")

    // Apple Intelligence integration
    private var foundationModelsManager: FoundationModelsManager {
        FoundationModelsManager.shared
    }

    /// Whether Apple Intelligence (Foundation Models) is available
    var isAppleIntelligenceAvailable: Bool {
        foundationModelsManager.isAvailable
    }

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Processing state
    var isProcessing: Bool = false
    var lastAnalysisDate: Date?
    var pendingSuggestions: [AISuggestion] = []
    var recentInsights: [AIInsight] = []
    
    // Configuration
    private var configuration: AIConfiguration?
    
    // Analytics cache
    private var analyticsCache: [String: Any] = [:]
    private var cacheTimestamp: Date?
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    
    private init() {
        setupPeriodicAnalysis()
    }
    
    // MARK: - Configuration Management
    
    func getConfiguration(userId: String, context: ModelContext) -> AIConfiguration {
        if let config = configuration, config.userId == userId {
            return config
        }
        
        let descriptor = FetchDescriptor<AIConfiguration>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingConfig = try? context.fetch(descriptor).first {
            configuration = existingConfig
            return existingConfig
        }
        
        // Create default configuration
        let newConfig = AIConfiguration(userId: userId)
        context.insert(newConfig)
        
        do {
            try context.save()
            configuration = newConfig
            logger.info("Created AI configuration for user: \(userId)")
        } catch {
            logger.error("Failed to create AI configuration: \(error.localizedDescription)")
        }
        
        return newConfig
    }
    
    func updateConfiguration(
        userId: String,
        isEnabled: Bool? = nil,
        suggestionFrequency: AISuggestionFrequency? = nil,
        insightFrequency: AIInsightFrequency? = nil,
        privacyLevel: AIPrivacyLevel? = nil,
        confidenceThreshold: Double? = nil,
        context: ModelContext
    ) {
        let config = getConfiguration(userId: userId, context: context)
        
        config.updateSettings(
            isEnabled: isEnabled,
            suggestionFrequency: suggestionFrequency,
            insightFrequency: insightFrequency,
            privacyLevel: privacyLevel,
            confidenceThreshold: confidenceThreshold
        )
        
        do {
            try context.save()
            logger.info("Updated AI configuration for user: \(userId)")
        } catch {
            logger.error("Failed to update AI configuration: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Suggestion Generation

    func generateSuggestions(userId: String, context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("AI suggestions is a Pro feature")
            return
        }

        let config = getConfiguration(userId: userId, context: context)

        guard config.isAIEnabled else {
            logger.info("AI suggestions disabled for user: \(userId)")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Generating AI suggestions for user: \(userId)")
        
        // Clear expired suggestions
        await clearExpiredSuggestions(context: context)
        
        // Generate different types of suggestions
        await generateDueDateSuggestions(userId: userId, context: context)
        await generateTaskBreakdownSuggestions(userId: userId, context: context)
        await generateProductivitySuggestions(userId: userId, context: context)
        await generateHabitSuggestions(userId: userId, context: context)
        await generateCollaborationSuggestions(userId: userId, context: context)
        await generateOrganizationSuggestions(userId: userId, context: context)
        
        // Update pending suggestions list
        await updatePendingSuggestions(context: context)
        
        lastAnalysisDate = Date()
    }
    
    private func generateDueDateSuggestions(userId: String, context: ModelContext) async {
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil }
        )
        
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        let calendar = Calendar.current
        
        for reminder in reminders {
            guard let dueDate = reminder.dueDate else { continue }
            
            // Check for schedule conflicts
            let conflictingReminders = reminders.filter { other in
                guard let otherDue = other.dueDate,
                      other.uuid != reminder.uuid else { return false }
                
                return calendar.isDate(dueDate, inSameDayAs: otherDue) &&
                       abs(dueDate.timeIntervalSince(otherDue)) < 3600 // Within 1 hour
            }
            
            if conflictingReminders.count > 2 {
                let suggestion = AISuggestion(
                    type: .scheduleConflictResolution,
                    title: "Schedule Conflict Detected",
                    description: "You have \(conflictingReminders.count + 1) tasks scheduled around \(dueDate.formatted(date: .omitted, time: .shortened)). Consider spreading them out.",
                    confidence: 0.8
                )
                suggestion.targetReminder = reminder
                suggestion.priority = .high
                
                context.insert(suggestion)
            }
            
            // Check for optimal timing based on historical data
            if let optimalTime = await calculateOptimalTime(for: reminder, context: context) {
                let timeDifference = abs(dueDate.timeIntervalSince(optimalTime))
                
                if timeDifference > 3600 { // More than 1 hour difference
                    let suggestion = AISuggestion(
                        type: .optimalTaskTiming,
                        title: "Better Timing Available",
                        description: "Based on your productivity patterns, \(optimalTime.formatted(date: .omitted, time: .shortened)) might be a better time for this task.",
                        confidence: 0.7
                    )
                    suggestion.targetReminder = reminder
                    suggestion.priority = .medium
                    
                    context.insert(suggestion)
                }
            }
        }
    }
    
    private func generateTaskBreakdownSuggestions(userId: String, context: ModelContext) async {
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted }
        )
        
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        for reminder in reminders {
            // Analyze task complexity based on title and details
            let complexity = analyzeTaskComplexity(reminder: reminder)
            
            if complexity > 0.7 { // High complexity threshold
                let suggestion = AISuggestion(
                    type: .taskBreakdown,
                    title: "Break Down Complex Task",
                    description: "'\(reminder.title)' seems complex. Consider breaking it into smaller, manageable subtasks.",
                    confidence: complexity
                )
                suggestion.targetReminder = reminder
                suggestion.priority = .medium
                
                // Add suggested breakdown in context data
                let breakdown = generateTaskBreakdown(reminder: reminder)
                suggestion.setContextData(["suggestedTasks": breakdown])
                
                context.insert(suggestion)
            }
        }
    }
    
    private func generateProductivitySuggestions(userId: String, context: ModelContext) async {
        // Analyze focus sessions for productivity patterns
        let sessionDescriptor = FetchDescriptor<FocusSession>()
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        
        if sessions.count >= 5 { // Need minimum data
            let productivityAnalysis = analyzeProductivityPatterns(sessions: sessions)
            
            if let bestTime = productivityAnalysis.mostProductiveTime {
                let suggestion = AISuggestion(
                    type: .focusTimeRecommendation,
                    title: "Optimize Your Focus Time",
                    description: "You're most productive around \(bestTime). Consider scheduling important tasks during this time.",
                    confidence: productivityAnalysis.confidence
                )
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
            
            if productivityAnalysis.needsBreaks {
                let suggestion = AISuggestion(
                    type: .breakSuggestion,
                    title: "Take More Breaks",
                    description: "Your productivity drops after \(productivityAnalysis.optimalSessionLength) minutes. Consider taking regular breaks.",
                    confidence: 0.8
                )
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
        }
        
        // Analyze workload distribution
        var descriptor = FetchDescriptor<Reminder>()
        descriptor.fetchLimit = 500
        let workloadAnalysis = analyzeWorkloadDistribution(reminders: (try? context.fetch(descriptor)) ?? [])
        
        if workloadAnalysis.isOverloaded {
            let suggestion = AISuggestion(
                type: .workloadBalance,
                title: "Workload Imbalance Detected",
                description: "You have \(workloadAnalysis.overdueCount) overdue tasks and \(workloadAnalysis.dueTodayCount) due today. Consider rescheduling some tasks.",
                confidence: 0.9
            )
            suggestion.priority = .high
            
            context.insert(suggestion)
        }
    }
    
    private func generateHabitSuggestions(userId: String, context: ModelContext) async {
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        
        for habit in habits {
            // Analyze habit timing patterns
            let timingAnalysis = analyzeHabitTiming(habit: habit)
            
            if let optimalTime = timingAnalysis.optimalTime {
                let suggestion = AISuggestion(
                    type: .habitTiming,
                    title: "Optimize Habit Timing",
                    description: "You're more likely to complete '\(habit.title)' at \(optimalTime). Consider adjusting your schedule.",
                    confidence: timingAnalysis.confidence
                )
                suggestion.targetHabit = habit
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
            
            // Suggest habit stacking opportunities
            if let stackingOpportunity = findHabitStackingOpportunity(for: habit, in: habits) {
                let suggestion = AISuggestion(
                    type: .habitStacking,
                    title: "Habit Stacking Opportunity",
                    description: "Try doing '\(habit.title)' right after '\(stackingOpportunity.title)' to build a stronger routine.",
                    confidence: 0.7
                )
                suggestion.targetHabit = habit
                suggestion.priority = .low
                
                context.insert(suggestion)
            }
            
            // Check for streak opportunities
            if habit.currentStreak >= 3 && habit.currentStreak < 7 {
                let suggestion = AISuggestion(
                    type: .habitStreak,
                    title: "Streak Opportunity",
                    description: "You're on a \(habit.currentStreak)-day streak with '\(habit.title)'! Keep it going to reach 7 days.",
                    confidence: 0.8
                )
                suggestion.targetHabit = habit
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
        }
    }
    
    private func generateCollaborationSuggestions(userId: String, context: ModelContext) async {
        let reminderDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted }
        )
        
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        for reminder in reminders {
            // Analyze if task could benefit from collaboration
            if shouldSuggestCollaboration(for: reminder) {
                let suggestion = AISuggestion(
                    type: .collaborationOpportunity,
                    title: "Collaboration Opportunity",
                    description: "'\(reminder.title)' might benefit from collaboration. Consider sharing it with team members.",
                    confidence: 0.6
                )
                suggestion.targetReminder = reminder
                suggestion.priority = .low
                
                context.insert(suggestion)
            }
            
            // Suggest delegation for overdue high-priority tasks
            // Temporarily disabled - taggedContacts relationship commented out
            if reminder.isOverdue && reminder.priority == .high { // && !(reminder.taggedContacts?.isEmpty ?? true) {
                let suggestion = AISuggestion(
                    type: .delegationSuggestion,
                    title: "Consider Delegation",
                    description: "This high-priority task is overdue. Consider delegating or asking for help from your contacts.",
                    confidence: 0.7
                )
                suggestion.targetReminder = reminder
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
        }
    }
    
    private func generateOrganizationSuggestions(userId: String, context: ModelContext) async {
        let reminderDescriptor = FetchDescriptor<Reminder>()
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        
        // Detect duplicate or similar tasks
        let duplicates = findDuplicateTasks(in: reminders)
        
        for duplicateGroup in duplicates {
            if duplicateGroup.count > 1 {
                let titles = duplicateGroup.map { $0.title }.joined(separator: ", ")
                let suggestion = AISuggestion(
                    type: .duplicateDetection,
                    title: "Duplicate Tasks Detected",
                    description: "You have similar tasks: \(titles). Consider consolidating them.",
                    confidence: 0.8
                )
                suggestion.priority = .medium
                
                context.insert(suggestion)
            }
        }
        
        // Suggest tags for untagged reminders
        // Temporarily disabled - tags relationship commented out
        let untaggedReminders = reminders // .filter { $0.tags?.isEmpty ?? true }
        
        if untaggedReminders.count > 5 {
            let suggestedTags = generateTagSuggestions(for: untaggedReminders)
            
            let suggestion = AISuggestion(
                type: .tagSuggestion,
                title: "Organize with Tags",
                description: "You have \(untaggedReminders.count) untagged reminders. Consider using tags like: \(suggestedTags.joined(separator: ", "))",
                confidence: 0.6
            )
            suggestion.priority = AISuggestionPriority.low
            
            context.insert(suggestion)
        }
    }
    
    // MARK: - Insight Generation
    
    func generateInsights(userId: String, context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("AI insights is a Pro feature")
            return
        }
        let config = getConfiguration(userId: userId, context: context)
        
        guard config.isAIEnabled else { return }
        
        logger.info("Generating AI insights for user: \(userId)")
        
        // Generate different types of insights
        await generateProductivityInsights(context: context)
        await generateHabitInsights(context: context)
        await generateTimeUsageInsights(context: context)
        await generateGoalProgressInsights(context: context)
        
        // Update recent insights
        await updateRecentInsights(context: context)
    }
    
    private func generateProductivityInsights(context: ModelContext) async {
        let sessionDescriptor = FetchDescriptor<FocusSession>()
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        
        guard sessions.count >= 7 else { return } // Need at least a week of data
        
        let productivityTrend = calculateProductivityTrend(sessions: sessions)
        
        let insight = AIInsight(
            type: .productivityTrend,
            title: "Your Productivity This Week",
            summary: productivityTrend.summary,
            confidence: 0.8
        )
        
        insight.detailedAnalysis = productivityTrend.detailedAnalysis
        insight.visualizationType = .lineChart
        insight.actionableRecommendations = try? JSONEncoder().encode(productivityTrend.recommendations)
        insight.setMetrics(productivityTrend.metrics)
        
        context.insert(insight)
    }
    
    private func generateHabitInsights(context: ModelContext) async {
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        
        guard !habits.isEmpty else { return }
        
        let habitProgress = analyzeHabitProgress(habits: habits)
        
        let insight = AIInsight(
            type: .habitProgress,
            title: "Habit Progress Analysis",
            summary: habitProgress.summary,
            confidence: 0.9
        )
        
        insight.detailedAnalysis = habitProgress.detailedAnalysis
        insight.visualizationType = .barChart
        insight.actionableRecommendations = try? JSONEncoder().encode(habitProgress.recommendations)
        
        context.insert(insight)
    }
    
    private func generateTimeUsageInsights(context: ModelContext) async {
        let timeDescriptor = FetchDescriptor<TimeEntry>()
        let timeEntries = (try? context.fetch(timeDescriptor)) ?? []
        
        guard timeEntries.count >= 10 else { return }
        
        let timeAnalysis = analyzeTimeUsage(entries: timeEntries)
        
        let insight = AIInsight(
            type: .timeUsageAnalysis,
            title: "Time Usage Breakdown",
            summary: timeAnalysis.summary,
            confidence: 0.8
        )
        
        insight.detailedAnalysis = timeAnalysis.detailedAnalysis
        insight.visualizationType = .pieChart
        insight.actionableRecommendations = try? JSONEncoder().encode(timeAnalysis.recommendations)
        
        context.insert(insight)
    }
    
    private func generateGoalProgressInsights(context: ModelContext) async {
        let goalDescriptor = FetchDescriptor<FocusGoal>(
            predicate: #Predicate { $0.isActive }
        )
        
        let goals = (try? context.fetch(goalDescriptor)) ?? []
        
        guard !goals.isEmpty else { return }
        
        let goalAnalysis = analyzeGoalProgress(goals: goals)
        
        let insight = AIInsight(
            type: .goalProgress,
            title: "Goal Progress Update",
            summary: goalAnalysis.summary,
            confidence: 0.9
        )
        
        insight.detailedAnalysis = goalAnalysis.detailedAnalysis
        insight.visualizationType = .gauge
        insight.actionableRecommendations = try? JSONEncoder().encode(goalAnalysis.recommendations)
        
        context.insert(insight)
    }
    
    // Timer for periodic analysis - must be retained
    private var analysisTimer: Timer?

    // MARK: - Helper Methods

    private func setupPeriodicAnalysis() {
        // Set up periodic analysis based on user preferences
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor in
                // This would be called with proper context in a real implementation
            }
        }
    }

    /// Call this method to clean up resources when the manager is no longer needed
    func cleanup() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        pendingSuggestions.removeAll()
        recentInsights.removeAll()
        analyticsCache.removeAll()
        configuration = nil
    }
    
    private func clearExpiredSuggestions(context: ModelContext) async {
        let pendingStatusRaw = AISuggestionStatus.pending.rawValue
        let descriptor = FetchDescriptor<AISuggestion>(
            predicate: #Predicate { $0.statusRaw == pendingStatusRaw }
        )
        
        let suggestions = (try? context.fetch(descriptor)) ?? []
        
        for suggestion in suggestions {
            if suggestion.isExpired {
                suggestion.expire()
            }
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to clear expired suggestions: \(error.localizedDescription)")
        }
    }
    
    private func updatePendingSuggestions(context: ModelContext) async {
        let pendingStatusRaw = AISuggestionStatus.pending.rawValue
        let descriptor = FetchDescriptor<AISuggestion>(
            predicate: #Predicate { $0.statusRaw == pendingStatusRaw },
            sortBy: [SortDescriptor(\.priorityRaw, order: .reverse), SortDescriptor(\.confidence, order: .reverse)]
        )
        
        pendingSuggestions = (try? context.fetch(descriptor)) ?? []
    }
    
    private func updateRecentInsights(context: ModelContext) async {
        let descriptor = FetchDescriptor<AIInsight>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let insights = (try? context.fetch(descriptor)) ?? []
        recentInsights = Array(insights.prefix(10))
    }
    
    // MARK: - Analysis Methods (Simplified implementations)
    
    private func calculateOptimalTime(for reminder: Reminder, context: ModelContext) async -> Date? {
        // This would analyze historical completion patterns
        // For now, return a simple suggestion based on time of day
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10 // Suggest 10 AM as optimal time
        return calendar.date(from: components)
    }
    
    private func analyzeTaskComplexity(reminder: Reminder) -> Double {
        let title = reminder.title.lowercased()
        let details = reminder.details?.lowercased() ?? ""
        
        // Simple complexity analysis based on keywords
        let complexityKeywords = ["implement", "design", "research", "analyze", "develop", "create", "build", "plan"]
        let simpleKeywords = ["call", "email", "buy", "check", "review", "send"]
        
        var complexity = 0.5 // Base complexity
        
        for keyword in complexityKeywords {
            if title.contains(keyword) || details.contains(keyword) {
                complexity += 0.2
            }
        }
        
        for keyword in simpleKeywords {
            if title.contains(keyword) || details.contains(keyword) {
                complexity -= 0.1
            }
        }
        
        // Factor in length and details
        if title.count > 50 { complexity += 0.1 }
        if !details.isEmpty { complexity += 0.1 }
        
        return max(0.0, min(1.0, complexity))
    }
    
    private func generateTaskBreakdown(reminder: Reminder) -> [String] {
        // Simple task breakdown suggestions
        return [
            "Research and gather requirements",
            "Create initial plan or outline",
            "Execute main work",
            "Review and refine",
            "Finalize and deliver"
        ]
    }
    
    private func analyzeProductivityPatterns(sessions: [FocusSession]) -> ProductivityAnalysis {
        // Analyze when user is most productive
        guard !sessions.isEmpty else {
            return ProductivityAnalysis(
                mostProductiveTime: nil,
                confidence: 0.0,
                needsBreaks: false,
                optimalSessionLength: 25
            )
        }

        var hourlyProductivity: [Int: Double] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyProductivity[hour, default: 0] += session.productivityScore
        }

        let bestHour = hourlyProductivity.max(by: { $0.value < $1.value })?.key
        let averageSessionLength = sessions.reduce(0) { $0 + $1.actualDuration } / Double(sessions.count)

        return ProductivityAnalysis(
            mostProductiveTime: bestHour.map { "\($0):00" },
            confidence: 0.8,
            needsBreaks: averageSessionLength > 3600, // More than 1 hour
            optimalSessionLength: Int(averageSessionLength / 60) // In minutes
        )
    }
    
    private func analyzeWorkloadDistribution(reminders: [Reminder]) -> WorkloadAnalysis {
        let overdue = reminders.filter { $0.isOverdue }.count
        let dueToday = reminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }.count
        
        return WorkloadAnalysis(
            isOverloaded: overdue > 3 || dueToday > 5,
            overdueCount: overdue,
            dueTodayCount: dueToday
        )
    }
    
    private func analyzeHabitTiming(habit: Habit) -> HabitTimingAnalysis {
        // Analyze when habit is most successfully completed
        let entries = habit.entries ?? []
        guard !entries.isEmpty else {
            return HabitTimingAnalysis(optimalTime: "9:00 AM", confidence: 0.0)
        }
        
        // Group entries by hour of day
        var hourCounts: [Int: Int] = [:]
        for entry in entries {
            let hour = Calendar.current.component(.hour, from: entry.date)
            hourCounts[hour, default: 0] += 1
        }
        
        // Find the hour with most completions
        let bestHour = hourCounts.max(by: { $0.value < $1.value })?.key ?? 9
        let confidence = Double(hourCounts[bestHour] ?? 0) / Double(entries.count)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let optimalTime = formatter.string(from: Calendar.current.date(bySettingHour: bestHour, minute: 0, second: 0, of: Date()) ?? Date())
        
        return HabitTimingAnalysis(
            optimalTime: optimalTime,
            confidence: min(confidence, 1.0)
        )
    }
    
    private func findHabitStackingOpportunity(for habit: Habit, in habits: [Habit]) -> Habit? {
        // Find habits that could be stacked together
        // This would analyze completion patterns and timing
        return habits.first { $0.id != habit.id }
    }
    
    private func shouldSuggestCollaboration(for reminder: Reminder) -> Bool {
        let title = reminder.title.lowercased()
        let collaborationKeywords = ["meeting", "discuss", "review", "team", "group", "collaborate"]
        
        return collaborationKeywords.contains { title.contains($0) }
    }
    
    private func findDuplicateTasks(in reminders: [Reminder]) -> [[Reminder]] {
        // Simple duplicate detection based on title similarity
        var groups: [[Reminder]] = []
        var processed: Set<UUID> = []
        
        for reminder in reminders {
            if processed.contains(reminder.uuid) { continue }
            
            var group = [reminder]
            processed.insert(reminder.uuid)
            
            for other in reminders {
                if processed.contains(other.uuid) { continue }
                
                if reminder.title.lowercased().contains(other.title.lowercased()) ||
                   other.title.lowercased().contains(reminder.title.lowercased()) {
                    group.append(other)
                    processed.insert(other.uuid)
                }
            }
            
            if group.count > 1 {
                groups.append(group)
            }
        }
        
        return groups
    }
    
    private func generateTagSuggestions(for reminders: [Reminder]) -> [String] {
        // Analyze reminder titles and suggest common tags
        let commonWords = extractCommonWords(from: reminders.map { $0.title })
        return Array(commonWords.prefix(3))
    }
    
    private func extractCommonWords(from titles: [String]) -> [String] {
        var wordCount: [String: Int] = [:]
        
        for title in titles {
            let words = title.lowercased().components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
            for word in words {
                if word.count > 3 { // Only consider words longer than 3 characters
                    wordCount[word, default: 0] += 1
                }
            }
        }
        
        return wordCount
            .filter { $0.value > 1 } // Appears more than once
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    // MARK: - Insight Analysis Methods
    
    private func calculateProductivityTrend(sessions: [FocusSession]) -> ProductivityTrendAnalysis {
        let recentSessions = sessions.suffix(7) // Last 7 sessions
        let averageScore = recentSessions.isEmpty ? 0.0 : recentSessions.reduce(0) { $0 + $1.productivityScore } / Double(recentSessions.count)

        return ProductivityTrendAnalysis(
            summary: "Your average productivity score this week is \(Int(averageScore))/100",
            detailedAnalysis: "Based on your recent focus sessions, you're maintaining a good productivity level.",
            recommendations: ["Continue your current focus routine", "Consider longer sessions if you feel comfortable"],
            metrics: ["averageScore": averageScore, "sessionCount": Double(recentSessions.count)]
        )
    }
    
    private func analyzeHabitProgress(habits: [Habit]) -> HabitProgressAnalysis {
        let totalHabits = habits.count
        let activeStreaks = habits.filter { $0.currentStreak > 0 }.count
        
        return HabitProgressAnalysis(
            summary: "\(activeStreaks) out of \(totalHabits) habits have active streaks",
            detailedAnalysis: "You're doing well with habit consistency. Keep focusing on building streaks.",
            recommendations: ["Focus on habits with broken streaks", "Consider habit stacking for better consistency"]
        )
    }
    
    private func analyzeTimeUsage(entries: [TimeEntry]) -> TimeUsageAnalysis {
        var categoryTime: [String: TimeInterval] = [:]
        
        for entry in entries {
            categoryTime[entry.category, default: 0] += entry.actualDuration
        }
        
        let totalTime = categoryTime.values.reduce(0, +)
        let topCategory = categoryTime.max(by: { $0.value < $1.value })?.key ?? "Unknown"
        
        return TimeUsageAnalysis(
            summary: "You spend most of your tracked time on \(topCategory)",
            detailedAnalysis: "Time tracking shows \(Int(totalTime/3600)) hours across \(categoryTime.count) categories.",
            recommendations: ["Consider balancing time across categories", "Track more activities for better insights"]
        )
    }
    
    private func analyzeGoalProgress(goals: [FocusGoal]) -> GoalProgressAnalysis {
        let completedGoals = goals.filter { $0.isCompleted }.count
        let totalGoals = goals.count
        let averageProgress = totalGoals > 0 ? goals.reduce(0) { $0 + $1.progress } / Double(totalGoals) : 0.0

        return GoalProgressAnalysis(
            summary: "\(completedGoals) out of \(totalGoals) goals completed",
            detailedAnalysis: "Your average goal progress is \(Int(averageProgress * 100))%",
            recommendations: ["Focus on goals with low progress", "Set smaller, achievable milestones"]
        )
    }

    // MARK: - Apple Intelligence Enhanced Methods

    /// Parse reminder text using Apple Intelligence (Foundation Models)
    /// Falls back to basic NLP if Apple Intelligence is not available
    func parseReminderWithAI(_ text: String) async -> AIReminderParseResult? {
        guard isProEnabled else {
            logger.warning("AI parsing requires Pro subscription")
            return nil
        }

        // Try Apple Intelligence first
        if isAppleIntelligenceAvailable {
            if let parsed = await foundationModelsManager.parseReminderText(text) {
                return AIReminderParseResult(
                    title: parsed.title,
                    dueDate: parsed.suggestedDueDate,
                    priority: parsed.priority,
                    tags: parsed.tags,
                    isRecurring: parsed.isRecurring,
                    recurringPattern: parsed.recurringPattern,
                    location: parsed.location,
                    notes: parsed.notes,
                    confidence: 0.9
                )
            }
        }

        // Fallback to basic NLP
        let parsed = await NaturalLanguageProcessor.shared.parseReminderText(text)

        var priorityString: String? = nil
        if parsed.priority != .none {
            priorityString = parsed.priority.title.lowercased()
        }

        var dueDateString: String? = nil
        if let dueDate = parsed.dueDate {
            let formatter = ISO8601DateFormatter()
            dueDateString = formatter.string(from: dueDate)
        }

        return AIReminderParseResult(
            title: parsed.finalText,
            dueDate: dueDateString,
            priority: priorityString,
            tags: [],
            isRecurring: false,
            confidence: 0.7
        )
    }

    /// Generate smart task breakdown using Apple Intelligence
    func generateSmartTaskBreakdown(for reminder: Reminder) async -> AITaskBreakdown? {
        guard isProEnabled else {
            logger.warning("Task breakdown requires Pro subscription")
            return nil
        }

        // Try Apple Intelligence first
        if isAppleIntelligenceAvailable {
            if let breakdown = await foundationModelsManager.generateTaskBreakdown(
                for: reminder.title,
                details: reminder.details
            ) {
                return AITaskBreakdown(
                    subtasks: breakdown.subtasks.map { subtask in
                        AISubtask(
                            title: subtask.title,
                            estimatedMinutes: subtask.estimatedMinutes,
                            order: subtask.order
                        )
                    },
                    estimatedTotalMinutes: breakdown.estimatedTotalMinutes,
                    complexity: breakdown.complexity,
                    reasoning: breakdown.reasoning
                )
            }
        }

        // Fallback to heuristic breakdown
        let heuristicSubtasks = generateTaskBreakdown(reminder: reminder)
        let complexityScore = analyzeTaskComplexity(reminder: reminder)
        let complexityString = complexityScore > 0.7 ? "complex" : "moderate"
        return AITaskBreakdown(
            subtasks: heuristicSubtasks.enumerated().map { index, title in
                AISubtask(
                    title: title,
                    estimatedMinutes: 15,
                    order: index + 1
                )
            },
            estimatedTotalMinutes: heuristicSubtasks.count * 15,
            complexity: complexityString,
            reasoning: "Based on task analysis"
        )
    }

    /// Generate AI-powered productivity insights
    func generateAIProductivityInsights(context: ModelContext) async -> AIProductivityInsight? {
        guard isProEnabled else {
            logger.warning("AI insights require Pro subscription")
            return nil
        }

        // Gather data
        let reminderDescriptor = FetchDescriptor<Reminder>()
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []
        let completedCount = reminders.filter { $0.isCompleted }.count

        let sessionDescriptor = FetchDescriptor<FocusSession>()
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let focusMinutes = Int(sessions.reduce(0.0) { $0 + $1.actualDuration } / 60.0)

        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        let habitRate = habits.isEmpty ? 0.0 : Double(habits.filter { $0.isCompletedToday }.count) / Double(habits.count)

        // Try Apple Intelligence
        if isAppleIntelligenceAvailable {
            if let insights = await foundationModelsManager.generateProductivityInsights(
                completedTasks: completedCount,
                totalTasks: reminders.count,
                focusMinutes: focusMinutes,
                habitCompletionRate: habitRate,
                topCategories: ["Work", "Personal", "Health"]
            ) {
                return AIProductivityInsight(
                    summary: insights.summary,
                    keyFindings: insights.keyFindings,
                    recommendations: insights.recommendations,
                    productivityScore: insights.productivityScore,
                    trend: insights.trend
                )
            }
        }

        // Fallback to basic analysis
        let completionRate = reminders.isEmpty ? 0.0 : Double(completedCount) / Double(reminders.count)
        let score = Int((completionRate * 0.4 + habitRate * 0.3 + min(Double(focusMinutes) / 120.0, 1.0) * 0.3) * 100)

        let trendString = completionRate > 0.5 ? "improving" : (completionRate > 0.3 ? "stable" : "declining")
        return AIProductivityInsight(
            summary: "You've completed \(completedCount) of \(reminders.count) tasks",
            keyFindings: [
                "Task completion rate: \(Int(completionRate * 100))%",
                "Focus time: \(focusMinutes) minutes",
                "Habit completion: \(Int(habitRate * 100))%"
            ],
            recommendations: [
                "Try to complete at least 3 more tasks today",
                "Schedule focused work time in the morning"
            ],
            productivityScore: score,
            trend: trendString
        )
    }

    /// Get AI-powered habit optimization suggestions
    func optimizeHabitWithAI(_ habit: Habit) async -> AIHabitOptimization? {
        guard isProEnabled else {
            logger.warning("Habit optimization requires Pro subscription")
            return nil
        }

        let entries = habit.entries ?? []
        let completionTimes = entries.prefix(10).compactMap { entry -> String? in
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: entry.date)
        }

        // Try Apple Intelligence
        if isAppleIntelligenceAvailable {
            if let optimization = await foundationModelsManager.optimizeHabit(
                habitTitle: habit.title,
                currentStreak: habit.currentStreak,
                completionTimes: Array(completionTimes),
                relatedHabits: []
            ) {
                return AIHabitOptimization(
                    optimalTime: optimization.optimalTime,
                    stackingOpportunities: optimization.stackingOpportunities.map { opp in
                        AIHabitStack(habitName: opp, timing: "after", reasoning: "Based on your patterns")
                    },
                    motivationalTips: optimization.motivationalTips,
                    predictedSuccessRate: optimization.predictedSuccessRate
                )
            }
        }

        // Fallback to basic analysis
        let timing = analyzeHabitTiming(habit: habit)
        return AIHabitOptimization(
            optimalTime: timing.optimalTime,
            stackingOpportunities: [],
            motivationalTips: [
                "Keep your streak going!",
                "Set a daily reminder for consistency"
            ],
            predictedSuccessRate: Int(timing.confidence * 100)
        )
    }

    /// Summarize reminders using Apple Intelligence
    func summarizeRemindersWithAI(_ reminders: [Reminder]) async -> AISummary? {
        guard isProEnabled else {
            logger.warning("AI summarization requires Pro subscription")
            return nil
        }

        let titles = reminders.map { $0.title }

        // Try Apple Intelligence
        if isAppleIntelligenceAvailable {
            if let summary = await foundationModelsManager.summarizeReminders(titles) {
                return AISummary(
                    briefSummary: summary.briefSummary,
                    keyPoints: summary.keyPoints,
                    actionItems: summary.actionItems,
                    urgencyLevel: summary.urgencyLevel
                )
            }
        }

        // Fallback to basic summary
        let overdueCount = reminders.filter { $0.isOverdue }.count
        let highPriorityCount = reminders.filter { $0.priority == .high }.count

        var urgencyString = "low"
        if overdueCount > 0 || highPriorityCount > 2 {
            urgencyString = "high"
        } else if highPriorityCount > 0 {
            urgencyString = "medium"
        }

        return AISummary(
            briefSummary: "You have \(reminders.count) tasks, \(overdueCount) overdue",
            keyPoints: [
                "\(reminders.count) total tasks",
                "\(overdueCount) overdue",
                "\(highPriorityCount) high priority"
            ],
            actionItems: reminders.prefix(3).map { $0.title },
            urgencyLevel: urgencyString
        )
    }

    /// Get smart scheduling suggestions using Apple Intelligence
    func getSmartScheduleSuggestions(
        for reminder: Reminder,
        existingEvents: [String]
    ) async -> AISmartSchedule? {
        guard isProEnabled else {
            logger.warning("Smart scheduling requires Pro subscription")
            return nil
        }

        // Try Apple Intelligence
        if isAppleIntelligenceAvailable {
            if let schedule = await foundationModelsManager.suggestSchedule(
                taskTitle: reminder.title,
                estimatedMinutes: 30,
                existingEvents: existingEvents,
                preferences: ["Prefer morning for focused work"]
            ) {
                return AISmartSchedule(
                    suggestedTimeSlots: schedule.suggestedTimeSlots.map { slot in
                        AITimeSlot(
                            startTime: slot.startTime,
                            endTime: slot.endTime,
                            confidence: slot.confidence,
                            reason: slot.reason
                        )
                    },
                    conflictWarnings: schedule.conflictWarnings,
                    reasoning: schedule.reasoning
                )
            }
        }

        // Fallback to basic suggestion
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var suggestedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        if Date() > suggestedTime {
            suggestedTime = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
        }

        let endTime = suggestedTime.addingTimeInterval(30 * 60)

        return AISmartSchedule(
            suggestedTimeSlots: [
                AITimeSlot(
                    startTime: formatter.string(from: suggestedTime),
                    endTime: formatter.string(from: endTime),
                    confidence: 70,
                    reason: "Based on typical productivity patterns"
                )
            ],
            conflictWarnings: [],
            reasoning: "Suggested based on general productivity patterns"
        )
    }
}

// MARK: - Supporting Types

struct ProductivityAnalysis {
    let mostProductiveTime: String?
    let confidence: Double
    let needsBreaks: Bool
    let optimalSessionLength: Int
}

struct WorkloadAnalysis {
    let isOverloaded: Bool
    let overdueCount: Int
    let dueTodayCount: Int
}

struct HabitTimingAnalysis {
    let optimalTime: String?
    let confidence: Double
}

struct ProductivityTrendAnalysis {
    let summary: String
    let detailedAnalysis: String
    let recommendations: [String]
    let metrics: [String: Double]
}

struct HabitProgressAnalysis {
    let summary: String
    let detailedAnalysis: String
    let recommendations: [String]
}

struct TimeUsageAnalysis {
    let summary: String
    let detailedAnalysis: String
    let recommendations: [String]
}

struct GoalProgressAnalysis {
    let summary: String
    let detailedAnalysis: String
    let recommendations: [String]
}
