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
    var isGeneratingNextWeekPlan: Bool = false
    var currentNextWeekPlan: WeeklyActionPlan?
    var lastPlanApplySummary: String?
    var lastReviewDate: Date? {
        get { UserDefaults.standard.object(forKey: "LastWeeklyReviewDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "LastWeeklyReviewDate") }
    }
    var lastPlanDate: Date? {
        get { UserDefaults.standard.object(forKey: "LastWeeklyPlanDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "LastWeeklyPlanDate") }
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
            
            // 2. Generate Content using selected AI provider
            let content = try await generateAIContent(from: data, context: context)
            
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

    func generateNextWeekPlan(context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("Next week planning is a Pro feature")
            return
        }

        isGeneratingNextWeekPlan = true
        defer { isGeneratingNextWeekPlan = false }

        do {
            let planningData = try await aggregatePlanningData(context: context)
            let plan = try await generateNextWeekPlanContent(from: planningData)
            currentNextWeekPlan = normalize(plan)
            lastPlanDate = Date()
            logger.info("Generated next week plan")
        } catch {
            logger.error("Failed to generate next week plan: \(error.localizedDescription)")
            currentNextWeekPlan = fallbackNextWeekPlan()
        }
    }

    @discardableResult
    func applyCurrentNextWeekPlan(context: ModelContext) async -> WeeklyPlanApplyResult {
        guard isProEnabled else {
            logger.warning("Applying next week plan requires Pro")
            return .empty
        }

        guard let plan = currentNextWeekPlan else {
            return .empty
        }

        let calendar = Calendar.current
        let nextWeekStart = startOfNextWeek()

        var result = WeeklyPlanApplyResult.empty
        let shouldCreateCalendarBlocks = EntitlementManager.shared.canUseCalendarBlocking
        if shouldCreateCalendarBlocks {
            await CalendarManager.shared.requestAccess()
        }

        for item in plan.reminders.prefix(12) {
            let dueDate = nextWeekDate(
                startOfNextWeek: nextWeekStart,
                weekday: item.weekday,
                hour: item.hour,
                minute: item.minute
            )
            let priority = priority(from: item.priority)
            let recurrence = recurrencePattern(from: item.recurringPattern)

            if recurrence == .none {
                let request = ReminderCreationService.Request(
                    title: item.title,
                    details: item.details?.nilIfBlank,
                    dueDate: dueDate,
                    priority: priority
                )

                do {
                    _ = try await ReminderCreationService.shared.createReminder(request: request, in: context)
                    result.oneTimeRemindersCreated += 1
                } catch {
                    logger.error("Failed to create planned reminder '\(item.title)': \(error.localizedDescription)")
                }
            } else {
                let template = ReminderTemplate(
                    name: item.title,
                    title: item.title,
                    details: item.details?.nilIfBlank,
                    category: "AI Weekly Plan",
                    priority: priority
                )
                context.insert(template)

                let recurring = RecurringRemindersManager.shared.createRecurringReminder(
                    template: template,
                    pattern: recurrence,
                    startDate: dueDate,
                    context: context
                )
                recurring.nextDue = dueDate
                recurring.lastGenerated = calendar.date(byAdding: .day, value: -7, to: dueDate)
                result.recurringRemindersCreated += 1
            }
        }

        for block in plan.focusBlocks.prefix(8) {
            let durationMinutes = max(15, min(180, block.durationMinutes))
            let focusType = focusType(from: block.focusType)
            let template = FocusTemplate(
                name: block.title,
                focusType: focusType,
                duration: TimeInterval(durationMinutes * 60)
            )
            template.templateDescription = "Generated from Weekly Review"
            context.insert(template)
            result.focusTemplatesCreated += 1

            guard shouldCreateCalendarBlocks, CalendarManager.shared.accessGranted else { continue }

            let blockDate = nextWeekDate(
                startOfNextWeek: nextWeekStart,
                weekday: block.weekday,
                hour: block.hour,
                minute: block.minute
            )

            let reminder = Reminder(
                title: block.title,
                details: "Focus block (\(focusType.displayName))",
                dueDate: blockDate,
                priority: .medium
            )
            context.insert(reminder)

            do {
                _ = try await CalendarManager.shared.createTimeBlock(
                    for: reminder,
                    startDate: blockDate,
                    duration: TimeInterval(durationMinutes * 60),
                    context: context
                )
                result.calendarBlocksCreated += 1
            } catch {
                logger.error("Failed to create focus calendar block '\(block.title)': \(error.localizedDescription)")
            }
        }

        let existingHabits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        var mutableHabits = existingHabits

        for target in plan.habits.prefix(8) {
            let normalizedTitle = target.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTitle.isEmpty else { continue }

            if let existing = mutableHabits.first(where: { $0.title.caseInsensitiveCompare(normalizedTitle) == .orderedSame }) {
                existing.habitDescription = target.habitDescription?.nilIfBlank ?? existing.habitDescription
                existing.targetCount = max(1, target.targetCount)
                existing.unit = target.unit.nilIfBlank ?? existing.unit
                existing.frequency = habitFrequency(from: target.frequency)
                existing.updatedAt = Date()
                result.habitsUpdated += 1
            } else {
                let newHabit = Habit(
                    title: normalizedTitle,
                    description: target.habitDescription?.nilIfBlank ?? "",
                    icon: "target",
                    color: "#007AFF",
                    frequency: habitFrequency(from: target.frequency),
                    targetCount: max(1, target.targetCount),
                    unit: target.unit.nilIfBlank ?? "times"
                )
                context.insert(newHabit)
                mutableHabits.append(newHabit)
                result.habitsCreated += 1
            }
        }

        for habit in mutableHabits {
            Task {
                await AdvancedSearchManager.shared.upsertHabitIndex(for: habit, context: context)
            }
        }

        let weeklyFocusHours = plan.focusBlocks
            .prefix(8)
            .reduce(0.0) { partialResult, block in
                partialResult + Double(max(15, min(180, block.durationMinutes))) / 60.0
            }
        if weeklyFocusHours > 0 {
            let goals = (try? context.fetch(FetchDescriptor<FocusGoal>())) ?? []
            if let goal = goals.first(where: { $0.title == "AI Weekly Focus Target" && $0.targetType == .weeklyTime }) {
                goal.targetValue = max(1.0, weeklyFocusHours)
                goal.currentValue = 0
                goal.isCompleted = false
                goal.completedAt = nil
                goal.lastUpdated = Date()
            } else {
                let goal = FocusGoal(
                    title: "AI Weekly Focus Target",
                    targetType: .weeklyTime,
                    targetValue: max(1.0, weeklyFocusHours)
                )
                context.insert(goal)
            }
            result.weeklyFocusGoalConfigured = true
        }

        do {
            try context.save()
        } catch {
            logger.error("Failed to save applied weekly plan: \(error.localizedDescription)")
        }

        lastPlanApplySummary = result.summary
        return result
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

    private struct PlanningData: Codable {
        let completedTasksLastWeek: Int
        let openTaskCount: Int
        let overdueTaskCount: Int
        let focusHoursLastWeek: Double
        let mostProductiveDay: String
        let topOpenTasks: [String]
        let activeHabitTargets: [PlanningHabitSnapshot]
    }

    private struct PlanningHabitSnapshot: Codable {
        let title: String
        let completionRate: Double
        let currentStreak: Int
        let targetCount: Int
        let frequency: String
    }
    
    private func aggregateWeeklyData(context: ModelContext) async throws -> WeeklyData {
        let calendar = Calendar.current
        let today = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!
        
        // Fetch current-week focus sessions
        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= oneWeekAgo && $0.startTime <= today }
        )
        let sessions = try context.fetch(sessionDescriptor)
        
        // Fetch previous-week focus sessions for trend comparison
        let previousSessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= twoWeeksAgo && $0.startTime < oneWeekAgo }
        )
        let previousSessions = try context.fetch(previousSessionDescriptor)
        
        // Calculate Metrics
        let totalTime = sessions.reduce(0) { $0 + ($1.actualDuration) }
        let completedSessions = sessions.filter { $0.wasCompleted }.count
        let interruptions = sessions.reduce(0) { $0 + $1.interruptionCount }
        
        // Fetch completed tasks for current week
        let completedTaskDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.completedAt != nil && $0.completedAt! >= oneWeekAgo }
        )
        let tasks = try context.fetch(completedTaskDescriptor)
        
        // Fetch completed tasks for previous week
        let previousCompletedTaskDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.completedAt != nil && $0.completedAt! >= twoWeeksAgo && $0.completedAt! < oneWeekAgo }
        )
        let previousTasks = try context.fetch(previousCompletedTaskDescriptor)
        
        let currentProductivityScore = computeWeeklyProductivityScore(
            focusTime: totalTime,
            sessionsCompleted: completedSessions,
            tasksCompleted: tasks.count,
            interruptions: interruptions
        )
        
        let previousProductivityScore = computeWeeklyProductivityScore(
            focusTime: previousSessions.reduce(0) { $0 + $1.actualDuration },
            sessionsCompleted: previousSessions.filter { $0.wasCompleted }.count,
            tasksCompleted: previousTasks.count,
            interruptions: previousSessions.reduce(0) { $0 + $1.interruptionCount }
        )
        
        let trend = deriveTrend(
            current: currentProductivityScore,
            previous: previousProductivityScore
        )
        
        let productiveDay = determineMostProductiveDay(
            sessions: sessions,
            completedTasks: tasks
        )
        
        return WeeklyData(
            totalFocusTime: totalTime,
            sessionsCompleted: completedSessions,
            tasksCompleted: tasks.count,
            productivityTrend: trend,
            mostProductiveDay: productiveDay,
            interruptionCount: interruptions
        )
    }

    private func aggregatePlanningData(context: ModelContext) async throws -> PlanningData {
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let completedTaskDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.completedAt != nil && $0.completedAt! >= oneWeekAgo }
        )
        let completedTasks = try context.fetch(completedTaskDescriptor)

        let openTaskDescriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let openTasks = try context.fetch(openTaskDescriptor)
        let overdueCount = openTasks.filter { $0.isOverdue }.count

        let sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= oneWeekAgo && $0.startTime <= now }
        )
        let sessions = try context.fetch(sessionDescriptor)
        let focusHours = sessions.reduce(0.0) { $0 + ($1.actualDuration / 3600.0) }

        let activeHabitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let activeHabits = try context.fetch(activeHabitDescriptor)

        let topTasks = openTasks
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.createdAt < rhs.createdAt
                }
            }
            .prefix(6)
            .map(\.title)

        let habitSnapshots = activeHabits
            .sorted { $0.completionRate > $1.completionRate }
            .prefix(6)
            .map { habit in
                PlanningHabitSnapshot(
                    title: habit.title,
                    completionRate: habit.completionRate,
                    currentStreak: habit.currentStreak,
                    targetCount: habit.targetCount,
                    frequency: habit.frequency?.rawValue ?? "daily"
                )
            }

        let mostProductiveDay = determineMostProductiveDay(
            sessions: sessions,
            completedTasks: completedTasks
        )

        return PlanningData(
            completedTasksLastWeek: completedTasks.count,
            openTaskCount: openTasks.count,
            overdueTaskCount: overdueCount,
            focusHoursLastWeek: focusHours,
            mostProductiveDay: mostProductiveDay,
            topOpenTasks: Array(topTasks),
            activeHabitTargets: habitSnapshots
        )
    }
    
    private func computeWeeklyProductivityScore(
        focusTime: TimeInterval,
        sessionsCompleted: Int,
        tasksCompleted: Int,
        interruptions: Int
    ) -> Double {
        let focusHours = focusTime / 3600
        let completionComponent = Double(tasksCompleted) * 1.2
        let sessionComponent = Double(sessionsCompleted) * 0.8
        let interruptionPenalty = Double(interruptions) * 0.4
        return max(0, focusHours + completionComponent + sessionComponent - interruptionPenalty)
    }
    
    private func deriveTrend(current: Double, previous: Double) -> String {
        guard previous > 0 else {
            return current > 0 ? "Up" : "Stable"
        }
        
        let delta = (current - previous) / previous
        if delta > 0.1 {
            return "Up"
        }
        if delta < -0.1 {
            return "Down"
        }
        return "Stable"
    }
    
    private func determineMostProductiveDay(
        sessions: [FocusSession],
        completedTasks: [Reminder]
    ) -> String {
        var scoresByWeekday: [Int: Double] = [:]
        let calendar = Calendar.current
        
        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.startTime)
            scoresByWeekday[weekday, default: 0] += max(0, session.productivityScore)
        }
        
        for task in completedTasks {
            guard let completedAt = task.completedAt else { continue }
            let weekday = calendar.component(.weekday, from: completedAt)
            scoresByWeekday[weekday, default: 0] += 25
        }
        
        guard let bestWeekday = scoresByWeekday.max(by: { $0.value < $1.value })?.key else {
            return "No activity recorded"
        }
        
        let weekdaySymbols = calendar.weekdaySymbols
        let index = max(0, min(weekdaySymbols.count - 1, bestWeekday - 1))
        return weekdaySymbols[index]
    }
    
    // MARK: - AI Generation

    private func generateAIContent(from data: WeeklyData, context _: ModelContext) async throws -> WeeklyReviewContent {
        let userId = SecurityUtils.getCurrentUserID()
        let provider = AIManager.shared.provider(for: .weeklyReview, userId: userId)

        if provider == .googleGemini3 {
            do {
                return try await generateGeminiContent(from: data)
            } catch {
                logger.error("Gemini weekly review generation failed: \(error.localizedDescription). Falling back to Apple on-device model.")
            }
        }

        return try await generateFoundationModelContent(from: data)
    }

    private func generateFoundationModelContent(from data: WeeklyData) async throws -> WeeklyReviewContent {
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

    private func generateGeminiContent(from data: WeeklyData) async throws -> WeeklyReviewContent {
        let dataJSON = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
        Generate an Executive Weekly Review from this productivity data:
        \(dataJSON)

        Return ONLY valid JSON with keys:
        - grade (String): Letter grade A-F.
        - summary (String): 1-2 sentence analysis.
        - highlight (String): Best win of the week.
        - areaForImprovement (String): One constructive suggestion for next week.
        """

        return try await GeminiManager.shared.generateStructuredResponse(
            prompt: prompt,
            as: WeeklyReviewContent.self,
            temperature: 0.2,
            maxOutputTokens: 512
        )
    }

    private func generateNextWeekPlanContent(from data: PlanningData) async throws -> WeeklyActionPlan {
        let userId = SecurityUtils.getCurrentUserID()
        let provider = AIManager.shared.provider(for: .weeklyReview, userId: userId)

        if provider == .googleGemini3 {
            do {
                return try await generateGeminiNextWeekPlan(from: data)
            } catch {
                logger.error("Gemini weekly plan generation failed: \(error.localizedDescription). Falling back to heuristic plan.")
            }
        }

        return heuristicNextWeekPlan(from: data)
    }

    private func generateGeminiNextWeekPlan(from data: PlanningData) async throws -> WeeklyActionPlan {
        let dataJSON = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
        You are planning a practical productivity week in a task manager app.
        Use this user context:
        \(dataJSON)

        Return ONLY valid JSON with keys:
        - summary (String): One concise sentence.
        - reminders (Array): Planned tasks for next week.
          Each item must include:
          title (String), details (String or null), priority ("high"|"medium"|"low"|"none"),
          weekday (Int 1-7, Sunday=1), hour (Int 0-23), minute (Int 0-59),
          recurringPattern ("none"|"daily"|"weekly"|"weekdays")
        - focusBlocks (Array): Time blocks to protect.
          Each item must include:
          title (String), focusType ("work"|"study"|"creative"|"personal"|"reading"),
          weekday (Int 1-7), hour (Int 0-23), minute (Int 0-59), durationMinutes (Int)
        - habits (Array): Habit targets for next week.
          Each item must include:
          title (String), habitDescription (String or null), targetCount (Int),
          unit (String), frequency ("daily"|"weekly")

        Keep it realistic:
        - reminders: 3-8 items
        - focusBlocks: 2-6 items
        - habits: 1-5 items
        """

        return try await GeminiManager.shared.generateStructuredResponse(
            prompt: prompt,
            as: WeeklyActionPlan.self,
            temperature: 0.2,
            maxOutputTokens: 1400
        )
    }

    private func heuristicNextWeekPlan(from data: PlanningData) -> WeeklyActionPlan {
        var reminders: [WeeklyPlannedReminder] = []

        let defaultReminderSeed = data.topOpenTasks.isEmpty
            ? ["Review priorities", "Close one overdue task", "Prepare weekly outcomes"]
            : data.topOpenTasks

        for (index, title) in defaultReminderSeed.prefix(5).enumerated() {
            reminders.append(
                WeeklyPlannedReminder(
                    title: title,
                    details: "Planned from weekly review",
                    priority: index < 2 ? "high" : "medium",
                    weekday: 2 + index, // Monday onward
                    hour: 9 + min(index, 3),
                    minute: 0,
                    recurringPattern: "none"
                )
            )
        }

        reminders.append(
            WeeklyPlannedReminder(
                title: "Weekly Review",
                details: "Review wins, blockers, and plan forward",
                priority: "medium",
                weekday: 6, // Friday
                hour: 16,
                minute: 0,
                recurringPattern: "weekly"
            )
        )

        let focusBlocks = [
            WeeklyPlannedFocusBlock(
                title: "Deep Work Block",
                focusType: "work",
                weekday: 2,
                hour: 9,
                minute: 0,
                durationMinutes: 60
            ),
            WeeklyPlannedFocusBlock(
                title: "Execution Block",
                focusType: "work",
                weekday: 4,
                hour: 10,
                minute: 0,
                durationMinutes: 45
            ),
            WeeklyPlannedFocusBlock(
                title: "Creative Planning",
                focusType: "creative",
                weekday: 5,
                hour: 14,
                minute: 0,
                durationMinutes: 45
            )
        ]

        let habits: [WeeklyPlannedHabitTarget]
        if data.activeHabitTargets.isEmpty {
            habits = [
                WeeklyPlannedHabitTarget(
                    title: "Daily Planning Check-in",
                    habitDescription: "Review priorities and schedule the top task.",
                    targetCount: 1,
                    unit: "times",
                    frequency: "daily"
                )
            ]
        } else {
            habits = data.activeHabitTargets.prefix(3).map { snapshot in
                WeeklyPlannedHabitTarget(
                    title: snapshot.title,
                    habitDescription: "Keep momentum on \(snapshot.title) this week.",
                    targetCount: max(1, snapshot.targetCount),
                    unit: "times",
                    frequency: snapshot.frequency
                )
            }
        }

        let summary = "Planned \(reminders.count) tasks, \(focusBlocks.count) focus blocks, and \(habits.count) habit targets for next week."
        return WeeklyActionPlan(
            summary: summary,
            reminders: reminders,
            focusBlocks: focusBlocks,
            habits: habits
        )
    }
    
    private func generateFallbackContent() -> WeeklyReviewContent {
        return WeeklyReviewContent(
            grade: "B+",
            summary: "Solid week. You maintained consistency but had a few interruptions.",
            highlight: "Hit 4 hours of focus on Wednesday.",
            areaForImprovement: "Try to reduce interruptions in the afternoon."
        )
    }

    private func fallbackNextWeekPlan() -> WeeklyActionPlan {
        WeeklyActionPlan(
            summary: "Created a balanced week plan with focused work and habit consistency.",
            reminders: [
                WeeklyPlannedReminder(
                    title: "Top Priority Task",
                    details: "Complete your highest-impact task first.",
                    priority: "high",
                    weekday: 2,
                    hour: 9,
                    minute: 0,
                    recurringPattern: "none"
                ),
                WeeklyPlannedReminder(
                    title: "Weekly Review",
                    details: "Reflect and plan next steps.",
                    priority: "medium",
                    weekday: 6,
                    hour: 16,
                    minute: 0,
                    recurringPattern: "weekly"
                )
            ],
            focusBlocks: [
                WeeklyPlannedFocusBlock(
                    title: "Deep Work",
                    focusType: "work",
                    weekday: 3,
                    hour: 9,
                    minute: 0,
                    durationMinutes: 60
                )
            ],
            habits: [
                WeeklyPlannedHabitTarget(
                    title: "Daily Planning",
                    habitDescription: "Plan your top task for the day.",
                    targetCount: 1,
                    unit: "times",
                    frequency: "daily"
                )
            ]
        )
    }

    private func normalize(_ plan: WeeklyActionPlan) -> WeeklyActionPlan {
        let normalizedReminders = plan.reminders
            .prefix(12)
            .compactMap { item -> WeeklyPlannedReminder? in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }

                return WeeklyPlannedReminder(
                    title: String(title.prefix(120)),
                    details: item.details?.nilIfBlank,
                    priority: item.priority?.lowercased(),
                    weekday: max(1, min(7, item.weekday)),
                    hour: max(0, min(23, item.hour)),
                    minute: max(0, min(59, item.minute)),
                    recurringPattern: item.recurringPattern?.lowercased()
                )
            }

        let normalizedBlocks = plan.focusBlocks
            .prefix(8)
            .compactMap { block -> WeeklyPlannedFocusBlock? in
                let title = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }

                return WeeklyPlannedFocusBlock(
                    title: String(title.prefix(120)),
                    focusType: block.focusType.lowercased(),
                    weekday: max(1, min(7, block.weekday)),
                    hour: max(0, min(23, block.hour)),
                    minute: max(0, min(59, block.minute)),
                    durationMinutes: max(15, min(180, block.durationMinutes))
                )
            }

        let normalizedHabits = plan.habits
            .prefix(8)
            .compactMap { habit -> WeeklyPlannedHabitTarget? in
                let title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }

                return WeeklyPlannedHabitTarget(
                    title: String(title.prefix(120)),
                    habitDescription: habit.habitDescription?.nilIfBlank,
                    targetCount: max(1, habit.targetCount),
                    unit: habit.unit.nilIfBlank ?? "times",
                    frequency: (habit.frequency.nilIfBlank ?? "daily").lowercased()
                )
            }

        return WeeklyActionPlan(
            summary: plan.summary.nilIfBlank ?? "Next week plan generated.",
            reminders: normalizedReminders,
            focusBlocks: normalizedBlocks,
            habits: normalizedHabits
        )
    }

    private func startOfNextWeek(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .weekOfYear, value: 1, to: startOfThisWeek) ?? startOfThisWeek
    }

    private func nextWeekDate(
        startOfNextWeek: Date,
        weekday: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        let calendar = Calendar.current
        let normalizedWeekday = max(1, min(7, weekday))
        let weekStartWeekday = calendar.component(.weekday, from: startOfNextWeek)
        var offset = normalizedWeekday - weekStartWeekday
        if offset < 0 {
            offset += 7
        }

        let baseDay = calendar.date(byAdding: .day, value: offset, to: startOfNextWeek) ?? startOfNextWeek
        return calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: baseDay
        ) ?? baseDay
    }

    private func priority(from value: String?) -> Priority {
        switch value?.lowercased() {
        case "high", "urgent":
            return .high
        case "medium", "normal":
            return .medium
        case "low":
            return .low
        default:
            return .none
        }
    }

    private func recurrencePattern(from value: String?) -> RecurrencePattern {
        switch value?.lowercased() {
        case "daily":
            return .daily
        case "weekly":
            return .weekly
        case "weekdays":
            return .weekdays
        case "weekends":
            return .weekends
        case "monthly":
            return .monthly
        default:
            return .none
        }
    }

    private func focusType(from value: String) -> FocusType {
        switch value.lowercased() {
        case "work":
            return .work
        case "study":
            return .study
        case "creative":
            return .creative
        case "personal":
            return .personal
        case "exercise":
            return .exercise
        case "meditation":
            return .meditation
        case "reading":
            return .reading
        default:
            return .work
        }
    }

    private func habitFrequency(from value: String) -> HabitFrequency {
        switch value.lowercased() {
        case "weekly":
            return .weekly
        case "monthly":
            return .monthly
        default:
            return .daily
        }
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

struct WeeklyActionPlan: Codable, Equatable, Sendable {
    var summary: String
    var reminders: [WeeklyPlannedReminder]
    var focusBlocks: [WeeklyPlannedFocusBlock]
    var habits: [WeeklyPlannedHabitTarget]
}

struct WeeklyPlannedReminder: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var details: String?
    var priority: String?
    var weekday: Int
    var hour: Int
    var minute: Int
    var recurringPattern: String?

    enum CodingKeys: String, CodingKey {
        case title
        case details
        case priority
        case weekday
        case hour
        case minute
        case recurringPattern
    }
}

