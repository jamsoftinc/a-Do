//
//  DailyPlanningView.swift
//  a-do
//
//  Daily planning view for morning briefing and day planning
//

import SwiftUI
import SwiftData
import EventKit

struct DailyPlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted },
           sort: [SortDescriptor(\Reminder.dueDate)])
    private var allReminders: [Reminder]

    @State private var calendarEvents: [EKEvent] = []
    @State private var selectedDate: Date = Date()
    @State private var isLoading = true
    @State private var isAutoPlanning = false
    @State private var autoPlanResultMessage = ""
    @State private var showingAutoPlanResult = false
    @State private var showingPaywall = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Header
                    dateHeaderSection

                    // Morning Briefing
                    morningBriefingSection

                    // Today's Schedule
                    todayScheduleSection

                    // Overdue Reminders
                    if !overdueReminders.isEmpty {
                        overdueSection
                    }

                    // Suggested Time Blocks
                    suggestedBlocksSection

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Daily Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadCalendarEvents()
                isLoading = false
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Auto Plan", isPresented: $showingAutoPlanResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(autoPlanResultMessage)
            }
        }
    }

    // MARK: - Date Header

    private var dateHeaderSection: some View {
        VStack(spacing: 8) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                .font(.title2)
                .fontWeight(.semibold)

            Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                .font(.headline)
                .foregroundStyle(.secondary)

            // Quick date navigation
            HStack(spacing: 16) {
                Button(action: { navigateDay(-1) }) {
                    Image(systemName: "chevron.left")
                }

                Button("Today") {
                    selectedDate = Date()
                }
                .buttonStyle(.bordered)

                Button(action: { navigateDay(1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Morning Briefing

    private var morningBriefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Morning Briefing", systemImage: "sun.max.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            HStack(spacing: 20) {
                DailyPlanStatCard(
                    title: "Tasks",
                    value: "\(todayReminders.count)",
                    icon: "checklist",
                    color: .blue
                )

                DailyPlanStatCard(
                    title: "Events",
                    value: "\(calendarEvents.count)",
                    icon: "calendar",
                    color: .purple
                )

                DailyPlanStatCard(
                    title: "High Priority",
                    value: "\(highPriorityCount)",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Today's Schedule

    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today's Schedule", systemImage: "clock")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if timelineItems.isEmpty {
                Text("No scheduled items for today")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(timelineItems) { item in
                    TimelineItemRow(item: item)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Overdue Section

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overdue", systemImage: "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            ForEach(overdueReminders, id: \.uuid) { reminder in
                HStack {
                    VStack(alignment: .leading) {
                        Text(reminder.title)
                            .fontWeight(.medium)

                        if let dueDate = reminder.dueDate {
                            Text("Due: \(dueDate.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button("Complete") {
                            completeReminder(reminder)
                        }
                        Button("Snooze to Today") {
                            snoozeToToday(reminder)
                        }
                        Button("Snooze to Tomorrow") {
                            snoozeToTomorrow(reminder)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Suggested Time Blocks

    private var suggestedBlocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested Time Blocks", systemImage: "calendar.badge.plus")
                .font(.headline)

            let unscheduledReminders = todayReminders.filter { $0.dueDate == nil || !isTimeSpecific($0.dueDate) }

            if unscheduledReminders.isEmpty {
                Text("All tasks have scheduled times")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(unscheduledReminders.prefix(3)), id: \.uuid) { reminder in
                    SuggestedBlockRow(
                        reminder: reminder,
                        suggestedTime: CalendarManager.shared.suggestTimeForReminder(reminder),
                        onSchedule: { scheduleReminder(reminder, at: $0) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)

            HStack(spacing: 12) {
                DailyPlanActionButton(
                    title: isAutoPlanning ? "Planning..." : "AI Auto-Plan",
                    icon: EntitlementManager.shared.canUseDailyPlanning ? "sparkles" : "lock.fill",
                    color: .purple
                ) {
                    autoPlanMyDay()
                }
                .disabled(isAutoPlanning)

                DailyPlanActionButton(
                    title: "Complete All",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    completeAllTodayReminders()
                }

                DailyPlanActionButton(
                    title: "Reschedule",
                    icon: "calendar.badge.clock",
                    color: .orange
                ) {
                    // This would open a batch reschedule sheet
                }

                DailyPlanActionButton(
                    title: "Add Task",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    // This would open quick add
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var todayReminders: [Reminder] {
        allReminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }

    private var overdueReminders: [Reminder] {
        let now = Date()
        return allReminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return dueDate < now && !calendar.isDateInToday(dueDate)
        }
    }

    private var highPriorityCount: Int {
        todayReminders.filter { $0.priority == .high }.count
    }

    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        // Add reminders with specific times
        for reminder in todayReminders {
            if let dueDate = reminder.dueDate, isTimeSpecific(dueDate) {
                items.append(TimelineItem(
                    id: reminder.uuid.uuidString,
                    title: reminder.title,
                    time: dueDate,
                    type: .reminder,
                    priority: reminder.priority
                ))
            }
        }

        // Add calendar events
        for event in calendarEvents {
            items.append(TimelineItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Event",
                time: event.startDate,
                type: .calendarEvent,
                endTime: event.endDate
            ))
        }

        return items.sorted { $0.time < $1.time }
    }

    // MARK: - Helper Methods

    private func navigateDay(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
            selectedDate = newDate
            Task {
                await loadCalendarEvents()
            }
        }
    }

    private func loadCalendarEvents() async {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        await CalendarManager.shared.requestAccess()
        calendarEvents = CalendarManager.shared.todayEvents.filter { event in
            event.startDate >= start && event.startDate < end
        }
    }

    private func isTimeSpecific(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour != 0 || components.minute != 0)
    }

    private func completeReminder(_ reminder: Reminder) {
        reminder.isCompleted = true
        reminder.completedAt = Date()
        try? modelContext.save()
    }

    private func snoozeToToday(_ reminder: Reminder) {
        let endOfDay = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date())
        reminder.dueDate = endOfDay
        try? modelContext.save()
    }

    private func snoozeToTomorrow(_ reminder: Reminder) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())
        reminder.dueDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow ?? Date())
        try? modelContext.save()
    }

    private func scheduleReminder(_ reminder: Reminder, at date: Date) {
        reminder.dueDate = date
        try? modelContext.save()

        // Create calendar block
        Task {
            try? await CalendarManager.shared.createTimeBlock(
                for: reminder,
                startDate: date,
                duration: 30 * 60,
                context: modelContext
            )
        }
    }

    private func completeAllTodayReminders() {
        let now = Date()
        for reminder in todayReminders {
            reminder.isCompleted = true
            reminder.completedAt = now
        }
        try? modelContext.save()
    }

    private var autoPlanCandidates: [Reminder] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return allReminders
            .filter { reminder in
                guard !reminder.isCompleted else { return false }
                if let dueDate = reminder.dueDate {
                    if dueDate < dayStart { return true } // Overdue tasks.
                    if dueDate >= dayStart && dueDate < dayEnd {
                        return !isTimeSpecific(dueDate)
                    }
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    @MainActor
    private func autoPlanMyDay() {
        guard EntitlementManager.shared.canUseDailyPlanning else {
            showingPaywall = true
            return
        }

        guard !isAutoPlanning else { return }
        isAutoPlanning = true

        Task { @MainActor in
            let candidates = Array(autoPlanCandidates.prefix(8))
            guard !candidates.isEmpty else {
                autoPlanResultMessage = "No unscheduled tasks were found for auto-planning."
                showingAutoPlanResult = true
                isAutoPlanning = false
                return
            }

            let orderedIDs = await AIManager.shared.rankRemindersForFocus(candidates, focusType: .work)
            let rankIndex = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
            let rankedCandidates = candidates.sorted { lhs, rhs in
                let lhsRank = rankIndex[lhs.uuid] ?? Int.max
                let rhsRank = rankIndex[rhs.uuid] ?? Int.max
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.createdAt < rhs.createdAt
            }

            let existingIntervals = scheduledIntervalsForSelectedDay()
            let slots = generateSlots(
                for: selectedDate,
                neededCount: rankedCandidates.count,
                existingIntervals: existingIntervals
            )

            guard !slots.isEmpty else {
                autoPlanResultMessage = "No available time slots were found for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
                showingAutoPlanResult = true
                isAutoPlanning = false
                return
            }

            let shouldBlockCalendar = EntitlementManager.shared.canUseCalendarBlocking
            if shouldBlockCalendar {
                await CalendarManager.shared.requestAccess()
            }

            var scheduledCount = 0
            var blockedCount = 0

            for (reminder, slot) in zip(rankedCandidates, slots) {
                reminder.dueDate = slot
                scheduledCount += 1

                let leadTimes = reminder.notifications?.map(\.leadTimeSeconds) ?? []
                await NotificationManager.shared.rescheduleNotifications(
                    for: reminder,
                    dueDate: slot,
                    leadTimes: leadTimes
                )

                guard shouldBlockCalendar, CalendarManager.shared.accessGranted else { continue }
                do {
                    if reminder.calendarEventID == nil {
                        _ = try await CalendarManager.shared.createTimeBlock(
                            for: reminder,
                            startDate: slot,
                            duration: 30 * 60,
                            context: modelContext
                        )
                    } else {
                        try await CalendarManager.shared.updateTimeBlock(
                            for: reminder,
                            newStartDate: slot,
                            newDuration: 30 * 60,
                            context: modelContext
                        )
                    }
                    blockedCount += 1
                } catch {
                    // Calendar blocking is best-effort; reminders are still scheduled in-app.
                }
            }

            try? modelContext.save()
            await loadCalendarEvents()

            if scheduledCount == 0 {
                autoPlanResultMessage = "Auto-plan could not place tasks into open slots."
            } else if blockedCount > 0 {
                autoPlanResultMessage = "Scheduled \(scheduledCount) tasks and created \(blockedCount) calendar blocks."
            } else {
                autoPlanResultMessage = "Scheduled \(scheduledCount) tasks for your day."
            }

            showingAutoPlanResult = true
            isAutoPlanning = false
        }
    }

    private func scheduledIntervalsForSelectedDay() -> [DateInterval] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        var intervals: [DateInterval] = []

        for reminder in todayReminders {
            guard let dueDate = reminder.dueDate, isTimeSpecific(dueDate) else { continue }
            let end = dueDate.addingTimeInterval(30 * 60)
            intervals.append(DateInterval(start: dueDate, end: end))
        }

        for event in calendarEvents {
            let start = max(event.startDate, dayStart)
            let end = min(event.endDate, dayEnd)
            if end > start {
                intervals.append(DateInterval(start: start, end: end))
            }
        }

        return intervals.sorted { $0.start < $1.start }
    }

    private func generateSlots(
        for day: Date,
        neededCount: Int,
        existingIntervals: [DateInterval]
    ) -> [Date] {
        guard neededCount > 0 else { return [] }
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let preferredStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart),
              let preferredEnd = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayStart) else {
            return []
        }

        var usedIntervals = existingIntervals
        var slots: [Date] = []
        let slotDuration: TimeInterval = 30 * 60
        let increment: TimeInterval = 30 * 60

        let now = Date()
        var cursor = max(preferredStart, calendar.isDate(day, inSameDayAs: now) ? now : preferredStart)
        cursor = roundedUpToHalfHour(cursor)

        while slots.count < neededCount && cursor < min(preferredEnd, dayEnd) {
            let candidate = DateInterval(start: cursor, duration: slotDuration)
            let hasConflict = usedIntervals.contains { $0.intersects(candidate) }
            if !hasConflict && candidate.end <= min(preferredEnd, dayEnd) {
                slots.append(cursor)
                usedIntervals.append(candidate)
            }
            cursor = cursor.addingTimeInterval(increment)
        }

        return slots
    }

    private func roundedUpToHalfHour(_ date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0

        if minute == 0 || minute == 30 {
            components.second = 0
            return calendar.date(from: components) ?? date
        }

        if minute < 30 {
            components.minute = 30
        } else {
            components.minute = 0
            if let hour = components.hour {
                components.hour = hour + 1
            }
        }
        components.second = 0
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Supporting Views

struct DailyPlanStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct TimelineItem: Identifiable {
    let id: String
    let title: String
    let time: Date
    let type: TimelineItemType
    var priority: Priority = .none
    var endTime: Date?

    enum TimelineItemType {
        case reminder
        case calendarEvent
    }
}

struct TimelineItemRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack {
                Text(item.time.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .fontWeight(.medium)

                if let endTime = item.endTime {
                    Text(endTime.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50)

            // Type indicator
            Circle()
                .fill(item.type == .reminder ? Color.blue : Color.purple)
                .frame(width: 8, height: 8)

            // Title
            VStack(alignment: .leading) {
                Text(item.title)
                    .fontWeight(.medium)

                if item.type == .reminder && item.priority == .high {
                    Text("High Priority")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Type icon
            Image(systemName: item.type == .reminder ? "checklist" : "calendar")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct SuggestedBlockRow: View {
    let reminder: Reminder
    let suggestedTime: Date?
    let onSchedule: (Date) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reminder.title)
                    .fontWeight(.medium)

                if let time = suggestedTime {
                    Text("Suggested: \(time.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let time = suggestedTime {
                Button("Schedule") {
                    onSchedule(time)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DailyPlanActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    DailyPlanningView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
