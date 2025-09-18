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
    
    // Timer management
    private var processingTimer: Timer?
    
    private init() {
        setupPeriodicProcessing()
    }
    
    deinit {
        // Note: Cannot access @MainActor properties in deinit
        // Timer cleanup will happen automatically when the object is deallocated
        // For explicit cleanup, call stopPeriodicProcessing() before deallocation
    }
    
    func stopPeriodicProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    // MARK: - Periodic Processing
    
    private func setupPeriodicProcessing() {
        // Set up timer to process recurring reminders
        processingTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processRecurringReminders()
            }
        }
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
        let defaultTemplates = [
            ReminderTemplate(
                name: "Daily Standup",
                title: "Daily team standup meeting",
                category: "Work"
            ),
            ReminderTemplate(
                name: "Weekly Review",
                title: "Review weekly goals and progress",
                category: "Personal"
            ),
            ReminderTemplate(
                name: "Take Medication",
                title: "Take daily medication",
                category: "Health"
            ),
            ReminderTemplate(
                name: "Water Plants",
                title: "Water indoor plants",
                category: "Home"
            ),
            ReminderTemplate(
                name: "Exercise",
                title: "Daily workout session",
                category: "Health"
            )
        ]
        
        for template in defaultTemplates {
            template.icon = "doc.text"
            template.colorHex = "#007AFF"
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
    
    func createReminderFromTemplate(_ template: ReminderTemplate, context: ModelContext) -> Reminder {
        let reminder = Reminder()
        reminder.title = template.title
        reminder.details = template.details
        reminder.priorityRaw = template.priority
        
        // Update template usage
        template.usageCount += 1
        template.lastUsed = Date()
        
        context.insert(reminder)
        
        do {
            try context.save()
            logger.info("Successfully created reminder from template: '\(template.name)' -> '\(reminder.title)'")
        } catch {
            logger.error("Failed to save reminder from template: \(error.localizedDescription)")
        }
        
        return reminder
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
    
    func processRecurringReminders() async {
        // This would be implemented with proper context handling
        logger.info("Processing recurring reminders...")
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Implementation would go here
        lastProcessingDate = Date()
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
    
    func generateRemindersForRecurring(_ recurring: RecurringReminder, context: ModelContext) {
        guard let rule = recurring.recurrenceRule,
              recurring.isActive else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Generate reminders for the next occurrence
        if let nextDate = rule.nextOccurrence(after: now) {
            let reminder = Reminder()
            reminder.title = recurring.templateTitle
            reminder.details = recurring.templateDetails
            reminder.priorityRaw = recurring.templatePriority
            reminder.dueDate = nextDate
            
            context.insert(reminder)
            recurring.generatedReminders?.append(reminder)
            recurring.lastGenerated = now
            
            try? context.save()
        }
    }
}
