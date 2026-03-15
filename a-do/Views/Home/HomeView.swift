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

    private var pendingCount: Int {
        allReminders.count
    }

    private var headerDateLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var heroSubtitle: String {
        if pendingCount == 0 {
            return "You are clear for now. Capture anything new before it slips away."
        }

        if todayReminders.isEmpty {
            return "\(pendingCount) open reminder\(pendingCount == 1 ? "" : "s") waiting, with \(inboxReminders.count) sitting in your inbox."
        }

        return "\(todayReminders.count) due today and \(inboxReminders.count) more waiting in your inbox."
    }

    private var featureColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 14),
            count: horizontalSizeClass == .regular ? 3 : 2
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                homeBackground

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        heroSection
                        quickAddSection
                        overviewSection
                        toolsSection
                        intelligenceSection

                        if !EntitlementManager.shared.isProUser {
                            proUpgradeSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                        HomeToolbarButtonLabel(systemName: "ellipsis")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 0) {
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
                            HomeToolbarButtonLabel(
                                systemName: AudioManager.shared.isRecording ? "stop.fill" : "mic.fill",
                                tint: AudioManager.shared.isRecording ? .red : AppTheme.Colors.primary
                            )
                        }

                        Rectangle()
                            .fill(AppTheme.Colors.primary.opacity(0.18))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 4)

                        Button {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showingReminderForm = true
                        } label: {
                            HomeToolbarButtonLabel(systemName: "plus", tint: AppTheme.Colors.primary)
                        }
                        .accessibilityLabel("Add Reminder")
                    }
                    .padding(4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.Colors.primary.opacity(0.12), lineWidth: 1)
                    )
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
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Spacer()

                        Button("Undo") {
                            viewModel.undoLastQuickCapture(context: context)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.Colors.primary.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var homeBackground: some View {
        ZStack {
            AppTheme.Gradients.background
                .ignoresSafeArea()

            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 140, y: -220)

            Circle()
                .fill(AppTheme.Colors.secondary.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 48)
                .offset(x: -170, y: 280)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 420, height: 220)
                .rotationEffect(.degrees(18))
                .offset(x: 110, y: 430)
                .blur(radius: 20)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(greetingTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(heroSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 12) {
                    Text(headerDateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.14), in: Capsule())

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(pendingCount == 0 ? "CLEAR" : "\(pendingCount)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(pendingCount == 1 ? "open task" : "open tasks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }

            HStack(spacing: 10) {
                HeroMetricPill(title: "Today", value: "\(todayReminders.count)", systemImage: "calendar")
                HeroMetricPill(title: "Inbox", value: "\(inboxReminders.count)", systemImage: "tray")
                HeroMetricPill(title: "Lists", value: "\(allReminders.count)", systemImage: "square.stack.3d.up")
            }

            HStack(spacing: 12) {
                Button {
                    showingReminderForm = true
                } label: {
                    HeroActionButton(
                        title: "New Reminder",
                        subtitle: "Open the full composer",
                        systemImage: "plus.circle.fill",
                        isPrimary: true
                    )
                }
                .buttonStyle(.plain)

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
                    HeroActionButton(
                        title: AudioManager.shared.isRecording ? "Stop Listening" : "Voice Capture",
                        subtitle: AudioManager.shared.isRecording ? "Tap to finish recording" : "Turn speech into reminders",
                        systemImage: AudioManager.shared.isRecording ? "waveform.circle.fill" : "mic.circle.fill",
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.primary,
                            AppTheme.Colors.primaryLight,
                            AppTheme.Colors.secondary.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.Colors.primary.opacity(0.18), radius: 24, x: 0, y: 16)
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                eyebrow: "At A Glance",
                title: "Today’s landscape",
                subtitle: "Your most important buckets, surfaced before you have to think about them."
            )

            summaryGrid
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            NavigationLink(destination: TodayView()) {
                HomeSummaryCard(
                    title: "Today",
                    subtitle: "Tasks due in the next 24 hours",
                    icon: "calendar",
                    iconColor: .blue,
                    metric: "\(todayReminders.count)"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: InboxView()) {
                HomeSummaryCard(
                    title: "Inbox",
                    subtitle: "Unscheduled reminders waiting for direction",
                    icon: "tray",
                    iconColor: .gray,
                    metric: "\(inboxReminders.count)"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ListsView()) {
                HomeSummaryCard(
                    title: "All Lists",
                    subtitle: "Everything active across your system",
                    icon: "folder",
                    iconColor: .purple,
                    metric: "\(allReminders.count)"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CompletedRemindersView()) {
                HomeSummaryCard(
                    title: "Completed",
                    subtitle: "Review what shipped and clean up the archive",
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    metric: "Review"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                eyebrow: "Workflows",
                title: "Tools",
                subtitle: "Jump into the modes that help you plan, focus, and move faster."
            )

            LazyVGrid(columns: featureColumns, spacing: 14) {
                NavigationLink(destination: FocusDashboardView()) {
                    homeFeatureTile(
                        icon: "scope",
                        title: "Focus Mode",
                        subtitle: "Deep work sessions",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: TimeTrackingView()) {
                    homeFeatureTile(
                        icon: "timer",
                        title: "Time Tracking",
                        subtitle: "See where time goes",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: TemplatesView()) {
                    homeFeatureTile(
                        icon: "doc.on.doc",
                        title: "Templates",
                        subtitle: "Reuse strong routines",
                        color: .cyan
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SmartSearchView()) {
                    homeFeatureTile(
                        icon: "magnifyingglass",
                        title: "Smart Search",
                        subtitle: "Find anything naturally",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ShadowInboxView()) {
                    homeFeatureTile(
                        icon: "tray.full",
                        title: "Shadow Inbox",
                        subtitle: "Catch loose ideas fast",
                        color: .indigo
                    )
                }
                .buttonStyle(.plain)

                Button { showingCollaboration = true } label: {
                    homeFeatureTile(
                        icon: "person.2",
                        title: "Collaboration",
                        subtitle: "Plan together",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Intelligence Section

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                eyebrow: "AI Layer",
                title: "Intelligence",
                subtitle: "Use the app as a thinking partner, not just a place to store tasks."
            )

            LazyVGrid(columns: featureColumns, spacing: 14) {
                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAISuggestions = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    homeFeatureTile(
                        icon: "sparkles",
                        title: "AI Suggestions",
                        subtitle: "Surface the next smart move",
                        color: .blue,
                        locked: !EntitlementManager.shared.hasAccess(to: .advancedNLP)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAIInsights = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    homeFeatureTile(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "AI Insights",
                        subtitle: "See patterns in your system",
                        color: .indigo,
                        locked: !EntitlementManager.shared.hasAccess(to: .advancedNLP)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if EntitlementManager.shared.hasAccess(to: .dailyPlanning) {
                        showingDailyPlanning = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    homeFeatureTile(
                        icon: "sun.max",
                        title: "Daily Planning",
                        subtitle: "Shape the day before it shapes you",
                        color: .orange,
                        locked: !EntitlementManager.shared.hasAccess(to: .dailyPlanning)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if EntitlementManager.shared.isProUser {
                        showingMorningBriefing = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    homeFeatureTile(
                        icon: "sunrise",
                        title: "Morning Briefing",
                        subtitle: "Start with a tailored overview",
                        color: .yellow,
                        locked: !EntitlementManager.shared.isProUser
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pro Upgrade

    private var proUpgradeSection: some View {
        Button { showingPaywall = true } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.Colors.secondary.opacity(0.12), in: Capsule())

                    Text("Upgrade to Pro")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("Unlock AI features, voice workflows, and unlimited habits.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.secondary, AppTheme.Colors.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .padding(20)
            .background(HomePanelBackground(accent: AppTheme.Colors.secondary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeader(
                eyebrow: "Capture",
                title: "Quick add",
                subtitle: "Type naturally, dictate out loud, or set a date before the thought disappears."
            )

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.2), .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    if viewModel.isPreparingQuickCapture {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }

                TextField("What needs to happen?", text: $viewModel.quickTitle, axis: .vertical)
                    .font(.body.weight(.medium))
                    .focused($isQuickAddFocused)
                    .submitLabel(.done)
                    .lineLimit(1...3)
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
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.Gradients.primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPreparingQuickCapture)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.Colors.surface.opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                    )
            )

            if isQuickAddFocused || !viewModel.quickTitle.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add timing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                ("Today", "today", "sun.max.fill", viewModel.quickDueDate.map { Calendar.current.isDateInToday($0) } ?? false),
                                ("Tomorrow", "tomorrow", "sun.haze.fill", viewModel.quickDueDate.map { Calendar.current.isDateInTomorrow($0) } ?? false),
                                ("Pick Date", "pick", "calendar.badge.clock", viewModel.quickDueDate.map { date in
                                    !Calendar.current.isDateInToday(date) && !Calendar.current.isDateInTomorrow(date)
                                } ?? false)
                            ], id: \.0) { title, action, icon, isSelected in
                                Button {
                                    switch action {
                                    case "today": viewModel.setQuickDueDateToToday()
                                    case "tomorrow": viewModel.setQuickDueDateToTomorrow()
                                    case "pick": viewModel.showingQuickDatePicker = true
                                    default: break
                                    }
                                } label: {
                                    Label(title, systemImage: icon)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(
                                            isSelected ? AppTheme.Gradients.primary : LinearGradient(
                                                colors: [AppTheme.Colors.surface, AppTheme.Colors.surfaceLight.opacity(0.75)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(
                                                    isSelected ? .clear : AppTheme.Colors.primary.opacity(0.14),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }

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
                                Label(
                                    AudioManager.shared.isRecording ? "Stop" : "Dictate",
                                    systemImage: AudioManager.shared.isRecording ? "waveform.circle.fill" : "mic.fill"
                                )
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    (AudioManager.shared.isRecording ? Color.red : AppTheme.Colors.secondary).opacity(0.14),
                                    in: Capsule()
                                )
                                .foregroundStyle(AudioManager.shared.isRecording ? Color.red : AppTheme.Colors.secondary)
                            }
                            .buttonStyle(.plain)

                            if viewModel.quickDueDate != nil {
                                Button {
                                    viewModel.clearQuickDueDate()
                                } label: {
                                    Label("Clear", systemImage: "xmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(AppTheme.Colors.textSecondary.opacity(0.12), in: Capsule())
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if AudioManager.shared.isRecording || !AudioManager.shared.liveTranscription.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: AudioManager.shared.isRecording ? "waveform.circle.fill" : "mic.badge.checkmark")
                        .foregroundStyle(AudioManager.shared.isRecording ? Color.red : AppTheme.Colors.success)

                    Text(AudioManager.shared.liveTranscription.isEmpty ? "Listening…" : AudioManager.shared.liveTranscription)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, 2)
                .transition(.opacity)
            }
        }
        .padding(22)
        .background(HomePanelBackground(accent: AppTheme.Colors.primary))
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: isQuickAddFocused)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: viewModel.quickTitle.isEmpty)
    }

    private func homeFeatureTile(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        locked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.16))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(color)
                }

                Spacer()

                Image(systemName: locked ? "lock.fill" : "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(locked ? AppTheme.Colors.secondary : AppTheme.Colors.textTertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(HomePanelBackground(accent: color))
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

private struct HomeToolbarButtonLabel: View {
    let systemName: String
    var tint: Color = AppTheme.Colors.primary

    var body: some View {
        Image(systemName: systemName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.18), in: Circle())
    }
}

private struct HomeSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .tracking(0.8)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HeroMetricPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))

                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct HeroActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))

                Text(subtitle)
                    .font(.caption)
                    .opacity(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(isPrimary ? AppTheme.Colors.textPrimary : Color.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isPrimary ? AnyShapeStyle(Color.white.opacity(0.96)) : AnyShapeStyle(Color.white.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isPrimary ? .white.opacity(0.35) : .white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct HomePanelBackground: View {
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface.opacity(0.98),
                        AppTheme.Colors.surfaceLight.opacity(0.82),
                        accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.58), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.10), radius: 18, x: 0, y: 12)
    }
}

struct HomeSummaryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let metric: String

    private var metricFont: Font {
        metric.count > 4
            ? .title3.weight(.bold)
            : .system(size: 34, weight: .bold, design: .rounded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(iconColor)
                }

                Spacer()

                Text(metric)
                    .font(metricFont)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(HomePanelBackground(accent: iconColor))
    }
}
