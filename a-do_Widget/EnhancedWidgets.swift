//
//  EnhancedWidgets.swift
//  a-do_Widget
//
//  Enhanced widget configurations and types
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Shared Types

// Helper function to check Pro status from shared UserDefaults
func isProUser() -> Bool {
    guard let sharedDefaults = UserDefaults(suiteName: "group.com.ado.app") else {
        return false
    }
    return sharedDefaults.bool(forKey: "isProUser")
}

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - App Intents
import AppIntents

struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Reminder"
    static var description = IntentDescription("Mark a reminder as complete")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Reminder ID")
    var reminderId: String

    init(reminderId: String) {
        self.reminderId = reminderId
    }

    init() {
        self.reminderId = ""
    }

    func perform() async throws -> some IntentResult {
        // Opens the app to complete the reminder
        return .result()
    }
}

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as complete for today")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Habit ID")
    var habitId: String

    init(habitId: String) {
        self.habitId = habitId
    }

    init() {
        self.habitId = ""
    }

    func perform() async throws -> some IntentResult {
        // Opens the app to complete the habit
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
        // Opens the app to start the focus session
        return .result()
    }
}

struct StartTimeTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Time Tracking"
    static var description = IntentDescription("Start tracking time for a category")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Category")
    var category: String

    init(category: String) {
        self.category = category
    }

    init() {
        self.category = "Work"
    }

    func perform() async throws -> some IntentResult {
        // Opens the app to start time tracking
        return .result()
    }
}

struct StopTimeTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Time Tracking"
    static var description = IntentDescription("Stop the current time tracking session")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        // Opens the app to stop time tracking
        return .result()
    }
}

// MARK: - Reminder Widget
struct ReminderWidget: Widget {
    let kind: String = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Reminders")
        .description("View your upcoming reminders and tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: Date(), reminders: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> ()) {
        let entry = ReminderEntry(date: Date(), reminders: fetchReminders())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> ()) {
        let currentDate = Date()

        // Check Pro status
        if !isProUser() {
            // Show upgrade message for free users
            let upgradeReminders = [
                ReminderData(
                    id: "upgrade",
                    title: "Widgets are a Pro feature",
                    dueDate: nil,
                    priority: .none,
                    isCompleted: false,
                    hasLocation: false,
                    hasVoice: false,
                    tags: []
                )
            ]
            let entry = ReminderEntry(date: currentDate, reminders: upgradeReminders)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        let reminders = fetchReminders()
        let entry = ReminderEntry(date: currentDate, reminders: reminders)

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchReminders() -> [ReminderData] {
        guard
            let defaults = UserDefaults(suiteName: "group.com.ado.app"),
            let rawData = defaults.data(forKey: "widget_reminders_v1")
        else {
            return fallbackReminders()
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try decoder.decode([ReminderSnapshot].self, from: rawData)
            let mapped = snapshots.map { snapshot in
                ReminderData(
                    id: snapshot.id,
                    title: snapshot.title,
                    dueDate: snapshot.dueDate,
                    priority: Priority(rawValue: snapshot.priorityRaw) ?? .none,
                    isCompleted: snapshot.isCompleted,
                    hasLocation: snapshot.hasLocation,
                    hasVoice: snapshot.hasVoice,
                    tags: snapshot.tags
                )
            }
            return mapped.isEmpty ? fallbackReminders() : mapped
        } catch {
            return fallbackReminders()
        }
    }

    private func fallbackReminders() -> [ReminderData] {
        return []
    }
}

private struct ReminderSnapshot: Codable {
    let id: String
    let title: String
    let dueDate: Date?
    let priorityRaw: Int
    let isCompleted: Bool
    let hasLocation: Bool
    let hasVoice: Bool
    let tags: [String]
}

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderData]
}

struct ReminderData {
    let id: String
    let title: String
    let dueDate: Date?
    let priority: Priority
    let isCompleted: Bool
    let hasLocation: Bool
    let hasVoice: Bool
    let tags: [String]
}

struct ReminderWidgetEntryView: View {
    var entry: ReminderProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallReminderWidget(entry: entry)
        case .systemMedium:
            MediumReminderWidget(entry: entry)
        case .systemLarge:
            LargeReminderWidget(entry: entry)
        default:
            SmallReminderWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget
struct SmallReminderWidget: View {
    let entry: ReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "Reminders", icon: "checkmark.circle.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8))

