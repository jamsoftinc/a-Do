import SwiftUI
import SwiftData
import EventKit

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @State private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var showingPaywall = false
    @State private var showingReminderForm = false
    @State private var showingSettings = false
    @State private var showUnifiedView = true
    @Query private var profiles: [UserProfile]

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted })
    private var allReminders: [Reminder]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    dayStrip
                    dateHeader
                    timelineView
                }
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { profileAvatar }
                }
                ToolbarItem(placement: .principal) {
                    Text("A-do")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingReminderForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.primary, in: Circle())
                    }
                }
            }
            .task {
                await calendarManager.requestAccess()
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack { ReminderFormView() }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsPageView() }
            }
        }
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.14))
                .frame(width: 34, height: 34)
            if let name = profiles.first?.displayName, !name.isEmpty {
                Text(String(name.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primary)
            } else {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
    }

    // MARK: - Day Strip

    private var dayStrip: some View {
        DayStripView(selectedDate: $selectedDate)
            .padding(.horizontal, 16)
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    showUnifiedView.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.caption.weight(.bold))
                        Text("Unified View")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(showUnifiedView ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(showUnifiedView ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(showUnifiedView ? AppTheme.Colors.primary.opacity(0.3) : AppTheme.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Timeline

    private var timelineView: some View {
        let hours = Array(7...20) // 7 AM to 8 PM
        let dayEvents = eventsForDate(selectedDate)
        let dayReminders = remindersForDate(selectedDate)

        return VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                let hourEvents = dayEvents.filter { event in
                    Calendar.current.component(.hour, from: event.startDate) == hour
                }
                let hourReminders = dayReminders.filter { reminder in
                    guard let dueDate = reminder.dueDate else { return false }
                    return Calendar.current.component(.hour, from: dueDate) == hour
                }

                timelineRow(hour: hour, events: hourEvents, reminders: hourReminders)
            }
        }
        .padding(.horizontal, 20)
    }

    private func timelineRow(hour: Int, events: [EKEvent], reminders: [Reminder]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            VStack {
                Text(formatHour(hour))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .frame(width: 50, alignment: .trailing)

                if isCurrentHour(hour) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 50)

            // Content
            VStack(spacing: 8) {
                if events.isEmpty && reminders.isEmpty {
                    if hour == 10 || hour == 14 {
                        TimelineEmptySlot()
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 1)
                    }
                }

                ForEach(events, id: \.eventIdentifier) { event in
                    let duration = event.endDate.timeIntervalSince(event.startDate) / 60
                    let hasVideo = event.hasNotes // approximate: use as proxy
                    let color = Color(cgColor: event.calendar.cgColor)

                    TimelineEventCard(
                        title: event.title ?? "Event",
                        subtitle: "\(event.location ?? "")  \(Int(duration))m",
                        color: color,
                        hasVideoIcon: hasVideo
                    )
                }

                ForEach(reminders, id: \.uuid) { reminder in
                    TimelineEventCard(
                        title: reminder.title,
                        subtitle: reminder.dueDate.map { "Reminder  \($0.formatted(date: .omitted, time: .shortened))" } ?? "Reminder",
                        color: .clear,
                        isDraggable: true,
                        isReminder: true,
                        isHighPriority: reminder.priority == .high,
                        isCompleted: reminder.isCompleted
                    ) {
                        withAnimation {
                            reminder.isCompleted.toggle()
                            reminder.completedAt = reminder.isCompleted ? Date() : nil
                            try? context.save()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(String(format: "%02d", displayHour)) \(period)"
    }

    private func isCurrentHour(_ hour: Int) -> Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return Calendar.current.isDateInToday(selectedDate) && currentHour == hour
    }

    // MARK: - Data

    private func eventsForDate(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let allEvents = calendarManager.todayEvents + calendarManager.upcomingEvents
        return allEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }.sorted { $0.startDate < $1.startDate }
    }

    private func remindersForDate(_ date: Date) -> [Reminder] {
        let calendar = Calendar.current
        return allReminders.filter { reminder in
            guard let dueDate = reminder.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
}

// MARK: - Event Row (kept for compatibility with other views)
struct EventRow: View {
    let event: EKEvent

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.primary)

                    Rectangle()
                        .fill(Color(cgColor: event.calendar.cgColor))
                        .frame(width: 3, height: 20)

                    Text(event.endDate, style: .time)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    CalendarManager.shared.openEventInCalendar(event)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Day Cell (kept for month view if accessed elsewhere)
struct DayCell: View {
    let date: Date
    let events: [EKEvent]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(backgroundColor))

            if !events.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { index in
                        Circle()
                            .fill(Color(cgColor: events[index].calendar.cgColor))
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
        )
    }

    private var textColor: Color {
        if isToday { return .white }
        else if !isCurrentMonth { return AppTheme.Colors.textTertiary }
        else { return AppTheme.Colors.textPrimary }
    }

    private var backgroundColor: Color {
        isToday ? AppTheme.Colors.primary : .clear
    }
}
