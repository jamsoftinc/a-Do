import SwiftUI
import SwiftData
import EventKit
import os
import AVFoundation
import Combine

extension Calendar {
    func isDateInTomorrow(_ date: Date) -> Bool {
        guard let tomorrow = self.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return self.isDate(date, inSameDayAs: tomorrow)
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var profiles: [UserProfile]
    private var cloudKitManager = CloudKitManager.shared

    // Cached filtered reminders
    @State private var inboxReminders: [Reminder] = []
    @State private var todayReminders: [Reminder] = []
    @State private var allReminders: [Reminder] = []
    @State private var lastUpdateDate: Date = Date()
    @State private var isLoadingReminders: Bool = false

    @State private var viewModel = ReminderHomeViewModel()
    @State private var behavioralLearning = BehavioralLearningManager.shared
    @Environment(AppRouter.self) private var router
    @FocusState private var isQuickAddFocused: Bool

    // Sheet states
    @State private var showingPaywall = false
    @State private var showingReminderForm = false

    // More menu sheets
    @State private var showingCollaboration = false
    @State private var showingAISuggestions = false
    @State private var showingAIInsights = false
    @State private var showingDailyPlanning = false
    @State private var showingMorningBriefing = false
    @State private var reminderMutationMonitor = ReminderMutationMonitor.shared
    @State private var isViewVisible = false

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = profiles.first?.displayName ?? ""
        switch hour {
        case 0..<12: return "Good Morning\(name.isEmpty ? "" : ", \(name)")"
        case 12..<17: return "Good Afternoon\(name.isEmpty ? "" : ", \(name)")"
        default: return "Good Evening\(name.isEmpty ? "" : ", \(name)")"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Cards (Apple Reminders style 2x2 grid)
                    summaryGrid

                    // Quick Add
                    quickAddSection

                    // Tools
                    toolsSection

                    // Intelligence
                    intelligenceSection

                    // Pro Upgrade
                    if !EntitlementManager.shared.isProUser {
                        proUpgradeSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(greetingTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Features") {
                            NavigationLink(destination: CompletedRemindersView()) {
                                Label("Completed", systemImage: "checkmark.circle")
                            }

                            NavigationLink(destination: SmartSearchView()) {
                                Label("Smart Search", systemImage: "magnifyingglass")
                            }

                            NavigationLink(destination: TimeTrackingView()) {
                                Label("Time Tracking", systemImage: "timer")
                            }

                            NavigationLink(destination: FocusDashboardView()) {
                                Label("Focus", systemImage: "scope")
                            }

                            NavigationLink(destination: ShadowInboxView()) {
                                Label("Shadow Inbox", systemImage: "tray.full")
                            }

                            Button {
                                showingCollaboration = true
                            } label: {
                                Label("Collaboration", systemImage: "person.2")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            if EntitlementManager.shared.hasAccess(to: .voiceReminders) {
                                if AudioManager.shared.isRecording {
                                    stopQuickVoiceMemo()
                                } else {
                                    Task { await startQuickVoiceMemo() }
                                }
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Image(systemName: AudioManager.shared.isRecording ? "stop.circle.fill" : "mic")
                                .foregroundStyle(AudioManager.shared.isRecording ? Color.red : Color.accentColor)
                        }

                        Button {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showingReminderForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Reminder")
                    }
                }
            }
            .onAppear {
                isViewVisible = true
                cloudKitManager.loadSyncSetting(context: context)
                loadRemindersAsync()
            }
            .onDisappear {
                isViewVisible = false
            }
            .onChange(of: reminderMutationMonitor.revision) { _, _ in
                guard isViewVisible else { return }
                loadRemindersAsync()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack {
                    ReminderFormView()
                }
            }
            .sheet(isPresented: $showingCollaboration) {
                NavigationStack {
                    CollaborationView()
                }
            }
            .sheet(isPresented: $showingAISuggestions) {
                NavigationStack {
                    AISuggestionsViewWrapper()
                }
            }
            .sheet(isPresented: $showingAIInsights) {
                AIInsightsDashboardWrapper()
            }
            .sheet(isPresented: $showingDailyPlanning) {
                NavigationStack {
                    DailyPlanningView()
                }
            }
            .fullScreenCover(isPresented: $showingMorningBriefing) {
                MorningBriefingView()
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
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                viewModel.showingQuickDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                viewModel.showingQuickDatePicker = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingQuickCaptureReview) {
                QuickCaptureReviewSheet(
                    drafts: Binding(
                        get: { viewModel.pendingQuickCaptureDrafts },
                        set: { viewModel.pendingQuickCaptureDrafts = $0 }
                    ),
                    isSaving: viewModel.isPreparingQuickCapture,
                    onCancel: {
                        viewModel.cancelQuickCaptureReview()
                    },
                    onConfirm: {
                        Task {
                            await viewModel.commitQuickCapture(context: context)
                        }
                    }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.showQuickCaptureUndo {
                    HStack(spacing: 12) {
                        Text("Created \(viewModel.lastQuickCaptureCreatedCount) reminder\(viewModel.lastQuickCaptureCreatedCount == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Button("Undo") {
                            viewModel.undoLastQuickCapture(context: context)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            NavigationLink(destination: TodayView()) {
                HomeSummaryCard(title: "Today", icon: "calendar", iconColor: .blue, count: todayReminders.count)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: InboxView()) {
                HomeSummaryCard(title: "Inbox", icon: "tray", iconColor: .gray, count: inboxReminders.count)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ListsView()) {
                HomeSummaryCard(title: "All Lists", icon: "folder", iconColor: .purple, count: allReminders.count)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CompletedRemindersView()) {
                HomeSummaryCard(title: "Completed", icon: "checkmark", iconColor: .green)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools")
                .font(.title3.weight(.semibold))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: FocusDashboardView()) {
                    homeRow(icon: "scope", title: "Focus Mode", color: .purple)
                }
                sectionDivider
                NavigationLink(destination: TimeTrackingView()) {
                    homeRow(icon: "timer", title: "Time Tracking", color: .orange)
                }
                sectionDivider
                NavigationLink(destination: TemplatesView()) {
                    homeRow(icon: "doc.on.doc", title: "Templates", color: .cyan)
                }
                sectionDivider
                NavigationLink(destination: SmartSearchView()) {
                    homeRow(icon: "magnifyingglass", title: "Smart Search", color: .blue)
                }
                sectionDivider
                NavigationLink(destination: ShadowInboxView()) {
                    homeRow(icon: "tray.full", title: "Shadow Inbox", color: .indigo)
                }
                sectionDivider
                Button { showingCollaboration = true } label: {
                    homeRow(icon: "person.2", title: "Collaboration", color: .green)
                }
            }
            .buttonStyle(.plain)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Intelligence Section

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intelligence")
                .font(.title3.weight(.semibold))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAISuggestions = true
                    } else { showingPaywall = true }
                } label: {
                    homeRow(icon: "sparkles", title: "AI Suggestions", color: .blue,
                            locked: !EntitlementManager.shared.hasAccess(to: .advancedNLP))
                }
                sectionDivider
                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAIInsights = true
                    } else { showingPaywall = true }
                } label: {
                    homeRow(icon: "chart.line.uptrend.xyaxis", title: "AI Insights", color: .indigo,
                            locked: !EntitlementManager.shared.hasAccess(to: .advancedNLP))
                }
                sectionDivider
                Button {
                    if EntitlementManager.shared.hasAccess(to: .dailyPlanning) {
                        showingDailyPlanning = true
                    } else { showingPaywall = true }
                } label: {
                    homeRow(icon: "sun.max", title: "Daily Planning", color: .orange,
                            locked: !EntitlementManager.shared.hasAccess(to: .dailyPlanning))
                }
                sectionDivider
                Button {
                    if EntitlementManager.shared.isProUser {
                        showingMorningBriefing = true
                    } else { showingPaywall = true }
                } label: {
                    homeRow(icon: "sunrise", title: "Morning Briefing", color: .yellow,
                            locked: !EntitlementManager.shared.isProUser)
                }
            }
            .buttonStyle(.plain)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Pro Upgrade

    private var proUpgradeSection: some View {
        Button { showingPaywall = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text("Unlock AI features & unlimited habits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Upgrade")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(16)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                TextField("New Reminder", text: $viewModel.quickTitle)
                    .font(.body)
                    .focused($isQuickAddFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !viewModel.quickTitle.isEmpty {
                            viewModel.addQuickReminder(context: context)
                        }
                    }

                if !viewModel.quickTitle.isEmpty {
                    Button {
                        viewModel.addQuickReminder(context: context)
                        isQuickAddFocused = false
                    } label: {
                        if viewModel.isPreparingQuickCapture {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPreparingQuickCapture)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isQuickAddFocused || !viewModel.quickTitle.isEmpty {
                Divider().padding(.leading, 48)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([
                            ("Today", "today", viewModel.quickDueDate.map { Calendar.current.isDateInToday($0) } ?? false),
                            ("Tomorrow", "tomorrow", viewModel.quickDueDate.map { Calendar.current.isDateInTomorrow($0) } ?? false),
                            ("Pick Date", "pick", viewModel.quickDueDate.map { date in
                                !Calendar.current.isDateInToday(date) && !Calendar.current.isDateInTomorrow(date)
                            } ?? false)
                        ], id: \.0) { title, action, isSelected in
                            Button {
                                switch action {
                                case "today": viewModel.setQuickDueDateToToday()
                                case "tomorrow": viewModel.setQuickDueDateToTomorrow()
                                case "pick": viewModel.showingQuickDatePicker = true
                                default: break
                                }
                            } label: {
                                Text(title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                                    .foregroundStyle(isSelected ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if viewModel.quickDueDate != nil {
                            Button {
                                viewModel.clearQuickDueDate()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }
        }
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Row Components

    private func homeRow(icon: String, title: String, color: Color, locked: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title)
                .font(.body)
                .foregroundStyle(Color(.label))

            Spacer()

            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var sectionDivider: some View {
        Divider().padding(.leading, 56)
    }

    // MARK: - Helper Methods
    private func updateFilteredReminders() {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var newInboxReminders: [Reminder] = []
        var newTodayReminders: [Reminder] = []

        for reminder in allReminders {
            guard !reminder.isCompleted else { continue }
            if let dueDate = reminder.dueDate {
                if calendar.isDate(dueDate, inSameDayAs: today) {
                    newTodayReminders.append(reminder)
                } else {
                    newInboxReminders.append(reminder)
                }
            } else {
                newInboxReminders.append(reminder)
            }
        }

        self.inboxReminders = newInboxReminders
        self.todayReminders = newTodayReminders
        self.lastUpdateDate = now
    }

    private func loadRemindersAsync() {
        guard !isLoadingReminders else { return }
        Task { await loadRemindersInBackground() }
    }

    private func loadRemindersInBackground() async {
        guard !isLoadingReminders else { return }
        await MainActor.run { isLoadingReminders = true }

        let reminderIDs = await MemorySafeDataLoader.loadReminders(
            context: context,
            limit: 200,
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
            self.updateFilteredReminders()
            self.isLoadingReminders = false
        }
    }

    // MARK: - Voice Memo Methods
    private func startQuickVoiceMemo() async {
        await AudioManager.shared.startRecording()
        let _ = await AudioManager.shared.awaitCaptureCompletion()
        await createVoiceReminderFromTranscription()
    }

    private func createVoiceReminderFromTranscription() async {
        guard !AudioManager.shared.transcribedText.isEmpty else { return }
        let text = AudioManager.shared.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 2 else { return }

        let parsedRequests = await AIManager.shared.buildCaptureRequests(
            from: text,
            fallbackDueDate: viewModel.quickDueDate
        )

        let preparedRequests = parsedRequests.enumerated().map { index, baseRequest in
            var request = baseRequest
            if request.dueDate == nil {
                request.dueDate = viewModel.quickDueDate
            }

            if index == 0, let audioFileURL = AudioManager.shared.getAudioFileURL() {
                request.voiceReminder = VoiceReminder(
                    audioFileName: audioFileURL.lastPathComponent,
                    transcribedText: text,
                    recordingDuration: AudioManager.shared.recordingDuration
                )
            }

            return request
        }

        guard !preparedRequests.isEmpty else { return }

        do {
            let reminders = try await ReminderCreationService.shared.createReminders(requests: preparedRequests, in: context)
            if !reminders.isEmpty {
                AudioManager.shared.transcribedText = ""
            }
        } catch {
            Logger(subsystem: "a-do", category: "HomeView").error("Voice reminder creation failed: \(error.localizedDescription)")
        }
    }

    private func stopQuickVoiceMemo() {
        AudioManager.shared.stopRecording()
    }
}

// MARK: - Home Summary Card (Apple Reminders style)
struct HomeSummaryCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    var count: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(iconColor, in: Circle())

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.title.bold())
                        .foregroundStyle(Color(.label))
                }
            }

            Spacer()

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 85)
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
