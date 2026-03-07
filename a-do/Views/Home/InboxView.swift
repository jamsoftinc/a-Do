import SwiftUI
import SwiftData
import os

struct InboxView: View {
    @Environment(\.modelContext) private var context
    @State private var allReminders: [Reminder] = []
    @State private var isLoading: Bool = false
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .createdDate
    @State private var showingReminderForm = false
    @State private var selectedReminder: Reminder?

    enum SortOption: String, CaseIterable {
        case createdDate = "Created Date"
        case dueDate = "Due Date"
        case priority = "Priority"
        case title = "Title"

        var sortDescriptor: SortDescriptor<Reminder> {
            switch self {
            case .createdDate:
                return SortDescriptor(\.createdAt, order: .reverse)
            case .dueDate:
                return SortDescriptor(\.dueDate, order: .forward)
            case .priority:
                return SortDescriptor(\.priorityRaw, order: .reverse)
            case .title:
                return SortDescriptor(\.title, order: .forward)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading reminders...")
                            Spacer()
                        }
                    }
                } else if filteredReminders.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label(searchText.isEmpty ? "No Reminders" : "No Results",
                                  systemImage: searchText.isEmpty ? "tray" : "magnifyingglass")
                        } description: {
                            Text(searchText.isEmpty
                                 ? "Create your first reminder to get started."
                                 : "Try adjusting your search terms.")
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(filteredReminders) { reminder in
                            InboxReminderRowView(reminder: reminder)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedReminder = reminder
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Complete") {
                                        completeReminder(reminder)
                                    }
                                    .tint(.green)

                                    Button("Delete", role: .destructive) {
                                        deleteReminder(reminder)
                                    }

                                    Button("Edit") {
                                        selectedReminder = reminder
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Mark Important") {
                                        markImportant(reminder)
                                    }
                                    .tint(.orange)
                                }
                        }
                    } header: {
                        HStack {
                            Text("Sort by:")
                                .font(.caption)

                            Picker("Sort", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)

                            Spacer()

                            Text("\(filteredReminders.count) reminders")
                                .font(.caption)
                        }
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search reminders")
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            .sheet(item: $selectedReminder) { reminder in
                NavigationStack {
                    ReminderFormView(existingReminder: reminder)
                }
            }
        }
        .task {
            await loadReminders()
        }
        .refreshable {
            await loadReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReminderCreated"))) { _ in
            Task {
                await loadReminders()
            }
        }
    }

    private var filteredReminders: [Reminder] {
        var reminders = allReminders

        if !searchText.isEmpty {
            reminders = reminders.filter { reminder in
                reminder.title.localizedCaseInsensitiveContains(searchText) ||
                (reminder.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        reminders.sort { reminder1, reminder2 in
            switch sortOption {
            case .createdDate:
                return reminder1.createdAt > reminder2.createdAt
            case .dueDate:
                if let date1 = reminder1.dueDate, let date2 = reminder2.dueDate {
                    return date1 < date2
                } else if reminder1.dueDate != nil {
                    return true
                } else if reminder2.dueDate != nil {
                    return false
                } else {
                    return reminder1.createdAt > reminder2.createdAt
                }
            case .priority:
                return reminder1.priorityRaw > reminder2.priorityRaw
            case .title:
                return reminder1.title.localizedCaseInsensitiveCompare(reminder2.title) == .orderedAscending
            }
        }

        return reminders
    }

    private func loadReminders() async {
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        let reminderIDs = await MemorySafeDataLoader.loadReminders(
            context: context,
            limit: 500,
            predicate: #Predicate<Reminder> { !$0.isCompleted }
        )

        await MainActor.run {
            var loadedReminders: [Reminder] = []
            for id in reminderIDs {
                if let reminder = context.model(for: id) as? Reminder {
                    loadedReminders.append(reminder)
                }
            }
            self.allReminders = loadedReminders
        }
    }

    private func completeReminder(_ reminder: Reminder) {
        reminder.isCompleted = true
        reminder.completedAt = Date()

        do {
            try context.save()
            WidgetSnapshotManager.shared.refreshSnapshots(context: context)
        } catch {
            // Handle error silently in production
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        context.delete(reminder)

        do {
            try context.save()
            WidgetSnapshotManager.shared.refreshSnapshots(context: context)
        } catch {
            // Handle error silently in production
        }
    }

    private func markImportant(_ reminder: Reminder) {
        reminder.priority = .high
        do {
            try context.save()
            WidgetSnapshotManager.shared.refreshSnapshots(context: context)
        } catch {
            // Handle error silently in production
        }
    }
}

struct InboxReminderRowView: View {
    let reminder: Reminder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if reminder.priority != .none {
                    Circle()
                        .fill(AppTheme.priorityColor(reminder.priority))
                        .frame(width: 8, height: 8)
                }

                Text(reminder.title)
                    .font(.body)
                    .strikethrough(reminder.isCompleted)

                Spacer()
            }

            if let details = reminder.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if let dueDate = reminder.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDate, style: .date)
                            .font(.caption)

                        if dueDate < Date() && !reminder.isCompleted {
                            Text("Overdue")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1), in: Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(reminder.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    InboxView()
        .modelContainer(for: [Reminder.self], inMemory: true)
}
