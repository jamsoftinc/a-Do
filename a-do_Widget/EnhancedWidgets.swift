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
        ReminderEntry(date: Date(), reminders: sampleReminders())
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> ()) {
        let entry = ReminderEntry(date: Date(), reminders: sampleReminders())
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
        // In a real implementation, this would fetch from the shared container
        return sampleReminders()
    }

    private func sampleReminders() -> [ReminderData] {
        return [
            ReminderData(
                id: UUID().uuidString,
                title: "Team Meeting",
                dueDate: Date().addingTimeInterval(3600),
                priority: .high,
                isCompleted: false,
                hasLocation: true,
                hasVoice: false,
                tags: ["Work"]
            ),
            ReminderData(
                id: UUID().uuidString,
                title: "Buy groceries",
                dueDate: Date().addingTimeInterval(7200),
                priority: .medium,
                isCompleted: false,
                hasLocation: false,
                hasVoice: false,
                tags: ["Personal"]
            ),
            ReminderData(
                id: UUID().uuidString,
                title: "Call dentist",
                dueDate: nil,
                priority: .low,
                isCompleted: false,
                hasLocation: false,
                hasVoice: true,
                tags: ["Health"]
            )
        ]
    }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if entry.reminders.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let nextReminder = entry.reminders.first!
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(priorityColor(nextReminder.priority))
                            .frame(width: 6, height: 6)
                        Text(nextReminder.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                    }

                    if let dueDate = nextReminder.dueDate {
                        Text(dueDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if entry.reminders.count > 1 {
                        Text("+\(entry.reminders.count - 1) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
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

// MARK: - Medium Widget
struct MediumReminderWidget: View {
    let entry: ReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(entry.reminders.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if entry.reminders.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("All caught up!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No pending reminders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entry.reminders.prefix(3).enumerated()), id: \.offset) { index, reminder in
                        ReminderRowWidget(reminder: reminder)
                    }

                    if entry.reminders.count > 3 {
                        HStack {
                            Text("+ \(entry.reminders.count - 3) more reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget
struct LargeReminderWidget: View {
    let entry: ReminderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.reminders.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("pending")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if entry.reminders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    VStack(spacing: 8) {
                        Text("All caught up!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("No pending reminders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Priority breakdown
                let priorityBreakdown = calculatePriorityBreakdown(entry.reminders)

                HStack(spacing: 16) {
                    PriorityIndicator(count: priorityBreakdown.high, color: .red, label: "High")
                    PriorityIndicator(count: priorityBreakdown.medium, color: .orange, label: "Med")
                    PriorityIndicator(count: priorityBreakdown.low, color: .yellow, label: "Low")
                    Spacer()
                }

                // Reminder list
                VStack(spacing: 6) {
                    ForEach(Array(entry.reminders.prefix(6).enumerated()), id: \.offset) { index, reminder in
                        ReminderRowWidget(reminder: reminder, showDetails: true)
                    }

                    if entry.reminders.count > 6 {
                        HStack {
                            Text("+ \(entry.reminders.count - 6) more reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
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
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ReminderRowWidget: View {
    let reminder: ReminderData
    var showDetails: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Interactive completion button
            Button(intent: CompleteReminderIntent(reminderId: reminder.id)) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : .gray)
                    .font(.body)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(priorityColor(reminder.priority))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .strikethrough(reminder.isCompleted)
                    .foregroundColor(reminder.isCompleted ? .secondary : .primary)

                if showDetails {
                    HStack(spacing: 8) {
                        if let dueDate = reminder.dueDate {
                            Text(dueDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if reminder.hasLocation {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }

                        if reminder.hasVoice {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }

                        if !reminder.tags.isEmpty {
                            Text(reminder.tags.first!)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            if let dueDate = reminder.dueDate, !showDetails {
                Text(dueDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
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
            sessionName: "Deep Work",
            remainingTime: 1800,
            totalTime: 3600,
            todaysSessions: 3,
            todaysFocusTime: 7200
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> ()) {
        let entry = FocusEntry(
            date: Date(),
            isActive: false,
            sessionName: "Deep Work",
            remainingTime: 1800,
            totalTime: 3600,
            todaysSessions: 3,
            todaysFocusTime: 7200
        )
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

        // In a real implementation, this would fetch current focus session data
        let entry = FocusEntry(
            date: currentDate,
            isActive: false,
            sessionName: "Work Session",
            remainingTime: 0,
            totalTime: 1800,
            todaysSessions: 2,
            todaysFocusTime: 3600
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Focus")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Check if this is the upgrade message (Pro Feature indicator)
            if entry.sessionName == "Pro Feature" {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("Widgets are a")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Pro Feature")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.isActive {
                VStack(spacing: 8) {
                    Text(formatTime(entry.remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: 1.0 - (entry.remainingTime / entry.totalTime))
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                }
            } else {
                VStack(spacing: 8) {
                    Text("\(entry.todaysSessions)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    Text("sessions today")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatTime(entry.todaysFocusTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Start button
                    Button(intent: StartFocusSessionIntent(durationMinutes: 25)) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text("Start")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
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
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Focus Sessions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()

                if entry.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            // Check if this is the upgrade message (Pro Feature indicator)
            if entry.sessionName == "Pro Feature" {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("Widgets are a")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Text("Pro Feature")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.sessionName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatTime(entry.remainingTime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("remaining")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        CircularProgressView(
                            progress: 1.0 - (entry.remainingTime / entry.totalTime),
                            color: .orange
                        )
                        .frame(width: 40, height: 40)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.todaysSessions)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatTime(entry.todaysFocusTime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Focus Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    // Quick action buttons
                    HStack(spacing: 8) {
                        Button(intent: StartFocusSessionIntent(durationMinutes: 25)) {
                            Text("25 min")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(intent: StartFocusSessionIntent(durationMinutes: 50)) {
                            Text("50 min")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
            }
        }
        .padding()
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
                .stroke(color.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
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
            currentCategory: "Work",
            elapsedTime: 3600,
            todaysTotal: 14400,
            topCategories: [
                ("Work", 7200),
                ("Study", 3600),
                ("Personal", 1800)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeTrackingEntry) -> ()) {
        let entry = TimeTrackingEntry(
            date: Date(),
            isTracking: true,
            currentCategory: "Work",
            elapsedTime: 1800,
            todaysTotal: 10800,
            topCategories: [
                ("Work", 5400),
                ("Study", 3600),
                ("Personal", 1800)
            ]
        )
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

        let entry = TimeTrackingEntry(
            date: currentDate,
            isTracking: false,
            currentCategory: "Work",
            elapsedTime: 0,
            todaysTotal: 7200,
            topCategories: [
                ("Work", 3600),
                ("Study", 2400),
                ("Personal", 1200)
            ]
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
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
            HStack {
                Image(systemName: "stopwatch")
                    .foregroundColor(.green)
                Text("Time")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if entry.currentCategory == "Pro Feature" {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("Widgets are a")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Pro Feature")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.isTracking {
                VStack(spacing: 8) {
                    Text(formatTime(entry.elapsedTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text(entry.currentCategory)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Tracking")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    // Stop button
                    Button(intent: StopTimeTrackingIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.caption2)
                            Text("Stop")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 8) {
                    Text(formatTime(entry.todaysTotal))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("today")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Start button
                    Button(intent: StartTimeTrackingIntent(category: "Work")) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text("Start")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
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
                Image(systemName: "stopwatch")
                    .foregroundColor(.green)
                Text("Time Tracking")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()

                if entry.isTracking {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            // Check if this is the upgrade message (Pro Feature indicator)
            if entry.currentCategory == "Pro Feature" {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("Widgets are a")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Text("Pro Feature")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.isTracking {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatTime(entry.elapsedTime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text(entry.currentCategory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatTime(entry.todaysTotal))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Text("Total Today")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Stop button
                    Button(intent: StopTimeTrackingIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.caption)
                            Text("Stop Tracking")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(formatTime(entry.todaysTotal))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("Today's Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        ForEach(Array(entry.topCategories.prefix(2).enumerated()), id: \.offset) { index, category in
                            HStack {
                                Button(intent: StartTimeTrackingIntent(category: category.0)) {
                                    HStack {
                                        Text(category.0)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(formatTime(category.1))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "play.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding()
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
