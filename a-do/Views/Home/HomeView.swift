import SwiftUI
import SwiftData
import EventKit
import os

extension Calendar {
    func isDateInTomorrow(_ date: Date) -> Bool {
        guard let tomorrow = self.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return self.isDate(date, inSameDayAs: tomorrow)
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Reminder.createdAt, order: .reverse) private var allReminders: [Reminder]
    
    // Filter reminders for different sections
    private var inboxReminders: [Reminder] {
        allReminders.filter { reminder in
            !reminder.isCompleted && (reminder.dueDate == nil || !Calendar.current.isDateInToday(reminder.dueDate!))
        }
    }
    
    private var todayReminders: [Reminder] {
        allReminders.filter { reminder in
            !reminder.isCompleted && 
            reminder.dueDate != nil && 
            Calendar.current.isDateInToday(reminder.dueDate!)
        }
    }

    @State private var viewModel = ReminderHomeViewModel()
    @State private var calendarManager = CalendarManager.shared
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    if horizontalSizeClass == .regular {
                        // iPad layout - use grid for better space utilization
                        LazyVGrid(columns: adaptiveColumns, spacing: 20) {
                            quickAdd
                            locationStatus
                            inboxSection
                            todayRemindersSection
                            todayCalendar
                            upcomingCalendar
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                    } else {
                        // iPhone layout - vertical stack
                        VStack(spacing: 20) {
                            quickAdd
                            locationStatus
                            inboxSection
                            todayRemindersSection
                            todayCalendar
                            upcomingCalendar
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                    }
                }
                .scrollIndicators(.hidden)

                addButton
            }
            .navigationTitle("a-do")
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
            case .sendText(let rid):
                if let reminder = allReminders.first(where: { $0.uuid == rid }) {
                    Task { await composeAndSend(reminder: reminder) }
                }
            case .smartHighPriority, .tag, .priority:
                break
            }
        }
    }
    
    // MARK: - iPad Adaptive Layout
    private var adaptiveColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
        } else {
            return [GridItem(.flexible())]
        }
    }

    private var quickAdd: some View {
        GlassCard {
            VStack(spacing: 12) {
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
                
                // Due date options
                HStack(spacing: 8) {
                    Button("No Date") {
                        viewModel.clearQuickDueDate()
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.quickDueDate == nil ? .blue : .secondary)
                    
                    Button("Today") {
                        viewModel.setQuickDueDateToToday()
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.quickDueDate != nil && Calendar.current.isDateInToday(viewModel.quickDueDate!) ? .blue : .secondary)
                    
                    Button("Tomorrow") {
                        viewModel.setQuickDueDateToTomorrow()
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.quickDueDate != nil && Calendar.current.isDateInTomorrow(viewModel.quickDueDate!) ? .blue : .secondary)
                    
                    Button("Pick Date") {
                        viewModel.showingQuickDatePicker = true
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.quickDueDate != nil && 
                          !Calendar.current.isDateInToday(viewModel.quickDueDate!) && 
                          !Calendar.current.isDateInTomorrow(viewModel.quickDueDate!) ? .blue : .secondary)
                }
                .font(.caption)
                
                if let dueDate = viewModel.quickDueDate {
                    Text("Due: \(dueDate, style: .date) at \(dueDate, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingQuickDatePicker) {
            NavigationStack {
                DatePicker("Due Date", selection: Binding(
                    get: { self.viewModel.quickDueDate ?? Date() },
                    set: { self.viewModel.quickDueDate = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .padding()
                .navigationTitle("Set Due Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            viewModel.showingQuickDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            viewModel.showingQuickDatePicker = false
                        }
                    }
                }
            }
        }
    }
    
    private var locationStatus: some View {
        GlassCard {
            VStack(spacing: 12) {
                LocationStatusView()
                
                if LocationManager.shared.currentLocation != nil {
                    HStack {
                        Button("Create Location Reminder") {
                            createLocationReminder()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Spacer()
                        
                        Button("Refresh Location") {
                            Task {
                                await refreshLocation()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                }
            }
        }
    }

    private var inboxSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Inbox")
                        .font(.headline)
                    Text("(\(inboxReminders.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink("All", destination: ListsView())
                }
                ForEach(inboxReminders.prefix(5)) { reminder in
                    ReminderRow(reminder: reminder)
                }
                if inboxReminders.isEmpty {
                    Text("No reminders in inbox.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var todayRemindersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's Reminders")
                        .font(.headline)
                    Text("(\(todayReminders.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        // Force a refresh by touching the context
                        _ = context.container
                    }
                    .font(.caption)
                }
                ForEach(todayReminders.prefix(5)) { reminder in
                    ReminderRow(reminder: reminder)
                }
                if todayReminders.isEmpty {
                    Text("No reminders due today.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var todayCalendar: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Calendar Events").font(.headline)
                if horizontalSizeClass == .regular {
                    // iPad - use LazyVGrid for better layout
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                        ForEach(calendarManager.todayEvents, id: \.eventIdentifier) { event in
                            EventCard(event: event)
                        }
                    }
                    if calendarManager.todayEvents.isEmpty {
                        Text("No events today").foregroundStyle(.secondary)
                    }
                } else {
                    // iPhone - horizontal scroll
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
    }

    private var upcomingCalendar: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming 5 Days").font(.headline)
                if horizontalSizeClass == .regular {
                    // iPad - use LazyVGrid for better layout
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                        ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                            EventCard(event: event)
                        }
                    }
                    if calendarManager.upcomingEvents.isEmpty {
                        Text("No upcoming events").foregroundStyle(.secondary)
                    }
                } else {
                    // iPhone - horizontal scroll
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
                if reminder.autoTextTaggedContacts || reminder.autoTextMe {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill").foregroundStyle(.green)
                        Text("Auto message: \(reminder.autoTextMe ? "Me" : "")\(reminder.autoTextMe && reminder.autoTextTaggedContacts ? ", " : "")\(reminder.autoTextTaggedContacts ? "Tagged" : "")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if reminder.appleNote != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text").foregroundStyle(.blue)
                        Text("Apple Note attached")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                isCompleted.toggle()
                reminder.isCompleted = isCompleted
                do { try context.save() } catch { Logger(subsystem: "a-do", category: "Home").error("Toggle complete failed: \(String(describing: error))") }
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
                Task {
                    await NotificationManager.shared.scheduleNotifications(
                        for: reminder.id,
                        dueDate: reminder.dueDate,
                        leadTimes: reminder.notifications?.map { $0.leadTimeSeconds } ?? [],
                        title: reminder.title
                    )
                }
            } label: { Label("Reschedule Notifications", systemImage: "bell.badge") }
            Button {
                try? RemindersManager.shared.export(reminder: reminder)
            } label: { Label("Export to Apple Reminders", systemImage: "arrow.up.square") }
            Button {
                Task { try? await CalendarManager.shared.createEvent(from: reminder.title, dueDate: reminder.dueDate) }
            } label: { Label("Create Calendar Event", systemImage: "calendar.badge.plus") }
            if reminder.appleNote != nil {
                Button {
                    NotesManager.shared.openNoteInNotesApp(noteIdentifier: reminder.appleNote!.noteIdentifier)
                } label: { Label("Open Apple Note", systemImage: "note.text") }
            }
        }
    }
}

extension HomeView {
    @MainActor
    func composeAndSend(reminder: Reminder) async {
        var recipients: [String] = []
        if reminder.autoTextTaggedContacts {
            recipients.append(contentsOf: reminder.taggedContacts?.compactMap { $0.phoneNumber } ?? [])
        }
        if reminder.autoTextMe, let my = await ContactsManager.shared.myPhoneNumber() { recipients.append(my) }
        recipients = Array(Set(recipients)).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !recipients.isEmpty else { return }
        let body = reminder.details?.isEmpty == false ? "\(reminder.title) — \(reminder.details!)" : reminder.title
        NotificationManager.shared.composeSMS(to: recipients, body: body)
    }
    
    private func createLocationReminder() {
        // Navigate to reminder form with current location pre-filled
        // This will be handled by the router or navigation
        // For now, we'll just present the form
        // In a more sophisticated implementation, you could pass the location data
    }
    
    private func refreshLocation() async {
        _ = await LocationManager.shared.getCurrentLocation()
    }
}


