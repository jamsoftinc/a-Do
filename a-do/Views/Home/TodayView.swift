import SwiftUI
import SwiftData
import os

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var todayReminders: [Reminder] = []
    @State private var isLoading: Bool = false
    @State private var showingReminderForm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Gradients.background.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if todayReminders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                                Text("All caught up!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("No tasks due today")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                            
                            // Smart Actions
                            VStack(spacing: 16) {
                                Button {
                                    // Navigate to tomorrow planning
                                    // ideally this opens a sheet, but for now we simulate action
                                } label: {
                                    Label("Plan for Tomorrow", systemImage: "sun.max")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(AppTheme.Gradients.primary)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 40)
                                
                                NavigationLink(destination: InboxView()) {
                                    Label("Review Inbox", systemImage: "tray")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.primary)
                                        .padding()
                                        .background(AppTheme.Colors.surface)
                                        .clipShape(Capsule())
                                        .shadow(radius: 2)
                                }
                            }
                            .padding(.top, 20)
                        } else {
                            ForEach(todayReminders) { reminder in
                                TodayReminderCard(reminder: reminder, onDelete: deleteReminder)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingReminderForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack {
                    ReminderFormView()
                }
            }
            .onAppear {
                loadTodayReminders()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReminderCreated"))) { _ in
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

            // Fetch all incomplete reminders
            let predicate = #Predicate<Reminder> { reminder in
                !reminder.isCompleted && reminder.dueDate != nil
            }

            let descriptor = FetchDescriptor<Reminder>(predicate: predicate, sortBy: [SortDescriptor(\.dueDate)])

            do {
                let allReminders = try context.fetch(descriptor)
                // Filter for today only
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
        NotificationManager.shared.cancelNotification(for: reminder)
        context.delete(reminder)
        try? context.save()
        loadTodayReminders()
    }
}

private struct TodayReminderCard: View {
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
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleCompletion()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isCompleted ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.body)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                    
                    if let dueDate = reminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(dueDate, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(AppTheme.priorityColor(reminder.priority))
                    .frame(width: 8, height: 8)
            }
            .padding(12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditSheet = true
        }
        .contextMenu {
            Button { toggleCompletion() } label: { Label(isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: isCompleted ? "circle" : "checkmark.circle.fill") }
            Button { showingEditSheet = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete(reminder) } label: { Label("Delete", systemImage: "trash") }
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
        
        if isCompleted {
            HapticManager.shared.play(.success)
        } else {
            HapticManager.shared.impact()
        }
    }
}
