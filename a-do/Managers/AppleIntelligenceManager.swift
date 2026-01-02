//
//  AppleIntelligenceManager.swift
//  a-do
//
//  Coordinator for all Apple Intelligence features including:
//  - Foundation Models (on-device LLM)
//  - Visual Intelligence (camera-based search)
//  - Writing Tools (text enhancement)
//  - Siri Intelligence (enhanced shortcuts)
//
//  Requires: iOS 26+
//

import Foundation
import SwiftData
import Observation
import os
import FoundationModels

// MARK: - Apple Intelligence Feature Status

enum AppleIntelligenceFeature: String, CaseIterable {
    case foundationModels = "foundation_models"
    case visualIntelligence = "visual_intelligence"
    case writingTools = "writing_tools"
    case siriIntelligence = "siri_intelligence"
    case smartSuggestions = "smart_suggestions"
    case contextualActions = "contextual_actions"

    var displayName: String {
        switch self {
        case .foundationModels: return "On-Device AI"
        case .visualIntelligence: return "Visual Intelligence"
        case .writingTools: return "Writing Tools"
        case .siriIntelligence: return "Siri Intelligence"
        case .smartSuggestions: return "Smart Suggestions"
        case .contextualActions: return "Contextual Actions"
        }
    }

    var description: String {
        switch self {
        case .foundationModels:
            return "AI-powered task parsing, breakdown, and insights using Apple's on-device language model"
        case .visualIntelligence:
            return "Scan documents, business cards, and handwritten notes to create reminders"
        case .writingTools:
            return "Proofread, rewrite, and enhance your reminder descriptions"
        case .siriIntelligence:
            return "Enhanced Siri integration with context-aware responses"
        case .smartSuggestions:
            return "Intelligent suggestions for due dates, priorities, and tags"
        case .contextualActions:
            return "Context-aware quick actions based on your current activity"
        }
    }

    var icon: String {
        switch self {
        case .foundationModels: return "brain"
        case .visualIntelligence: return "eye"
        case .writingTools: return "pencil.and.outline"
        case .siriIntelligence: return "mic.badge.plus"
        case .smartSuggestions: return "sparkles"
        case .contextualActions: return "wand.and.stars"
        }
    }

    var minimumOS: String {
        return "iOS 26"
    }
}

// MARK: - Apple Intelligence Manager

@MainActor
@Observable
final class AppleIntelligenceManager {
    static let shared = AppleIntelligenceManager()

    private let logger = Logger(subsystem: "a-do", category: "AppleIntelligence")

    // Feature managers
    private(set) var foundationModels: FoundationModelsManager
    private(set) var visualIntelligence: VisualIntelligenceManager

    // State
    var isAppleIntelligenceAvailable: Bool = false
    var availableFeatures: Set<AppleIntelligenceFeature> = []
    var isInitialized: Bool = false
    var lastError: String?

