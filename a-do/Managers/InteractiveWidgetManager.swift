//
//  InteractiveWidgetManager.swift
//  a-do
//
//  Interactive Widget Manager for iOS 26
//

import Foundation
import AppIntents
import WidgetKit
import Observation
import SwiftData
import os

@MainActor
@Observable
final class InteractiveWidgetManager {
    static let shared = InteractiveWidgetManager()

    private let logger = Logger(subsystem: "a-do", category: "InteractiveWidget")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseInteractiveWidgets
    }

    private init() {}

    // MARK: - Widget Updates

    func refreshAllWidgets() {
        refreshWidgets(kinds: Set(WidgetSnapshotKind.allCases), description: "all")
    }

    func refreshReminderWidgets() {
        refreshWidgets(kinds: [.reminders], description: "reminder")
    }

    func refreshFocusWidgets() {
        refreshWidgets(kinds: [.focus], description: "focus")
    }

    func refreshHabitWidgets() {
        refreshWidgets(kinds: [.habits], description: "habit")
    }

    func refreshTimeTrackingWidgets() {
        refreshWidgets(kinds: [.timeTracking], description: "time tracking")
    }

    private func refreshWidgets(kinds: Set<WidgetSnapshotKind>, description: String) {
        do {
            let context = try AppContainer.makeAppGroupContext()
            WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: kinds)
            logger.info("\(description, privacy: .public) widgets queued for refresh")
        } catch {
            logger.error("Failed to queue widget refresh: \(error.localizedDescription, privacy: .public)")
            if kinds.contains(.reminders) { WidgetCenter.shared.reloadTimelines(ofKind: "ReminderWidget") }
            if kinds.contains(.habits) { WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget") }
            if kinds.contains(.focus) { WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget") }
            if kinds.contains(.timeTracking) { WidgetCenter.shared.reloadTimelines(ofKind: "TimeTrackingWidget") }
        }
    }
}

// MARK: - App Intents for Widget Interactions

struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription("Mark a reminder as complete")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder ID")
    var reminderId: String

    init(reminderId: String) {
        self.reminderId = reminderId
    }

    init() {
        self.reminderId = ""
    }

    func perform() async throws -> some IntentResult {
        // Check Pro access
        guard await EntitlementManager.shared.canUseInteractiveWidgets else {
            return .result()
        }

        let context = try AppContainer.makeAppGroupContext()

        // Find and complete the reminder
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.uuid.uuidString == reminderId }
        )

        if let reminders = try? context.fetch(descriptor),
           let reminder = reminders.first {
            reminder.isCompleted = true
            reminder.completedAt = Date()

            try? context.save()

            // Refresh widgets
            await MainActor.run {
                InteractiveWidgetManager.shared.refreshReminderWidgets()
            }
        }

        return .result()
    }
}

struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Start a focus session")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Duration (minutes)")
    var durationMinutes: Int

    init(durationMinutes: Int) {
        self.durationMinutes = durationMinutes
    }

    init() {
        self.durationMinutes = 25
    }

    func perform() async throws -> some IntentResult {
        // This opens the app to start the focus session
        return .result()
    }
}

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as complete for today")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit ID")
    var habitId: String

    init(habitId: String) {
        self.habitId = habitId
    }

    init() {
        self.habitId = ""
    }

    func perform() async throws -> some IntentResult {
        // Check Pro access
        guard await EntitlementManager.shared.canUseInteractiveWidgets else {
            return .result()
        }

        let context = try AppContainer.makeAppGroupContext()

        // Find the habit
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id.uuidString == habitId }
        )

        if let habits = try? context.fetch(descriptor),
           let habit = habits.first {

            // Create habit entry for today
            let today = Calendar.current.startOfDay(for: Date())
            let entry = HabitEntry(
                date: today,
                count: 1,
                notes: "",
                habit: habit
            )

            context.insert(entry)
            try? context.save()

            // Refresh widgets
            await MainActor.run {
                InteractiveWidgetManager.shared.refreshHabitWidgets()
            }
        }

        return .result()
    }
}

struct StartTimeTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Time Tracking"
    static var description = IntentDescription("Start tracking time for a category")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Category")
    var category: String

    init(category: String) {
        self.category = category
    }

    init() {
        self.category = "Work"
    }

    func perform() async throws -> some IntentResult {
        // Check Pro access
        guard await EntitlementManager.shared.canUseInteractiveWidgets else {
            return .result()
        }

        // This would start time tracking
        // For now, just refresh widgets
        await MainActor.run {
            InteractiveWidgetManager.shared.refreshTimeTrackingWidgets()
        }

        return .result()
    }
}

struct StopTimeTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Time Tracking"
    static var description = IntentDescription("Stop the current time tracking session")
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        // Check Pro access
        guard await EntitlementManager.shared.canUseInteractiveWidgets else {
            return .result()
        }

        // This would stop time tracking
        // For now, just refresh widgets
        await MainActor.run {
            InteractiveWidgetManager.shared.refreshTimeTrackingWidgets()
        }

        return .result()
    }
}
