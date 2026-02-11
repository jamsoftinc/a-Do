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
            VStack(spacing: 0) {
                // Search and Sort Controls
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search reminders...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Sort Options
                    HStack {
                        Text("Sort by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Text("\(filteredReminders.count) reminders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Reminders List
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading reminders...")
                        Spacer()
                    }
                } else if filteredReminders.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No reminders in inbox" : "No reminders found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Create your first reminder to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
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
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            // Refresh reminders when a new one is created
            Task {
                await loadReminders()
            }
        }
    }
    
    private var filteredReminders: [Reminder] {
        var reminders = allReminders
        
        // Apply search filter
        if !searchText.isEmpty {
            reminders = reminders.filter { reminder in
                reminder.title.localizedCaseInsensitiveContains(searchText) ||
                (reminder.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply sorting
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
            limit: 500, // Higher limit for inbox
            predicate: #Predicate<Reminder> { !$0.isCompleted }
        )
        
        await MainActor.run {
            // Fetch objects on the main context using IDs
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Priority indicator
                if reminder.priority != .none {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isCompleted)
                
                Spacer()
            }
            
            if let details = reminder.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack {
                if let dueDate = reminder.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if dueDate < Date() && !reminder.isCompleted {
                            Text("Overdue")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Text(reminder.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        case .none:
            return .clear
        }
    }
}

#Preview {
    InboxView()
        .modelContainer(for: [Reminder.self], inMemory: true)
}
