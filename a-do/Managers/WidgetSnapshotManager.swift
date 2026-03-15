import Foundation
import SwiftData
import WidgetKit
import os

@MainActor
final class WidgetSnapshotManager {
    static let shared = WidgetSnapshotManager()
    private let suiteName = "group.com.ado.app"
    private let remindersKey = "widget_reminders_v1"
    private let habitsKey = "widget_habits_v1"
    private let focusKey = "widget_focus_v1"
    private let timeTrackingKey = "widget_time_tracking_v1"
    private let updatedAtKey = "widget_snapshot_updated_at"
    private var pendingKinds: Set<WidgetSnapshotKind> = Set(WidgetSnapshotKind.allCases)
    private var pendingContainer: ModelContainer?
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func refreshSnapshots(
        context: ModelContext,
        kinds: Set<WidgetSnapshotKind>? = nil
    ) {
        pendingKinds.formUnion(kinds ?? defaultKinds)
        pendingContainer = context.container
        refreshTask?.cancel()

        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            guard let container = self.pendingContainer else { return }

            let kindsToRefresh = self.pendingKinds
            self.pendingKinds = []
            self.pendingContainer = nil

            let suiteName = self.suiteName
            let remindersKey = self.remindersKey
            let habitsKey = self.habitsKey
            let focusKey = self.focusKey
            let timeTrackingKey = self.timeTrackingKey
            let updatedAtKey = self.updatedAtKey

            Task.detached(priority: .utility) {
                Self.performRefresh(
                    container: container,
                    kinds: kindsToRefresh,
                    suiteName: suiteName,
                    remindersKey: remindersKey,
                    habitsKey: habitsKey,
                    focusKey: focusKey,
                    timeTrackingKey: timeTrackingKey,
                    updatedAtKey: updatedAtKey
                )
            }
        }
    }

    nonisolated private static func performRefresh(
        container: ModelContainer,
        kinds: Set<WidgetSnapshotKind>,
        suiteName: String,
        remindersKey: String,
        habitsKey: String,
        focusKey: String,
        timeTrackingKey: String,
        updatedAtKey: String
    ) {
        let logger = Logger(subsystem: "a-do", category: "WidgetSnapshots")
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let context = ModelContext(container)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if kinds.contains(.reminders) {
                let reminders = fetchReminderSnapshots(context: context)
                defaults.set(try encoder.encode(reminders), forKey: remindersKey)
            }

            if kinds.contains(.habits) {
                let habits = fetchHabitSnapshots(context: context)
                defaults.set(try encoder.encode(habits), forKey: habitsKey)
            }

            if kinds.contains(.focus) {
                let focus = fetchFocusSnapshot(context: context)
                defaults.set(try encoder.encode(focus), forKey: focusKey)
            }

            if kinds.contains(.timeTracking) {
                let timeTracking = fetchTimeTrackingSnapshot(context: context)
                defaults.set(try encoder.encode(timeTracking), forKey: timeTrackingKey)
            }

            defaults.set(Date(), forKey: updatedAtKey)

            if kinds.contains(.reminders) {
                WidgetCenter.shared.reloadTimelines(ofKind: "ReminderWidget")
            }

            if kinds.contains(.habits) {
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
            }

            if kinds.contains(.focus) {
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
            }

            if kinds.contains(.timeTracking) {
                WidgetCenter.shared.reloadTimelines(ofKind: "TimeTrackingWidget")
            }

            logger.info("Widget snapshots refreshed")
        } catch {
            logger.error("Failed to write widget snapshots: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated private static func fetchReminderSnapshots(context: ModelContext) -> [WidgetReminderSnapshot] {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        let reminders = (try? context.fetch(descriptor)) ?? []
        return reminders.map { reminder in
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

    nonisolated private static func fetchHabitSnapshots(context: ModelContext) -> [WidgetHabitSnapshot] {
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        let habits = (try? context.fetch(descriptor)) ?? []
        return habits.map { habit in
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

    nonisolated private static func fetchFocusSnapshot(context: ModelContext) -> WidgetFocusSnapshot {
        var activeSessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        activeSessionDescriptor.fetchLimit = 1
        let activeSession = (try? context.fetch(activeSessionDescriptor))?.first
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

        let todaySessionsDescriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= today && session.startTime < tomorrow
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let sessions = (try? context.fetch(todaySessionsDescriptor)) ?? []
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

    nonisolated private static func fetchTimeTrackingSnapshot(context: ModelContext) -> WidgetTimeTrackingSnapshot {
        var activeEntryDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        activeEntryDescriptor.fetchLimit = 1
        let activeEntry = (try? context.fetch(activeEntryDescriptor))?.first
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        let todayEntriesDescriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { entry in
                entry.startTime >= today && entry.startTime < tomorrow
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let todaysEntries = (try? context.fetch(todayEntriesDescriptor)) ?? []
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

    private var defaultKinds: Set<WidgetSnapshotKind> {
        [.reminders, .habits, .focus, .timeTracking]
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

enum WidgetSnapshotKind: CaseIterable, Hashable, Sendable {
    case reminders
    case habits
    case focus
    case timeTracking
}
