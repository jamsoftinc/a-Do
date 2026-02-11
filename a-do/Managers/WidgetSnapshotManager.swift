import Foundation
import SwiftData
import WidgetKit
import os

@MainActor
final class WidgetSnapshotManager {
    static let shared = WidgetSnapshotManager()

    private let logger = Logger(subsystem: "a-do", category: "WidgetSnapshots")
    private let suiteName = "group.com.ado.app"
    private let remindersKey = "widget_reminders_v1"
    private let habitsKey = "widget_habits_v1"
    private let focusKey = "widget_focus_v1"
    private let timeTrackingKey = "widget_time_tracking_v1"
    private let updatedAtKey = "widget_snapshot_updated_at"

    private init() {}

    func refreshSnapshots(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let reminders = fetchReminderSnapshots(context: context)
        let habits = fetchHabitSnapshots(context: context)
        let focus = fetchFocusSnapshot(context: context)
        let timeTracking = fetchTimeTrackingSnapshot(context: context)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            defaults.set(try encoder.encode(reminders), forKey: remindersKey)
            defaults.set(try encoder.encode(habits), forKey: habitsKey)
            defaults.set(try encoder.encode(focus), forKey: focusKey)
            defaults.set(try encoder.encode(timeTracking), forKey: timeTrackingKey)
            defaults.set(Date(), forKey: updatedAtKey)

            WidgetCenter.shared.reloadTimelines(ofKind: "ReminderWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "TimeTrackingWidget")
            logger.info("Widget snapshots refreshed")
        } catch {
            logger.error("Failed to write widget snapshots: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchReminderSnapshots(context: ModelContext) -> [WidgetReminderSnapshot] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.createdAt, order: .reverse)]
        )

        let reminders = (try? context.fetch(descriptor)) ?? []
        return reminders.prefix(20).map { reminder in
            WidgetReminderSnapshot(
                id: reminder.uuid.uuidString,
                title: reminder.title,
                dueDate: reminder.dueDate,
                priorityRaw: reminder.priorityRaw,
                isCompleted: reminder.isCompleted,
                hasLocation: reminder.locationTrigger != nil,
                hasVoice: reminder.voiceReminder != nil,
                tags: reminder.tags?.map(\.name) ?? []
            )
        }
    }

    private func fetchHabitSnapshots(context: ModelContext) -> [WidgetHabitSnapshot] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        let habits = (try? context.fetch(descriptor)) ?? []
        return habits.prefix(20).map { habit in
            WidgetHabitSnapshot(
                id: habit.id.uuidString,
                title: habit.title,
                icon: habit.icon,
                color: habit.color,
                currentStreak: habit.currentStreak,
                isCompletedToday: habit.isCompletedToday
            )
        }
    }

    private func fetchFocusSnapshot(context: ModelContext) -> WidgetFocusSnapshot {
        let allSessionsDescriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let sessions = (try? context.fetch(allSessionsDescriptor)) ?? []

        let activeSession = sessions.first(where: { $0.isActive })
        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return WidgetFocusSnapshot(
                isActive: false,
                sessionName: "Focus",
                remainingTime: 0,
                totalTime: 0,
                todaysSessions: 0,
                todaysFocusTime: 0
            )
        }

        let todaysSessions = sessions.filter { $0.startTime >= today && $0.startTime < tomorrow }
        let todaysFocusTime = todaysSessions.reduce(0.0) { $0 + $1.actualDuration }

        return WidgetFocusSnapshot(
            isActive: activeSession != nil,
            sessionName: activeSession?.name ?? "Focus",
            remainingTime: activeSession?.remainingTime ?? 0,
            totalTime: activeSession?.plannedDuration ?? 0,
            todaysSessions: todaysSessions.count,
            todaysFocusTime: todaysFocusTime
        )
    }

    private func fetchTimeTrackingSnapshot(context: ModelContext) -> WidgetTimeTrackingSnapshot {
        let descriptor = FetchDescriptor<TimeEntry>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []

        let activeEntry = entries.first(where: { $0.isRunning })
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        let todaysEntries = entries.filter { $0.startTime >= today && $0.startTime < tomorrow }
        let todaysTotal = todaysEntries.reduce(0.0) { $0 + $1.actualDuration }

        var categoryTotals: [String: TimeInterval] = [:]
        for entry in todaysEntries {
            categoryTotals[entry.category, default: 0] += entry.actualDuration
        }
        let topCategories = categoryTotals
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { WidgetTimeCategorySnapshot(category: $0.key, duration: $0.value) }

        return WidgetTimeTrackingSnapshot(
            isTracking: activeEntry != nil,
            currentCategory: activeEntry?.category ?? "Work",
            elapsedTime: activeEntry?.actualDuration ?? 0,
            todaysTotal: todaysTotal,
            topCategories: topCategories
        )
    }
}

struct WidgetReminderSnapshot: Codable {
    var id: String
    var title: String
    var dueDate: Date?
    var priorityRaw: Int
    var isCompleted: Bool
    var hasLocation: Bool
    var hasVoice: Bool
    var tags: [String]
}

struct WidgetHabitSnapshot: Codable {
    var id: String
    var title: String
    var icon: String
    var color: String
    var currentStreak: Int
    var isCompletedToday: Bool
}

struct WidgetFocusSnapshot: Codable {
    var isActive: Bool
    var sessionName: String
    var remainingTime: TimeInterval
    var totalTime: TimeInterval
    var todaysSessions: Int
    var todaysFocusTime: TimeInterval
}

struct WidgetTimeCategorySnapshot: Codable {
    var category: String
    var duration: TimeInterval
}

struct WidgetTimeTrackingSnapshot: Codable {
    var isTracking: Bool
    var currentCategory: String
    var elapsedTime: TimeInterval
    var todaysTotal: TimeInterval
    var topCategories: [WidgetTimeCategorySnapshot]
}
