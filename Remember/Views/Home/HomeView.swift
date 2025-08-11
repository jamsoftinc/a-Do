import SwiftUI
import SwiftData
import EventKit
import os

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    @State private var viewModel = ReminderHomeViewModel()
    @State private var calendarManager = CalendarManager.shared
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        quickAdd
                        todayReminders
                        todayCalendar
                        upcomingCalendar
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)

                addButton
            }
            .navigationTitle("Remember")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink(destination: ListsView()) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                        }
                        Menu {
                            Button {
                                Task { try? await RemindersManager.shared.requestAccess(); await RemindersManager.shared.importReminders(into: context) }
                            } label: {
                                Label("Import from Reminders", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .task { await calendarManager.requestAccess() }
        .task { NotificationManager.shared.requestAuthorization() }
        .onChange(of: router.destination) { _, dest in
            guard let dest else { return }
            switch dest {
            case .smartToday:
                // Navigate to lists and open Today smart list
                // Minimal: present ListsView; detailed routing could push to specific list if we store IDs
                // Here we just push ListsView; user sees Today at top
                break
            case .smartHighPriority, .tag, .priority:
                break
            }
        }
    }

    private var quickAdd: some View {
        GlassCard {
            HStack {
                TextField("Quick reminder...", text: $viewModel.quickTitle)
                    .textFieldStyle(.plain)
                Button {
                    viewModel.addQuickReminder(context: context)
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.quickTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var todayReminders: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's Reminders")
                        .font(.headline)
                    Spacer()
                    NavigationLink("All", destination: ListsView())
                }
                ForEach(reminders.prefix(5)) { reminder in
                    ReminderRow(reminder: reminder)
                }
                if reminders.isEmpty {
                    Text("No reminders yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var todayCalendar: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Calendar Events").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(calendarManager.todayEvents, id: \.eventIdentifier) { event in
                            EventCard(event: event)
                        }
                        if calendarManager.todayEvents.isEmpty {
                            Text("No events today").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var upcomingCalendar: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming 5 Days").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                            EventCard(event: event)
                        }
                        if calendarManager.upcomingEvents.isEmpty {
                            Text("No upcoming events").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        NavigationLink(destination: ReminderFormView()) {
            ZStack {
                Circle().fill(.white).frame(width: 64, height: 64)
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .shadow(radius: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(24)
        .accessibilityLabel("Add Reminder")
    }
}

private struct EventCard: View {
    let event: EKEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title).font(.subheadline).bold().lineLimit(1)
            Text(event.startDate, style: .time).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReminderRow: View {
    @Environment(\.modelContext) private var context
    @State private var isCompleted: Bool
    @State private var showingEditSheet = false
    let reminder: Reminder

    init(reminder: Reminder) {
        self.reminder = reminder
        _isCompleted = State(initialValue: reminder.isCompleted)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.priorityColor(reminder.priority))
                .frame(width: 10, height: 10)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title).font(.body)
                if let due = reminder.dueDate {
                    Text(due, style: .date).font(.caption).foregroundStyle(.secondary)
                }
                if let details = reminder.details { Text(details).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            Button {
                isCompleted.toggle()
                reminder.isCompleted = isCompleted
                do { try context.save() } catch { Logger(subsystem: "Remember", category: "Home").error("Toggle complete failed: \(String(describing: error))") }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ReminderFormView(existingReminder: reminder)
            }
        }
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: { Label("Edit", systemImage: "pencil") }
            Button {
                NotificationManager.shared.cancelNotifications(for: reminder.id)
            } label: { Label("Cancel Notifications", systemImage: "bell.slash") }
            Button {
                NotificationManager.shared.scheduleNotifications(
                    for: reminder.id,
                    dueDate: reminder.dueDate,
                    leadTimes: reminder.notifications.map { $0.leadTimeSeconds },
                    title: reminder.title
                )
            } label: { Label("Reschedule Notifications", systemImage: "bell.badge") }
            Button {
                try? RemindersManager.shared.export(reminder: reminder)
            } label: { Label("Export to Apple Reminders", systemImage: "arrow.up.square") }
            Button {
                Task { try? await CalendarManager.shared.createEvent(from: reminder.title, dueDate: reminder.dueDate) }
            } label: { Label("Create Calendar Event", systemImage: "calendar.badge.plus") }
        }
    }
}


