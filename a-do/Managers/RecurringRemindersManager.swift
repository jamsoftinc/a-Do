//
//  RecurringRemindersManager.swift
//  a-do
//
//  Manager for recurring reminders and templates
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class RecurringRemindersManager {
    static let shared = RecurringRemindersManager()
    
    private let logger = Logger(subsystem: "a-do", category: "RecurringReminders")
    
    // Processing state
    var isProcessing: Bool = false
    var lastProcessingDate: Date?
    private let processingInterval: TimeInterval = 3600
    
    private init() {}
    
    // MARK: - Lifecycle Processing

    func processRecurringRemindersIfNeeded(context: ModelContext, reason: String, force: Bool = false) async {
        let isStale = lastProcessingDate.map { Date().timeIntervalSince($0) >= processingInterval } ?? true
        guard force || isStale else { return }
        logger.info("Processing recurring reminders for \(reason, privacy: .public)")
        await processRecurringReminders(context: context)
    }
    
    // MARK: - Template Management
    
    func ensureDefaultTemplates(context: ModelContext) {
        let existingTemplates = try? context.fetch(FetchDescriptor<ReminderTemplate>())
        
        if existingTemplates?.isEmpty ?? true {
            logger.info("No templates found, creating default templates")
            createDefaultTemplates(context: context)
        } else {
            logger.info("Found \(existingTemplates?.count ?? 0) existing templates")
        }
    }
    
    private func createDefaultTemplates(context: ModelContext) {
        // Work templates
        let dailyStandup = ReminderTemplate(name: "Daily Standup", title: "Daily team standup meeting", category: "Work")
        dailyStandup.icon = "person.3.fill"
        dailyStandup.colorHex = "#5856D6"
        dailyStandup.details = "Discuss progress, blockers, and plans for the day"

        let weeklyReview = ReminderTemplate(name: "Weekly Review", title: "Review weekly goals and progress", category: "Work")
        weeklyReview.icon = "chart.bar.fill"
        weeklyReview.colorHex = "#007AFF"
        weeklyReview.details = "Review accomplishments, plan next week's priorities"

        let meetingPrep = ReminderTemplate(name: "Meeting Prep", title: "Prepare for upcoming meeting", category: "Work")
        meetingPrep.icon = "doc.text.fill"
        meetingPrep.colorHex = "#FF9500"
        meetingPrep.details = "Review agenda, prepare talking points, gather materials"

        // Health templates
        let takeMedication = ReminderTemplate(name: "Take Medication", title: "Take daily medication", category: "Health")
        takeMedication.icon = "pills.fill"
        takeMedication.colorHex = "#FF2D55"

        let exercise = ReminderTemplate(name: "Exercise", title: "Daily workout session", category: "Health")
        exercise.icon = "figure.run"
        exercise.colorHex = "#34C759"
        exercise.estimatedDuration = 45 * 60

        let drinkWater = ReminderTemplate(name: "Drink Water", title: "Stay hydrated - drink water", category: "Health")
        drinkWater.icon = "drop.fill"
        drinkWater.colorHex = "#5AC8FA"

        let meditation = ReminderTemplate(name: "Meditation", title: "Daily mindfulness meditation", category: "Health")
        meditation.icon = "brain.head.profile"
        meditation.colorHex = "#AF52DE"
        meditation.estimatedDuration = 15 * 60

        // Home templates
        let waterPlants = ReminderTemplate(name: "Water Plants", title: "Water indoor plants", category: "Home")
        waterPlants.icon = "leaf.fill"
        waterPlants.colorHex = "#30D158"

        let groceryShopping = ReminderTemplate(name: "Grocery Shopping", title: "Buy groceries for the week", category: "Home")
        groceryShopping.icon = "cart.fill"
        groceryShopping.colorHex = "#FF9500"

        let cleanHouse = ReminderTemplate(name: "Clean House", title: "Weekly house cleaning", category: "Home")
        cleanHouse.icon = "sparkles"
        cleanHouse.colorHex = "#64D2FF"

        // Personal templates
        let callFamily = ReminderTemplate(name: "Call Family", title: "Catch up with family", category: "Personal")
        callFamily.icon = "phone.fill"
        callFamily.colorHex = "#34C759"

        let readBook = ReminderTemplate(name: "Read Book", title: "Daily reading time", category: "Personal")
        readBook.icon = "book.fill"
        readBook.colorHex = "#FF9F0A"
        readBook.estimatedDuration = 30 * 60

        let journaling = ReminderTemplate(name: "Journaling", title: "Write in journal", category: "Personal")
        journaling.icon = "pencil.line"
        journaling.colorHex = "#BF5AF2"
        journaling.estimatedDuration = 15 * 60

        // Finance templates
        let payBills = ReminderTemplate(name: "Pay Bills", title: "Pay monthly bills", category: "Finance")
        payBills.icon = "creditcard.fill"
        payBills.colorHex = "#32ADE6"

        let budgetReview = ReminderTemplate(name: "Budget Review", title: "Review monthly budget", category: "Finance")
        budgetReview.icon = "dollarsign.circle.fill"
        budgetReview.colorHex = "#30D158"

        let defaultTemplates = [
            dailyStandup, weeklyReview, meetingPrep,
            takeMedication, exercise, drinkWater, meditation,
            waterPlants, groceryShopping, cleanHouse,
            callFamily, readBook, journaling,
            payBills, budgetReview
        ]

        for template in defaultTemplates {
            context.insert(template)
        }
        
        do {
            try context.save()
            logger.info("Successfully created \(defaultTemplates.count) default templates")
        } catch {
            logger.error("Failed to save default templates: \(error.localizedDescription)")
        }
    }
    
    func getPopularTemplates(context: ModelContext, limit: Int = 10) -> [ReminderTemplate] {
        let descriptor = FetchDescriptor<ReminderTemplate>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        
        let templates = (try? context.fetch(descriptor)) ?? []
        return Array(templates.prefix(limit))
    }
    
    func searchTemplates(query: String, context: ModelContext) -> [ReminderTemplate] {
        let descriptor = FetchDescriptor<ReminderTemplate>(
            predicate: #Predicate<ReminderTemplate> { template in
                template.name.localizedStandardContains(query) ||
                template.title.localizedStandardContains(query) ||
                template.category.localizedStandardContains(query)
            }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func createReminderFromTemplate(_ template: ReminderTemplate, context: ModelContext) async -> Reminder? {
        // Update template usage
        template.usageCount += 1
        template.lastUsed = Date()

        do {
            let reminder = try await ReminderCreationService.shared.createReminder(
                request: .init(
                    title: template.title,
                    details: template.details,
                    dueDate: nil,
                    priority: template.priorityEnum,
                    useNaturalLanguageParsing: false
                ),
                in: context
            )
            logger.info("Successfully created reminder from template: '\(template.name)' -> '\(reminder.title)'")
            return reminder
        } catch {
            logger.error("Failed to save reminder from template: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Recurring Reminders
    
    func createRecurringReminder(
        template: ReminderTemplate,
        pattern: RecurrencePattern,
        startDate: Date,
        endDate: Date? = nil,
        context: ModelContext
    ) -> RecurringReminder {
        let rule = RecurrenceRule()
        rule.pattern = pattern
        rule.endDate = endDate
        
        let recurring = RecurringReminder(
            title: template.title,
            details: template.details,
            priority: template.priorityEnum,
            recurrenceRule: rule
        )
        recurring.templateCategory = template.category
        recurring.isActive = true
        
        context.insert(rule)
        context.insert(recurring)
        try? context.save()
        
        return recurring
    }
    
    func processRecurringReminders(context: ModelContext? = nil) async {
        logger.info("Processing recurring reminders...")

        isProcessing = true
        defer {
            isProcessing = false
            lastProcessingDate = Date()
        }

        // Get context - if not provided, we need to get it from AppContainer
        let ctx: ModelContext
        if let context {
            ctx = context
        } else if let container = AppContainer.shared.getContainer() {
            ctx = ModelContext(container)
        } else {
            logger.error("Recurring reminder processing skipped because no SwiftData container is available")
            return
        }

        // Fetch all active recurring reminders
        let descriptor = FetchDescriptor<RecurringReminder>(
            predicate: #Predicate<RecurringReminder> { $0.isActive }
        )

        guard let recurringReminders = try? ctx.fetch(descriptor) else {
            logger.error("Failed to fetch recurring reminders")
            return
        }

        logger.info("Found \(recurringReminders.count) active recurring reminders to process")

        var generatedCount = 0

        for recurring in recurringReminders {
            // Check if we should generate a reminder
            if recurring.shouldGenerateReminder() {
                if let reminder = recurring.generateReminder() {
                    ctx.insert(reminder)
                    generatedCount += 1
                    logger.info("Generated reminder: '\(reminder.title)' due: \(reminder.dueDate?.description ?? "none")")

                    // Schedule notification for the reminder
                    if let dueDate = reminder.dueDate {
                        Task {
                            await NotificationManager.shared.scheduleNotification(
                                for: reminder,
                                at: dueDate
                            )
                        }
                    }
                }
            }

            // Update nextDue if needed
            recurring.calculateNextDue()
        }

        do {
            try ctx.save()
            logger.info("Successfully processed recurring reminders. Generated \(generatedCount) new reminders.")
        } catch {
            logger.error("Failed to save generated reminders: \(error.localizedDescription)")
        }
    }

    /// Generate future instances for a recurring reminder (look-ahead)
    func generateFutureInstances(
        for recurring: RecurringReminder,
        count: Int = 5,
        context: ModelContext
    ) -> [Reminder] {
        guard let rule = recurring.recurrenceRule, recurring.isActive else { return [] }

        var instances: [Reminder] = []
        var currentDate = Date()

        for _ in 0..<count {
            guard let nextDate = rule.nextOccurrence(after: currentDate) else { break }

            let reminder = Reminder(
                title: recurring.templateTitle,
                details: recurring.templateDetails,
                dueDate: nextDate,
                priority: recurring.priority
            )

            instances.append(reminder)
            currentDate = nextDate
        }

        return instances
    }

    /// Skip the next occurrence of a recurring reminder
    func skipNextOccurrence(_ recurring: RecurringReminder, context: ModelContext) {
        guard recurring.isActive else { return }

        // Move to the next occurrence without generating a reminder
        recurring.lastGenerated = recurring.nextDue ?? Date()
        recurring.calculateNextDue()

        do {
            try context.save()
            logger.info("Skipped next occurrence for '\(recurring.templateTitle)'")
        } catch {
            logger.error("Failed to skip occurrence: \(error.localizedDescription)")
        }
    }

    /// Pause a recurring reminder
    func pauseRecurring(_ recurring: RecurringReminder, context: ModelContext) {
        recurring.isActive = false

        do {
            try context.save()
            logger.info("Paused recurring reminder: '\(recurring.templateTitle)'")
        } catch {
            logger.error("Failed to pause recurring reminder: \(error.localizedDescription)")
        }
    }

    /// Resume a paused recurring reminder
    func resumeRecurring(_ recurring: RecurringReminder, context: ModelContext) {
        recurring.isActive = true
        recurring.calculateNextDue()

        do {
            try context.save()
            logger.info("Resumed recurring reminder: '\(recurring.templateTitle)'")
        } catch {
            logger.error("Failed to resume recurring reminder: \(error.localizedDescription)")
        }
    }
    
    func getRecurringReminderStats(context: ModelContext) -> (
        totalRecurringReminders: Int,
        totalGeneratedReminders: Int,
        upcomingRecurring: Int
    ) {
        let recurringCount = (try? context.fetchCount(FetchDescriptor<RecurringReminder>())) ?? 0
        
        // Calculate actual generated reminders count
        let allRecurring = (try? context.fetch(FetchDescriptor<RecurringReminder>())) ?? []
        let generatedCount = allRecurring.reduce(0) { $0 + ($1.generatedReminders?.count ?? 0) }
        
        // Calculate upcoming recurring reminders (next 7 days)
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let upcomingCount = allRecurring.filter { recurring in
            guard let nextDue = recurring.nextDue else { return false }
            return nextDue <= nextWeek && recurring.isActive
        }.count
        
        return (recurringCount, generatedCount, upcomingCount)
    }
    
    // MARK: - Reminder Generation
    
    func generateRemindersForRecurring(_ recurring: RecurringReminder, context: ModelContext) async {
        guard let rule = recurring.recurrenceRule,
              recurring.isActive else { return }
        
        let now = Date()
        
        // Generate reminders for the next occurrence
        if let nextDate = rule.nextOccurrence(after: now) {
            do {
                let reminder = try await ReminderCreationService.shared.createReminder(
                    request: .init(
                        title: recurring.templateTitle,
                        details: recurring.templateDetails,
                        dueDate: nextDate,
                        priority: recurring.priority,
                        useNaturalLanguageParsing: false
                    ),
                    in: context
                )
                recurring.generatedReminders?.append(reminder)
                recurring.lastGenerated = now
                try? context.save()
            } catch {
                logger.error("Failed to generate recurring reminder: \(error.localizedDescription)")
            }
        }
    }
}
