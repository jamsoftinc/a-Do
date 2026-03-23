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
    @Query(filter: #Predicate<Habit> { $0.isActive }) private var activeHabits: [Habit]
    private var cloudKitManager = CloudKitManager.shared
    private var calendarManager = CalendarManager.shared

    @State private var inboxReminders: [Reminder] = []
    @State private var todayReminders: [Reminder] = []
    @State private var allReminders: [Reminder] = []
    @State private var lastUpdateDate: Date = Date()
    @State private var isLoadingReminders: Bool = false

    @State private var viewModel = ReminderHomeViewModel()
    @State private var behavioralLearning = BehavioralLearningManager.shared
    @Environment(AppRouter.self) private var router
    @FocusState private var isQuickAddFocused: Bool

    @State private var showingPaywall = false
    @State private var showingReminderForm = false
    @State private var showingSettings = false
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
        case 0..<12: return "Good Morning\(name.isEmpty ? "" : ",\n\(name)")"
        case 12..<17: return "Good Afternoon\(name.isEmpty ? "" : ",\n\(name)")"
        default: return "Good Evening\(name.isEmpty ? "" : ",\n\(name)")"
        }
    }

    private var dateLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }

    private var nextEvent: EKEvent? {
        calendarManager.todayEvents.first { event in
            event.endDate > Date()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    aiQuickGlanceCard
                    nextMeetingCard
                    topTasksSection
                    habitProgressSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        profileAvatar
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("A-do")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
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
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack { ReminderFormView() }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsPageView() }
            }
            .sheet(isPresented: $showingCollaboration) {
                NavigationStack { CollaborationView() }
            }
            .sheet(isPresented: $showingAISuggestions) {
                NavigationStack { AISuggestionsViewWrapper() }
            }
            .sheet(isPresented: $showingAIInsights) {
                AIInsightsDashboardWrapper()
            }
            .sheet(isPresented: $showingDailyPlanning) {
                NavigationStack { DailyPlanningView() }
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
                            Button("Cancel") { viewModel.showingQuickDatePicker = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { viewModel.showingQuickDatePicker = false }
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
                    onCancel: { viewModel.cancelQuickCaptureReview() },
                    onConfirm: {
                        Task { await viewModel.commitQuickCapture(context: context) }
                    }
                )
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .tracking(1.0)

            Text(greetingTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - AI Quick Glance

    private var aiQuickGlanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                Text("AI QUICK GLANCE")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white.opacity(0.9))

            Text(aiSuggestionText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                    showingAISuggestions = true
                } else {
                    showingPaywall = true
                }
            } label: {
                Text("Optimize Schedule")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.1))
                .offset(x: -16, y: -16)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl, style: .continuous))
    }

    private var aiSuggestionText: String {
        if todayReminders.count > 3 {
            return "You have a busy morning, maybe schedule a focus session at 11 AM?"
        } else if todayReminders.isEmpty {
            return "Your day is clear. Great time to tackle something from your inbox."
        } else {
            return "You have \(todayReminders.count) task\(todayReminders.count == 1 ? "" : "s") today. Stay focused and you will be done early."
        }
    }

    // MARK: - Next Meeting

    private var nextMeetingCard: some View {
        Group {
            if let event = nextEvent {
                GlassCard {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("NEXT MEETING")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                                    .tracking(0.5)
                                Spacer()
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.primary)
                            }

                            Text(event.title ?? "Meeting")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(formatEventTime(event))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            if let organizer = event.organizer?.name {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(AppTheme.Colors.success)
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Text(String(organizer.prefix(1)).uppercased())
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    Text("With \(organizer)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatEventTime(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end)"
    }

    // MARK: - Top Tasks

    private var topTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Tasks")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                NavigationLink(destination: TodayView()) {
                    Text("View All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            GlassCard {
                VStack(spacing: 0) {
                    let topTasks = Array(todayReminders.sorted { r1, r2 in
                        r1.priority.rawValue > r2.priority.rawValue
                    }.prefix(5))

                    if topTasks.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.Colors.success)
                                Text("All clear for today")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(topTasks, id: \.uuid) { reminder in
                            TaskRow(
                                title: reminder.title,
                                isCompleted: reminder.isCompleted,
                                priority: reminder.priority
                            ) {
                                withAnimation {
                                    reminder.isCompleted.toggle()
                                    reminder.completedAt = reminder.isCompleted ? Date() : nil
                                    try? context.save()
                                    behavioralLearning.trackAction(.taskCompleted, modelContext: context)
                                }
                            }

                            if reminder.uuid != topTasks.last?.uuid {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Habit Progress

    private var habitProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Habit Progress")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()
            }

            GlassCard {
                VStack(spacing: 4) {
                    let displayHabits = Array(activeHabits.prefix(4))

                    if displayHabits.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "flame")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.Colors.secondary)
                                Text("No active habits yet")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(displayHabits, id: \.id) { habit in
                            let progress = habitProgress(for: habit)
                            let completed = progress >= 1.0

                            HabitProgressRow(
                                icon: habit.icon,
                                iconColor: habitColor(for: habit),
                                name: habit.title,
                                progressText: habitProgressText(for: habit),
                                progress: progress,
                                isCompleted: completed
                            )
                        }
                    }
                }
            }
        }
    }

    private func habitProgress(for habit: Habit) -> Double {
        guard Double(habit.targetCount) > 0 else { return 0 }
        let todayEntries = habit.entries?.filter { entry in
            Calendar.current.isDateInToday(entry.date)
        } ?? []
        let totalValue = todayEntries.reduce(0.0) { $0 + Double($1.count) }
        return totalValue / Double(habit.targetCount)
    }

    private func habitProgressText(for habit: Habit) -> String {
        let todayEntries = habit.entries?.filter { entry in
            Calendar.current.isDateInToday(entry.date)
        } ?? []
        let totalValue = todayEntries.reduce(0.0) { $0 + Double($1.count) }
        let target = Double(habit.targetCount)

        if !habit.unit.isEmpty {
            return "\(String(format: "%.1g", totalValue)) / \(String(format: "%.1g", target)) \(habit.unit)"
        }
        return "\(Int(totalValue)) / \(Int(target))"
    }

    private func habitColor(for habit: Habit) -> Color {
        Color(hex: habit.color) ?? AppTheme.Colors.primary
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

        inboxReminders = newInboxReminders
        todayReminders = newTodayReminders
        lastUpdateDate = now
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
            allReminders = loadedReminders
            updateFilteredReminders()
            isLoadingReminders = false
        }
    }

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
            if request.dueDate == nil { request.dueDate = viewModel.quickDueDate }
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