            if entry.reminders.isEmpty {
                EmptyWidgetView(message: "All done!", icon: "checkmark.circle.fill", color: Color(red: 0.2, green: 0.7, blue: 0.3))
            } else {
                let nextReminder = entry.reminders.first!
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Capsule()
                            .fill(priorityColor(nextReminder.priority))
                            .frame(width: 3, height: 16)
                        
                        Text(nextReminder.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                    }

                    if let dueDate = nextReminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(dueDate, style: .relative)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.leading, 9)
                    }

                    Spacer(minLength: 0)

                    if entry.reminders.count > 1 {
                        Text("+\(entry.reminders.count - 1) more")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .medium: return Color(red: 0.9, green: 0.6, blue: 0.2)
        case .low: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .none: return .gray
        }
    }
}

// MARK: - Medium Widget
struct MediumReminderWidget: View {
    let entry: ReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                WidgetHeader(title: "Reminders", icon: "checkmark.circle.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8))
                
                if !entry.reminders.isEmpty {
                    Text("\(entry.reminders.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if entry.reminders.isEmpty {
                EmptyWidgetView(message: "All caught up!", icon: "checkmark.seal.fill", color: Color(red: 0.2, green: 0.7, blue: 0.3))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entry.reminders.prefix(3).enumerated()), id: \.offset) { index, reminder in
                        ReminderRowWidget(reminder: reminder)
                    }
                }
            }
        }
    }
}

// MARK: - Large Widget
struct LargeReminderWidget: View {
    let entry: ReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                WidgetHeader(title: "Reminders", icon: "checkmark.circle.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8))
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.reminders.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                    Text("pending")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            if entry.reminders.isEmpty {
                EmptyWidgetView(message: "All caught up!", icon: "checkmark.seal.fill", color: Color(red: 0.2, green: 0.7, blue: 0.3))
            } else {
                // Priority breakdown
                let breakdown = calculatePriorityBreakdown(entry.reminders)
                
                HStack(spacing: 12) {
                    PriorityIndicator(count: breakdown.high, color: Color(red: 0.9, green: 0.3, blue: 0.3), label: "HIGH")
                    PriorityIndicator(count: breakdown.medium, color: Color(red: 0.9, green: 0.6, blue: 0.2), label: "MED")
                    PriorityIndicator(count: breakdown.low, color: Color(red: 0.2, green: 0.8, blue: 0.4), label: "LOW")
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(Array(entry.reminders.prefix(6).enumerated()), id: \.offset) { index, reminder in
                        ReminderRowWidget(reminder: reminder, showDetails: true)
                    }
                }
            }
        }
    }
    private func calculatePriorityBreakdown(_ reminders: [ReminderData]) -> (high: Int, medium: Int, low: Int) {
        let high = reminders.filter { $0.priority == .high }.count
        let medium = reminders.filter { $0.priority == .medium }.count
        let low = reminders.filter { $0.priority == .low }.count
        return (high, medium, low)
    }
}

struct PriorityIndicator: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                Circle()
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .frame(width: 24, height: 24)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.trailing, 4)
    }
}

struct ReminderRowWidget: View {
    let reminder: ReminderData
    var showDetails: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Interactive completion button
            Button(intent: CompleteReminderIntent(reminderId: reminder.id)) {
                ZStack {
                    Circle()
                        .strokeBorder(reminder.isCompleted ? Color.green : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .background(reminder.isCompleted ? Circle().fill(Color.green.opacity(0.15)) : nil)
                    
                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(priorityColor(reminder.priority))
                        .frame(width: 3, height: 12)
                    
                    Text(reminder.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                }

                if showDetails {
                    HStack(spacing: 8) {
                        if let dueDate = reminder.dueDate {
                            Label(dueDate.formatted(.dateTime.hour().minute()), systemImage: "clock")
                                .font(.system(size: 9, weight: .medium))
                        }

                        if reminder.hasLocation {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                        }

                        if reminder.hasVoice {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                        }

                        if let tag = reminder.tags.first {
                            Text(tag)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.leading, 9)
                }
            }

            Spacer()

            if let dueDate = reminder.dueDate, !showDetails {
                Text(dueDate, style: .time)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetCardStyle()
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .none: return .gray
        }
    }
}

// MARK: - Focus Session Widget
struct FocusWidget: Widget {
    let kind: String = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Sessions")
        .description("Track your focus sessions and productivity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(
            date: Date(),
            isActive: false,
            sessionName: "",
            remainingTime: 0,
            totalTime: 0,
            todaysSessions: 0,
            todaysFocusTime: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> ()) {
        let entry = fetchFocusEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> ()) {
        let currentDate = Date()

        // Check Pro status
        if !isProUser() {
            // Show upgrade message for free users
            let entry = FocusEntry(
                date: currentDate,
                isActive: false,
                sessionName: "Pro Feature",
                remainingTime: 0,
                totalTime: 0,
                todaysSessions: 0,
                todaysFocusTime: 0
            )
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        let entry = fetchFocusEntry(date: currentDate)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchFocusEntry(date: Date) -> FocusEntry {
        guard
            let defaults = UserDefaults(suiteName: "group.com.ado.app"),
            let rawData = defaults.data(forKey: "widget_focus_v1"),
            let snapshot = try? JSONDecoder().decode(FocusSnapshot.self, from: rawData)
        else {
            return FocusEntry(
                date: date,
                isActive: false,
                sessionName: "",
                remainingTime: 0,
                totalTime: 0,
                todaysSessions: 0,
                todaysFocusTime: 0
            )
        }

        return FocusEntry(
            date: date,
            isActive: snapshot.isActive,
            sessionName: snapshot.sessionName,
            remainingTime: snapshot.remainingTime,
            totalTime: snapshot.totalTime,
            todaysSessions: snapshot.todaysSessions,
            todaysFocusTime: snapshot.todaysFocusTime
        )
    }
}

struct FocusEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let sessionName: String
    let remainingTime: TimeInterval
    let totalTime: TimeInterval
    let todaysSessions: Int
    let todaysFocusTime: TimeInterval
}

struct FocusWidgetEntryView: View {
    var entry: FocusProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFocusWidget(entry: entry)
        case .systemMedium:
            MediumFocusWidget(entry: entry)
        default:
            SmallFocusWidget(entry: entry)
        }
    }
}

struct SmallFocusWidget: View {
    let entry: FocusEntry