struct WeeklyPlannedFocusBlock: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var focusType: String
    var weekday: Int
    var hour: Int
    var minute: Int
    var durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case title
        case focusType
        case weekday
        case hour
        case minute
        case durationMinutes
    }
}

struct WeeklyPlannedHabitTarget: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var habitDescription: String?
    var targetCount: Int
    var unit: String
    var frequency: String

    enum CodingKeys: String, CodingKey {
        case title
        case habitDescription
        case targetCount
        case unit
        case frequency
    }
}

struct WeeklyPlanApplyResult: Sendable {
    var oneTimeRemindersCreated: Int
    var recurringRemindersCreated: Int
    var focusTemplatesCreated: Int
    var calendarBlocksCreated: Int
    var habitsCreated: Int
    var habitsUpdated: Int
    var weeklyFocusGoalConfigured: Bool

    static let empty = WeeklyPlanApplyResult(
        oneTimeRemindersCreated: 0,
        recurringRemindersCreated: 0,
        focusTemplatesCreated: 0,
        calendarBlocksCreated: 0,
        habitsCreated: 0,
        habitsUpdated: 0,
        weeklyFocusGoalConfigured: false
    )

    var summary: String {
        var parts: [String] = []
        if oneTimeRemindersCreated > 0 {
            parts.append("\(oneTimeRemindersCreated) reminders")
        }
        if recurringRemindersCreated > 0 {
            parts.append("\(recurringRemindersCreated) recurring plans")
        }
        if focusTemplatesCreated > 0 {
            parts.append("\(focusTemplatesCreated) focus templates")
        }
        if calendarBlocksCreated > 0 {
            parts.append("\(calendarBlocksCreated) calendar blocks")
        }
        if habitsCreated > 0 || habitsUpdated > 0 {
            parts.append("\(habitsCreated) habits created, \(habitsUpdated) updated")
        }
        if weeklyFocusGoalConfigured {
            parts.append("weekly focus goal configured")
        }

        if parts.isEmpty {
            return "No changes were applied."
        }

        return "Applied: " + parts.joined(separator: " • ")
    }
}

private enum WeeklyReviewAIError: Error {
    case parsingFailed
    case modelNotAvailable
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