    // Settings
    var isAppleIntelligenceEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAppleIntelligenceEnabled, forKey: "appleIntelligenceEnabled")
        }
    }

    private init() {
        self.foundationModels = FoundationModelsManager.shared
        self.visualIntelligence = VisualIntelligenceManager.shared
        self.isAppleIntelligenceEnabled = UserDefaults.standard.bool(forKey: "appleIntelligenceEnabled")

        Task {
            await initialize()
        }
    }

    // MARK: - Initialization

    func initialize() async {
        logger.info("Initializing Apple Intelligence for iOS 26...")

        // Check Foundation Models availability (device must support Apple Intelligence)
        await foundationModels.checkAvailability()
        if foundationModels.isAvailable {
            availableFeatures.insert(.foundationModels)
            isAppleIntelligenceAvailable = true
        }

        // All features are available on iOS 26
        availableFeatures.insert(.visualIntelligence)
        availableFeatures.insert(.writingTools)
        availableFeatures.insert(.siriIntelligence)
        availableFeatures.insert(.smartSuggestions)
        availableFeatures.insert(.contextualActions)

        isInitialized = true
        logger.info("Apple Intelligence initialized with \(self.availableFeatures.count) features available")
    }

    // MARK: - Pro Feature Check

    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // MARK: - Feature Availability

    func isFeatureAvailable(_ feature: AppleIntelligenceFeature) -> Bool {
        return availableFeatures.contains(feature)
    }

    func isFeatureEnabled(_ feature: AppleIntelligenceFeature) -> Bool {
        guard isAppleIntelligenceEnabled else { return false }
        guard isProEnabled else { return false }
        return isFeatureAvailable(feature)
    }

    // MARK: - Smart Task Creation

    /// Create a reminder using Apple Intelligence to parse natural language
    func createSmartReminder(
        from text: String,
        context: ModelContext
    ) async -> Reminder? {
        guard isFeatureEnabled(.foundationModels) else {
            // Fallback to basic parsing
            return await createBasicReminder(from: text, context: context)
        }

        logger.info("Creating smart reminder with Apple Intelligence")

        guard let parsed = await foundationModels.parseReminderText(text) else {
            return await createBasicReminder(from: text, context: context)
        }

        // Create reminder from parsed output
        let reminder = Reminder(title: parsed.title)

        // Set due date if parsed
        if let dueDateString = parsed.suggestedDueDate {
            reminder.dueDate = parseDateString(dueDateString)
        }

        // Set priority if parsed
        if let priorityString = parsed.priority?.lowercased() {
            switch priorityString {
            case "high": reminder.priority = .high
            case "medium": reminder.priority = .medium
            case "low": reminder.priority = .low
            default: break
            }
        }

        // Set notes if available
        if let notes = parsed.notes {
            reminder.details = notes
        }

        context.insert(reminder)

        do {
            try context.save()
            logger.info("Created smart reminder: \(parsed.title)")
            return reminder
        } catch {
            logger.error("Failed to save smart reminder: \(error.localizedDescription)")
            return nil
        }
    }

    private func createBasicReminder(from text: String, context: ModelContext) async -> Reminder? {
        let parsed = await NaturalLanguageProcessor.shared.parseReminderText(text)
        let reminder = Reminder(title: parsed.finalText, dueDate: parsed.dueDate)

        if parsed.priority != .none {
            reminder.priority = parsed.priority
        }

        context.insert(reminder)

        do {
            try context.save()
            return reminder
        } catch {
            logger.error("Failed to create basic reminder: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseDateString(_ dateString: String) -> Date? {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try relative dates
        let lowercased = dateString.lowercased()
        let calendar = Calendar.current

        switch lowercased {
        case "today":
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date())
        case "tomorrow":
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            }
        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: Date())
        default:
            break
        }

        return nil
    }

    // MARK: - Smart Task Breakdown

    /// Break down a complex task into subtasks using AI
    func breakdownTask(_ reminder: Reminder, context: ModelContext) async -> [Subtask]? {
        guard isFeatureEnabled(.foundationModels) else {
            logger.warning("Task breakdown requires Apple Intelligence")
            return nil
        }

        guard let breakdown = await foundationModels.generateTaskBreakdown(
            for: reminder.title,
            details: reminder.details
        ) else {
            return nil
        }

        var subtasks: [Subtask] = []

        for suggestion in breakdown.subtasks {
            let subtask = Subtask(title: suggestion.title, parentReminder: reminder)
            subtask.position = suggestion.order
            context.insert(subtask)
            subtasks.append(subtask)
        }

        // Link subtasks to the parent reminder
        if reminder.subtasks == nil {
            reminder.subtasks = subtasks
        } else {
            reminder.subtasks?.append(contentsOf: subtasks)
        }

        // Update original reminder with complexity info
        reminder.details = (reminder.details ?? "") + "\n\nComplexity: \(breakdown.complexity)\n\(breakdown.reasoning)"

        do {
            try context.save()
            logger.info("Created \(subtasks.count) subtasks for: \(reminder.title)")
            return subtasks
        } catch {
            logger.error("Failed to save subtasks: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Productivity Insights

    /// Generate AI-powered productivity insights
    func generateInsights(context: ModelContext) async -> ProductivityInsightOutput? {
        guard isFeatureEnabled(.foundationModels) else {
            return nil
        }

        // Gather data
        let reminderDescriptor = FetchDescriptor<Reminder>()
        let reminders = (try? context.fetch(reminderDescriptor)) ?? []

        let completedCount = reminders.filter { $0.isCompleted }.count
        let totalCount = reminders.count

        // Get focus time data
        let sessionDescriptor = FetchDescriptor<FocusSession>()
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let focusMinutes = Int(sessions.reduce(0.0) { $0 + $1.actualDuration } / 60.0)

        // Get habit data
        let habitDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        let habitCompletionRate = habits.isEmpty ? 0.0 : Double(habits.filter { $0.isCompletedToday }.count) / Double(habits.count)

        // Get top categories (from tags or lists)
        let topCategories = ["Work", "Personal", "Health"] // Simplified

        return await foundationModels.generateProductivityInsights(
            completedTasks: completedCount,
            totalTasks: totalCount,
            focusMinutes: focusMinutes,
            habitCompletionRate: habitCompletionRate,
            topCategories: topCategories
        )
    }

    // MARK: - Morning Briefing Integration

    /// Generate AI-enhanced morning briefing
    func generateMorningBriefing(context: ModelContext) async -> String? {
        guard isFeatureEnabled(.foundationModels) else {
            return nil
        }

        // Get today's reminders
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                !reminder.isCompleted &&
                reminder.dueDate != nil &&
                reminder.dueDate! >= startOfDay &&
                reminder.dueDate! < endOfDay
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )

        let reminders = (try? context.fetch(descriptor)) ?? []
        let reminderTitles = reminders.map { $0.title }

        guard let summary = await foundationModels.summarizeReminders(reminderTitles) else {
            return nil
        }

        // Format briefing
        var briefing = "Good morning! \(summary.briefSummary)\n\n"
        briefing += "Today's Focus:\n"
        for item in summary.actionItems.prefix(3) {
            briefing += "• \(item)\n"
        }
        briefing += "\nUrgency: \(summary.urgencyLevel.capitalized)"

        return briefing
    }

    // MARK: - Smart Scheduling

    /// Get AI suggestions for optimal task scheduling
    func suggestOptimalTime(
        for reminder: Reminder,
        existingEvents: [String],
        context: ModelContext
    ) async -> [TimeSlotSuggestion]? {
        guard isFeatureEnabled(.foundationModels) else {
            return nil
        }

        let estimatedMinutes = 30 // Default estimate
        let preferences = ["Morning person", "Prefer focused work before noon"]

        guard let schedule = await foundationModels.suggestSchedule(
            taskTitle: reminder.title,
            estimatedMinutes: estimatedMinutes,
            existingEvents: existingEvents,
            preferences: preferences
        ) else {
            return nil
        }

        return schedule.suggestedTimeSlots
    }

    // MARK: - Habit Optimization

    /// Get AI-powered habit optimization suggestions
    func optimizeHabit(_ habit: Habit) async -> HabitOptimizationOutput? {
        guard isFeatureEnabled(.foundationModels) else {
            return nil
        }

        let entries = habit.entries ?? []
        let completionTimes = entries.compactMap { entry -> String? in
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: entry.date)
        }

        return await foundationModels.optimizeHabit(
            habitTitle: habit.title,
            currentStreak: habit.currentStreak,
            completionTimes: Array(completionTimes.prefix(10)),
            relatedHabits: [] // Would come from habit analysis
        )
    }
}