    var body: some View {
        VStack(spacing: 12) {
            WidgetHeader(title: "Focus", icon: "target", color: Color(red: 0.4, green: 0.2, blue: 0.8))

            if entry.sessionName == "Pro Feature" {
                EmptyWidgetView(message: "Focus is a Pro Feature", icon: "star.fill", color: Color(red: 0.9, green: 0.4, blue: 0.6))
            } else if entry.isActive {
                VStack(spacing: 8) {
                    Text(formatTime(entry.remainingTime))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))

                    Text("remaining")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ProgressView(value: 1.0 - (entry.remainingTime / entry.totalTime))
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.8)))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(entry.todaysSessions)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                        Text("SESSIONS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                    Text(formatTime(entry.todaysFocusTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    WidgetActionButton(title: "Start", icon: "play.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8), intent: StartFocusSessionIntent(durationMinutes: 25))
                }
            }
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MediumFocusWidget: View {
    let entry: FocusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                WidgetHeader(title: "Focus Sessions", icon: "target", color: Color(red: 0.4, green: 0.2, blue: 0.8))

                if entry.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if entry.sessionName == "Pro Feature" {
                EmptyWidgetView(message: "Focus is a Pro Feature", icon: "star.fill", color: .orange)
            } else if entry.isActive {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.sessionName)
                            .font(.system(size: 15, weight: .bold))
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatTime(entry.remainingTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                            Text("left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                    
                    Spacer()
                    
                    CircularProgressView(
                        progress: 1.0 - (entry.remainingTime / entry.totalTime),
                        color: Color(red: 0.4, green: 0.2, blue: 0.8)
                    )
                    .frame(width: 50, height: 50)
                }
                .widgetCardStyle()
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(entry.todaysSessions)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.8))
                            Text("SESSIONS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text(formatTime(entry.todaysFocusTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.6))
                            Text("FOCUS TIME")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        WidgetActionButton(title: "25 min", icon: "play.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8), intent: StartFocusSessionIntent(durationMinutes: 25))
                        WidgetActionButton(title: "50 min", icon: "play.fill", color: Color(red: 0.9, green: 0.4, blue: 0.6), intent: StartFocusSessionIntent(durationMinutes: 50))
                        Spacer()
                    }
                }
            }
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: 2)
        }
    }
}

