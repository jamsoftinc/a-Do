import SwiftUI
import SwiftData
import os

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var todayReminders: [Reminder] = []
    @State private var isLoading: Bool = false
    @State private var showingReminderForm = false
    @State private var showingDailyPlanning = false
    @State private var reminderMutationMonitor = ReminderMutationMonitor.shared
    @State private var isViewVisible = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } else if todayReminders.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("All Caught Up", systemImage: "checkmark.circle")
                        } description: {
                            Text("No tasks due today.")
                        } actions: {
                            Button("Plan for Tomorrow") {
                                showingDailyPlanning = true
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink("Review Inbox", destination: InboxView())
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(todayReminders) { reminder in
                            TodayReminderRow(reminder: reminder, onDelete: deleteReminder)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        goHome()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingReminderForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack {
                    ReminderFormView()
                }
            }
            .sheet(isPresented: $showingDailyPlanning) {
                NavigationStack {
                    DailyPlanningView()
                }
            }
            .onAppear {
                isViewVisible = true
                loadTodayReminders()
            }
            .onDisappear {
                isViewVisible = false
            }
            .onChange(of: reminderMutationMonitor.revision) { _, _ in
                guard isViewVisible else { return }
                loadTodayReminders()
            }
        }
    }

    private func loadTodayReminders() {
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let predicate = #Predicate<Reminder> { reminder in
                !reminder.isCompleted && reminder.dueDate != nil
            }

            let descriptor = FetchDescriptor<Reminder>(predicate: predicate, sortBy: [SortDescriptor(\.dueDate)])

            do {
                let allReminders = try context.fetch(descriptor)
                todayReminders = allReminders.filter { reminder in
                    guard let dueDate = reminder.dueDate else { return false }
                    return calendar.isDate(dueDate, inSameDayAs: today)
                }
            } catch {
                Logger(subsystem: "a-do", category: "TodayView").error("Failed to fetch today reminders: \(error.localizedDescription)")
                todayReminders = []
            }
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        let reminderID = reminder.uuid
        NotificationManager.shared.cancelNotifications(for: reminder)
        context.delete(reminder)
        try? context.save()
        Task {
            await SearchSpotlightManager.shared.removeReminder(id: reminderID)
        }
        WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
        ReminderMutationMonitor.shared.notifyChange()
        loadTodayReminders()
    }

    private func goHome() {
        NotificationCenter.default.post(name: .appNavigateHome, object: nil)
        dismiss()
    }
}

private struct TodayReminderRow: View {
    @Environment(\.modelContext) private var context
    @State private var isCompleted: Bool
    @State private var showingEditSheet = false
    let reminder: Reminder
    let onDelete: (Reminder) -> Void

    init(reminder: Reminder, onDelete: @escaping (Reminder) -> Void) {
        self.reminder = reminder
        self.onDelete = onDelete
        _isCompleted = State(initialValue: reminder.isCompleted)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : AppTheme.Colors.textTertiary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.body)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)

                if let dueDate = reminder.dueDate {
                    Text(dueDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if reminder.priority != .none {
                Circle()
                    .fill(AppTheme.priorityColor(reminder.priority))
                    .frame(width: 8, height: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditSheet = true
        }
        .contextMenu {
            Button { toggleCompletion() } label: {
                Label(isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: isCompleted ? "circle" : "checkmark.circle.fill")
            }
            Button { showingEditSheet = true } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete(reminder) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ReminderFormView(existingReminder: reminder)
            }
        }
    }

    private func toggleCompletion() {
        isCompleted.toggle()
        reminder.isCompleted = isCompleted
        reminder.completedAt = isCompleted ? Date() : nil
        try? context.save()
        WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
        ReminderMutationMonitor.shared.notifyChange()

        if isCompleted {
            HapticManager.shared.play(.success)
        } else {
            HapticManager.shared.impact()
        }
    }
}
