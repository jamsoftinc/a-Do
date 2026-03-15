//
//  EnhancedSiriManager.swift
//  a-do
//
//  Enhanced Siri Integration for iOS 18+
//

import Foundation
import AppIntents
import SwiftData
import Observation
import os

@MainActor
@Observable
final class EnhancedSiriManager {
    static let shared = EnhancedSiriManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Siri")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseEnhancedSiri
    }
    
    private init() {}
    
    // MARK: - Helper Methods
    
    func getSharedModelContainer() throws -> ModelContainer {
        return try ModelContainer(
            for: Reminder.self, Habit.self, FocusSession.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.ado.app")
            )
        )
    }
}

// MARK: - Enhanced Siri App Intents

struct CreateComplexReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Smart Reminder"
    static var description = IntentDescription("Create a reminder with natural language")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Reminder Text", description: "Natural language description")
    var reminderText: String
    
    init(reminderText: String) {
        self.reminderText = reminderText
    }
    
    init() {
        self.reminderText = ""
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check Pro access
        guard await EntitlementManager.shared.canUseEnhancedSiri else {
            return .result(dialog: "Enhanced Siri features require Pro subscription")
        }
        
        // Parse with NLP
        let parsed = await NaturalLanguageProcessor.shared.parseReminderText(reminderText)
        
        let context = try AppContainer.makeAppGroupContext()
        let reminder = try await ReminderCreationService.shared.createReminder(
            request: .init(
                title: parsed.title ?? parsed.baseText,
                details: nil,
                dueDate: parsed.dueDate,
                priority: parsed.priority,
                useNaturalLanguageParsing: false
            ),
            in: context
        )

        let dueDateText = parsed.dueDate != nil ? " for \(formatDate(parsed.dueDate!))" : ""
        return .result(dialog: "Created reminder '\(reminder.title)'\(dueDateText)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct GetTodayRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "What do I have today?"
    static var description = IntentDescription("Get your reminders for today")
    static var openAppWhenRun: Bool = false
    
    init() {}
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check Pro access
        guard await EntitlementManager.shared.canUseEnhancedSiri else {
            return .result(dialog: "Enhanced Siri features require Pro subscription")
        }
        
        // Get shared model container
        let container = try ModelContainer(
            for: Reminder.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.ado.app")
            )
        )
        let context = ModelContext(container)
        
        // Get today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch all incomplete reminders, then filter manually
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                !reminder.isCompleted
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        let allReminders = try context.fetch(descriptor)

        // Filter for today's reminders
        let reminders = allReminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay
        }

        if reminders.isEmpty {
            return .result(dialog: "You have no reminders for today")
        }

        let count = reminders.count
        guard let firstReminder = reminders.first?.title else {
            return .result(dialog: "You have no reminders for today")
        }

        if count == 1 {
            return .result(dialog: "You have 1 reminder today: \(firstReminder)")
        } else {
            return .result(dialog: "You have \(count) reminders today. First one is: \(firstReminder)")
        }
    }
}

struct StartFocusSessionSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Start a focus session")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Duration", description: "Session duration in minutes")
    var duration: Int
    
    @Parameter(title: "Session Name")
    var sessionName: String?
    
    init(duration: Int, sessionName: String? = nil) {
        self.duration = duration
        self.sessionName = sessionName
    }
    
    init() {
        self.duration = 25
        self.sessionName = nil
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check Pro access
        guard await EntitlementManager.shared.canUseEnhancedSiri else {
            return .result(dialog: "Enhanced Siri features require Pro subscription")
        }
        
        // Get shared model container
        let container = try ModelContainer(
            for: FocusSession.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.ado.app")
            )
        )
        let context = ModelContext(container)
        
        // Create focus session
        let session = FocusSession(
            name: sessionName ?? "Focus Session",
            duration: TimeInterval(duration * 60)
        )
        session.isActive = true

        context.insert(session)
        try context.save()

        let sessionID = session.id
        let sessionDisplayName = session.name
        let remainingTime = session.remainingTime
        let totalTime = session.plannedDuration
        let isActive = session.isActive

        await MainActor.run {
            LiveActivityManager.shared.startFocusSessionActivity(
                sessionID: sessionID,
                name: sessionDisplayName,
                remainingTime: remainingTime,
                totalTime: totalTime,
                isActive: isActive
            )
        }
        
        return .result(dialog: "Started \(duration) minute focus session")
    }
}

struct CompleteReminderSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription("Mark a reminder as complete")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Reminder Title")
    var reminderTitle: String
    
    init(reminderTitle: String) {
        self.reminderTitle = reminderTitle
    }
    
    init() {
        self.reminderTitle = ""
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Check Pro access
        guard await EntitlementManager.shared.canUseEnhancedSiri else {
            return .result(dialog: "Enhanced Siri features require Pro subscription")
        }
        
        // Get shared model container
        let container = try ModelContainer(
            for: Reminder.self,
            configurations: ModelConfiguration(
                groupContainer: .identifier("group.com.ado.app")
            )
        )
        let context = ModelContext(container)
        
        // Find reminder by title (case-insensitive)
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { reminder in
                !reminder.isCompleted &&
                reminder.title.localizedStandardContains(reminderTitle)
            }
        )
        
        let reminders = try context.fetch(descriptor)
        
        guard let reminder = reminders.first else {
            return .result(dialog: "I couldn't find a reminder matching '\(reminderTitle)'")
        }
        
        // Mark as complete
        reminder.isCompleted = true
        reminder.completedAt = Date()
        try context.save()
        
        return .result(dialog: "Completed '\(reminder.title)'")
    }
}

// MARK: - Siri Shortcuts Provider

struct ADOAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayRemindersIntent(),
            phrases: [
                "What do I have today in \(.applicationName)",
                "Show my reminders in \(.applicationName)",
                "What's on my list in \(.applicationName)"
            ],
            shortTitle: "Today's Reminders",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: StartFocusSessionSiriIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Begin focus session in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "target"
        )

        // Visual Intelligence shortcuts
        AppShortcut(
            intent: SearchRemindersVisually(),
            phrases: [
                "Search \(.applicationName) for this",
                "Find reminders like this in \(.applicationName)",
                "Look up this in \(.applicationName)"
            ],
            shortTitle: "Search Reminders",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: CreateReminderFromVisual(),
            phrases: [
                "Create reminder from this in \(.applicationName)",
                "Add this to \(.applicationName)",
                "Make a reminder in \(.applicationName) from this"
            ],
            shortTitle: "Create from Visual",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ScanBusinessCardIntent(),
            phrases: [
                "Scan business card with \(.applicationName)",
                "Add contact from card in \(.applicationName)"
            ],
            shortTitle: "Scan Business Card",
            systemImageName: "person.crop.rectangle"
        )

        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan document for tasks with \(.applicationName)",
                "Extract tasks from this document in \(.applicationName)"
            ],
            shortTitle: "Scan Document",
            systemImageName: "doc.text.viewfinder"
        )
    }
}