// MARK: - Writing Tools Configuration

/// Custom configuration for Writing Tools behavior in the app
/// Note: SwiftUI provides its own WritingToolsBehavior type for the .writingToolsBehavior() modifier
enum AppWritingToolsConfig: String, CaseIterable {
    case automatic = "automatic"
    case limited = "limited"
    case disabled = "disabled"

    var displayName: String {
        switch self {
        case .automatic: return "Full Support"
        case .limited: return "Limited"
        case .disabled: return "Disabled"
        }
    }

    var description: String {
        switch self {
        case .automatic: return "All Writing Tools features enabled"
        case .limited: return "Basic proofreading only"
        case .disabled: return "Writing Tools disabled"
        }
    }
}

// MARK: - AppleIntelligenceManager Extensions

extension AppleIntelligenceManager {

    /// Get a human-readable status for Apple Intelligence
    var statusSummary: String {
        if !isAppleIntelligenceEnabled {
            return "Apple Intelligence is disabled"
        }
        if !isProEnabled {
            return "Upgrade to Pro to use Apple Intelligence"
        }
        if !isAppleIntelligenceAvailable {
            return "Apple Intelligence requires iOS 18+ and supported hardware"
        }
        return "Apple Intelligence is active (\(availableFeatures.count) features)"
    }

    /// Get device capability information
    var deviceCapabilities: String {
        var capabilities: [String] = []

        if foundationModels.isAvailable {
            capabilities.append("On-Device LLM")
        }

        if isFeatureAvailable(.visualIntelligence) {
            capabilities.append("Visual Intelligence")
        }

        if isFeatureAvailable(.writingTools) {
            capabilities.append("Writing Tools")
        }

        return capabilities.isEmpty ? "None available" : capabilities.joined(separator: ", ")
    }
}