// MARK: - Time Tracking Widget
struct TimeTrackingWidget: Widget {
    let kind: String = "TimeTrackingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeTrackingProvider()) { entry in
            TimeTrackingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Tracking")
        .description("Monitor your time tracking and productivity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimeTrackingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeTrackingEntry {
        TimeTrackingEntry(
            date: Date(),
            isTracking: false,
            currentCategory: "",
            elapsedTime: 0,
            todaysTotal: 0,
            topCategories: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeTrackingEntry) -> ()) {
        let entry = fetchTimeEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeTrackingEntry>) -> ()) {
        let currentDate = Date()

        // Check Pro status
        if !isProUser() {
            // Show upgrade message for free users
            let entry = TimeTrackingEntry(
                date: currentDate,
                isTracking: false,
                currentCategory: "Pro Feature",
                elapsedTime: 0,
                todaysTotal: 0,
                topCategories: []
            )
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        let entry = fetchTimeEntry(date: currentDate)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchTimeEntry(date: Date) -> TimeTrackingEntry {
        guard
            let defaults = UserDefaults(suiteName: "group.com.ado.app"),
            let rawData = defaults.data(forKey: "widget_time_tracking_v1"),
            let snapshot = try? JSONDecoder().decode(TimeTrackingSnapshot.self, from: rawData)
        else {
            return TimeTrackingEntry(
                date: date,
                isTracking: false,
                currentCategory: "",
                elapsedTime: 0,
                todaysTotal: 0,
                topCategories: []
            )
        }

        return TimeTrackingEntry(
            date: date,
            isTracking: snapshot.isTracking,
            currentCategory: snapshot.currentCategory,
            elapsedTime: snapshot.elapsedTime,
            todaysTotal: snapshot.todaysTotal,
            topCategories: snapshot.topCategories.map { ($0.category, $0.duration) }
        )
    }
}

private struct FocusSnapshot: Codable {
    let isActive: Bool
    let sessionName: String
    let remainingTime: TimeInterval
    let totalTime: TimeInterval
    let todaysSessions: Int
    let todaysFocusTime: TimeInterval
}

private struct TimeCategorySnapshot: Codable {
    let category: String
    let duration: TimeInterval
}

private struct TimeTrackingSnapshot: Codable {
    let isTracking: Bool
    let currentCategory: String
    let elapsedTime: TimeInterval
    let todaysTotal: TimeInterval
    let topCategories: [TimeCategorySnapshot]
}

struct TimeTrackingEntry: TimelineEntry {
    let date: Date
    let isTracking: Bool
    let currentCategory: String
    let elapsedTime: TimeInterval
    let todaysTotal: TimeInterval
    let topCategories: [(String, TimeInterval)]
}

struct TimeTrackingWidgetEntryView: View {
    var entry: TimeTrackingProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTimeTrackingWidget(entry: entry)
        case .systemMedium:
            MediumTimeTrackingWidget(entry: entry)
        default:
            SmallTimeTrackingWidget(entry: entry)
        }
    }
}

struct SmallTimeTrackingWidget: View {
    let entry: TimeTrackingEntry

    var body: some View {
        VStack(spacing: 12) {
            WidgetHeader(title: "Time", icon: "stopwatch.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8))

            if entry.currentCategory == "Pro Feature" {
                EmptyWidgetView(message: "Tracking is a Pro Feature", icon: "star.fill", color: Color(red: 0.9, green: 0.4, blue: 0.6))
            } else if entry.isTracking {
                VStack(spacing: 6) {
                    Text(formatTime(entry.elapsedTime))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))

                    Text(entry.currentCategory)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    WidgetActionButton(title: "Stop", icon: "stop.fill", color: .red, intent: StopTimeTrackingIntent())
                }
            } else {
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatTime(entry.todaysTotal))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.6))
                        Text("TOTAL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                    Text("today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    WidgetActionButton(title: "Start", icon: "play.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8), intent: StartTimeTrackingIntent(category: "Work"))
                }
            }
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MediumTimeTrackingWidget: View {
    let entry: TimeTrackingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                WidgetHeader(title: "Time Tracking", icon: "stopwatch.fill", color: Color(red: 0.4, green: 0.2, blue: 0.8))

                if entry.isTracking {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("TRACKING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if entry.currentCategory == "Pro Feature" {
                EmptyWidgetView(message: "Tracking is a Pro Feature", icon: "star.fill", color: Color(red: 0.9, green: 0.4, blue: 0.6))
            } else if entry.isTracking {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatTime(entry.elapsedTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                            Text(entry.currentCategory)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(entry.todaysTotal))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.6))
                            Text("TOTAL TODAY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .widgetCardStyle()

                    WidgetActionButton(title: "Stop Tracking", icon: "stop.fill", color: .red, intent: StopTimeTrackingIntent())
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatTime(entry.todaysTotal))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.6))
                        Text("TOTAL TODAY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    VStack(spacing: 6) {
                        ForEach(Array(entry.topCategories.prefix(2).enumerated()), id: \.offset) { index, category in
                            HStack {
                                Text(category.0)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text(formatTime(category.1))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                Button(intent: StartTimeTrackingIntent(category: category.0)) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .widgetCardStyle()
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
