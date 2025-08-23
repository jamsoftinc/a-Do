import SwiftUI
import SwiftData
import EventKit
import os
import AVFoundation

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
    @FocusState private var isQuickAddFocused: Bool
    @State private var showingImportReminders = false
    @State private var showingReminderForm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Quick Actions Section
                        quickActionsSection
                        
                        // Main Content
                        if horizontalSizeClass == .regular {
                            // iPad layout - side-by-side for better space utilization
                            HStack(alignment: .top, spacing: 20) {
                                VStack(spacing: 16) {
                                    inboxSection
                                    todayRemindersSection
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(spacing: 16) {
                                    todayCalendar
                                    upcomingCalendar
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // iPhone layout - optimized vertical stack
                            VStack(spacing: 16) {
                                inboxSection
                                todayRemindersSection
                                todayCalendar
                                upcomingCalendar
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingActionButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("a-do")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Voice memo button
                        Button {
                            Task {
                                await startQuickVoiceMemo()
                            }
                        } label: {
                            Image(systemName: AudioManager.shared.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(AudioManager.shared.isRecording ? .red : .white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .disabled(AudioManager.shared.isTranscribing)
                        
                        NavigationLink(destination: ListsView()) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                        NavigationLink(destination: CompletedRemindersView()) {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                        Menu {
                            Button {
                                showingImportReminders = true
                            } label: {
                                Label("Import from Reminders", systemImage: "square.and.arrow.down")
                            }
                            
                            Button {
                                Task {
                                    await ReminderCleanupManager.shared.cleanupOldReminders(in: context)
                                }
                            } label: {
                                Label("Clean Up Old Reminders", systemImage: "trash.circle")
                            }
                            
                            #if DEBUG
                            Button {
                                AppContainer.clearAllDemoData(context: context)
                            } label: {
                                Label("Clear All Demo Data", systemImage: "trash")
                            }
                            .foregroundColor(.red)
                            #endif
                        } label: {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
            }
        }
        .task { await calendarManager.requestAccess() }
        .task { NotificationManager.shared.requestAuthorization() }
        .sheet(isPresented: $showingImportReminders) {
            ImportRemindersView()
        }
        .sheet(isPresented: $showingReminderForm) {
            NavigationStack {
                ReminderFormView()
            }
        }
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
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            // Quick Add Card
            GlassCard {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Text input
                        TextField("Quick reminder...", text: $viewModel.quickTitle)
                            .textFieldStyle(.plain)
                            .focused($isQuickAddFocused)
                            .onTapGesture {
                                isQuickAddFocused = true
                            }
                        
                        // Voice memo button
                        Button {
                            Task {
                                await startQuickVoiceMemo()
                            }
                        } label: {
                            Image(systemName: AudioManager.shared.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundStyle(AudioManager.shared.isRecording ? .red : .blue)
                                .imageScale(.large)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .disabled(AudioManager.shared.isTranscribing)
                        
                        // Add button
                        Button {
                            viewModel.addQuickReminder(context: context)
                            isQuickAddFocused = false
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.white)
                                .imageScale(.large)
                                .frame(width: 32, height: 32)
                                .background(.blue, in: Circle())
                        }
                        .disabled(viewModel.quickTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    // Voice recording status
                    if AudioManager.shared.isRecording {
                        HStack {
                            Image(systemName: "record.circle")
                                .foregroundColor(.red)
                                .imageScale(.small)
                            Text("Recording... \(Int(AudioManager.shared.recordingDuration))s")
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                            Button("Stop") {
                                stopQuickVoiceMemo()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    
                    if AudioManager.shared.isTranscribing {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.orange)
                                .imageScale(.small)
                            Text("Transcribing...")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Success message for voice memo creation
                    if !AudioManager.shared.transcribedText.isEmpty && !AudioManager.shared.isRecording && !AudioManager.shared.isTranscribing {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .imageScale(.small)
                            Text("Voice reminder created!")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Clear") {
                                AudioManager.shared.transcribedText = ""
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Due date options - compact horizontal layout
                    HStack(spacing: 8) {
                        ForEach([
                            ("No Date", nil, viewModel.quickDueDate == nil),
                            ("Today", "today", viewModel.quickDueDate != nil && Calendar.current.isDateInToday(viewModel.quickDueDate!)),
                            ("Tomorrow", "tomorrow", viewModel.quickDueDate != nil && Calendar.current.isDateInTomorrow(viewModel.quickDueDate!)),
                            ("Pick", "pick", viewModel.quickDueDate != nil && 
                             !Calendar.current.isDateInToday(viewModel.quickDueDate!) && 
                             !Calendar.current.isDateInTomorrow(viewModel.quickDueDate!))
                        ], id: \.0) { title, action, isSelected in
                            Button {
                                switch action {
                                case "today":
                                    viewModel.setQuickDueDateToToday()
                                case "tomorrow":
                                    viewModel.setQuickDueDateToTomorrow()
                                case "pick":
                                    viewModel.showingQuickDatePicker = true
                                default:
                                    viewModel.clearQuickDueDate()
                                }
                            } label: {
                                Text(title)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? .blue : .clear, in: Capsule())
                                    .foregroundStyle(isSelected ? .white : .secondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    if let dueDate = viewModel.quickDueDate {
                        Text("Due: \(dueDate, style: .date) at \(dueDate, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Location Status - compact card
            if LocationManager.shared.authorizationStatus != .authorizedWhenInUse && 
               LocationManager.shared.authorizationStatus != .authorizedAlways {
                GlassCard {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundColor(.orange)
                        Text("Enable location for location-based reminders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Enable") {
                            LocationManager.shared.requestAuthorization()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            

        }
        .padding(.horizontal, 16)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inbox")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("\(inboxReminders.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    NavigationLink("View All", destination: ListsView())
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if inboxReminders.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("No reminders in inbox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(inboxReminders.prefix(3)) { reminder in
                            ReminderRow(reminder: reminder, onDelete: deleteReminder)
                        }
                        
                        if inboxReminders.count > 3 {
                            HStack {
                                Text("+ \(inboxReminders.count - 3) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }
    
    private var todayRemindersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("\(todayReminders.count) due today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        // Force a refresh by touching the context
                        _ = context.container
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                if todayReminders.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("All caught up!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(todayReminders.prefix(3)) { reminder in
                            ReminderRow(reminder: reminder, onDelete: deleteReminder)
                        }
                        
                        if todayReminders.count > 3 {
                            HStack {
                                Text("+ \(todayReminders.count - 3) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
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

    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        Button {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            showingReminderForm = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: true)
    }
    

    
    // MARK: - Delete Reminder
    private func deleteReminder(_ reminder: Reminder) {
        // Cancel any notifications for this reminder
        NotificationManager.shared.cancelNotifications(for: reminder.id)
        
        // Stop location monitoring if this reminder has location triggers
        if let locationTrigger = reminder.locationTrigger {
            LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
        }
        
        // Delete voice recording file if it exists
        if let voiceReminder = reminder.voiceReminder,
           let audioFileURL = voiceReminder.audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
        }
        
        // Remove from context and save
        context.delete(reminder)
        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Reminder deleted from context menu: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to delete reminder: \(error.localizedDescription)")
        }
    }
}

private struct EventCard: View {
    let event: EKEvent
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.title).font(.subheadline).bold().lineLimit(1)
                Spacer()
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(event.startDate, style: .time).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                CalendarManager.shared.openEventInCalendar(event)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct ReminderRow: View {
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
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            Circle()
                .fill(AppTheme.priorityColor(reminder.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                    .lineLimit(2)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                
                // Metadata
                HStack(spacing: 8) {
                    if let due = reminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .imageScale(.small)
                            Text(due, style: .time)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    
                    if reminder.autoTextTaggedContacts || reminder.autoTextMe {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                            Text("Auto")
                        }
                        .font(.caption2)
                        .foregroundStyle(.green)
                    }
                    
                    if reminder.appleNote != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                            Text("Note")
                        }
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    }
                    
                    if reminder.calendarInviteCreated {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                            Text("Event")
                        }
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    }
                    
                    if reminder.voiceReminder != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text("Voice")
                        }
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    }
                }
            }
            
            Spacer()
            
            // Complete button
            Button {
                if isCompleted {
                    // Mark as incomplete
                    isCompleted = false
                    reminder.isCompleted = false
                    reminder.completedAt = nil
                } else {
                    // Mark as complete
                    isCompleted = true
                    reminder.isCompleted = true
                    reminder.completedAt = Date()
                    
                    // Cancel notifications and stop location monitoring
                    NotificationManager.shared.cancelNotifications(for: reminder.id)
                    if let locationTrigger = reminder.locationTrigger {
                        LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
                    }
                }
                do { try context.save() } catch { Logger(subsystem: "a-do", category: "Home").error("Toggle complete failed: \(String(describing: error))") }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
                // Quick complete/incomplete toggle
                if isCompleted {
                    isCompleted = false
                    reminder.isCompleted = false
                    reminder.completedAt = nil
                } else {
                    isCompleted = true
                    reminder.isCompleted = true
                    reminder.completedAt = Date()
                    
                    // Cancel notifications and stop location monitoring
                    NotificationManager.shared.cancelNotifications(for: reminder.id)
                    if let locationTrigger = reminder.locationTrigger {
                        LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
                    }
                }
                do { try context.save() } catch { Logger(subsystem: "a-do", category: "Home").error("Toggle complete failed: \(String(describing: error))") }
            } label: { 
                Label(isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: isCompleted ? "circle" : "checkmark.circle.fill") 
            }
            
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
                Task { 
                    do {
                        let event = try await CalendarManager.shared.createCalendarInvite(
                            title: reminder.title,
                            details: reminder.details,
                            dueDate: reminder.dueDate,
                            duration: 30 * 60, // 30 minutes default
                            location: reminder.locationTrigger?.label,
                            attendees: [], // Could be enhanced to include tagged contacts
                            reminder: reminder
                        )
                        if let event = event {
                            // Show success feedback
                            Logger(subsystem: "a-do", category: "Calendar").info("Calendar invite created from context menu for reminder: \(reminder.title)")
                        }
                    } catch {
                        Logger(subsystem: "a-do", category: "Calendar").error("Failed to create calendar invite: \(error.localizedDescription)")
                    }
                }
            } label: { Label("Create Calendar Invite", systemImage: "calendar.badge.plus") }
            if reminder.appleNote != nil {
                Button {
                    NotesManager.shared.openNoteInNotesApp(noteIdentifier: reminder.appleNote!.noteIdentifier)
                } label: { Label("Open Apple Note", systemImage: "note.text") }
            }
            if reminder.voiceReminder != nil {
                Button {
                    Task {
                        if let voiceReminder = reminder.voiceReminder, let audioFileURL = voiceReminder.audioFileURL {
                            do {
                                let player = try AVAudioPlayer(contentsOf: audioFileURL)
                                player.play()
                            } catch {
                                Logger(subsystem: "a-do", category: "Voice").error("Failed to play voice recording: \(String(describing: error))")
                            }
                        }
                    }
                } label: { Label("Play Voice Recording", systemImage: "play.circle") }
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete(reminder)
            } label: { Label("Delete", systemImage: "trash") }
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
    
    // MARK: - Quick Voice Memo Methods
    
    private func startQuickVoiceMemo() async {
        // Start recording
        await AudioManager.shared.startRecording()
        
        // Monitor recording state and transcription
        while AudioManager.shared.isRecording || AudioManager.shared.isTranscribing {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Create reminder from transcribed text if successful
        if !AudioManager.shared.transcribedText.isEmpty {
            let transcribedText = AudioManager.shared.transcribedText
            
            // Create a new reminder with the transcribed text
            let reminder = Reminder(
                title: transcribedText,
                dueDate: viewModel.quickDueDate
            )
            
            context.insert(reminder)
            
            // Create voice reminder attachment
            if let audioFileURL = AudioManager.shared.getAudioFileURL() {
                let fileName = audioFileURL.lastPathComponent
                let voiceReminder = VoiceReminder(
                    audioFileName: fileName,
                    transcribedText: transcribedText,
                    recordingDuration: AudioManager.shared.recordingDuration
                )
                reminder.voiceReminder = voiceReminder
            }
            
            do {
                try context.save()
                Logger(subsystem: "a-do", category: "Voice").info("Quick voice reminder created: '\(transcribedText)'")
            } catch {
                Logger(subsystem: "a-do", category: "Voice").error("Failed to save quick voice reminder: \(String(describing: error))")
            }
        }
    }
    
    private func stopQuickVoiceMemo() {
        AudioManager.shared.stopRecording()
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


