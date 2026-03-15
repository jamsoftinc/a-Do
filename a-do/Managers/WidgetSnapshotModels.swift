import Foundation

nonisolated struct WidgetReminderSnapshot: Codable, Sendable {
    var id: String
    var title: String
    var dueDate: Date?
    var priorityRaw: Int
    var isCompleted: Bool
    var hasLocation: Bool
    var hasVoice: Bool
    var tags: [String]
}

nonisolated struct WidgetHabitSnapshot: Codable, Sendable {
    var id: String
    var title: String
    var icon: String
    var color: String
    var currentStreak: Int
    var isCompletedToday: Bool
}

nonisolated struct WidgetFocusSnapshot: Codable, Sendable {
    var isActive: Bool
    var sessionName: String
    var remainingTime: TimeInterval
    var totalTime: TimeInterval
    var todaysSessions: Int
    var todaysFocusTime: TimeInterval
}

nonisolated struct WidgetTimeCategorySnapshot: Codable, Sendable {
    var category: String
    var duration: TimeInterval
}

nonisolated struct WidgetTimeTrackingSnapshot: Codable, Sendable {
    var isTracking: Bool
    var currentCategory: String
    var elapsedTime: TimeInterval
    var todaysTotal: TimeInterval
    var topCategories: [WidgetTimeCategorySnapshot]
}

nonisolated enum WidgetSnapshotKind: String, CaseIterable, Hashable, Sendable {
    case reminders
    case habits
    case focus
    case timeTracking
}
