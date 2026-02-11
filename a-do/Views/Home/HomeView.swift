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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Gradients.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header
                        GreetingHeader(name: profiles.first?.displayName ?? "Traveler")
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Voice Reminder - Prominent
                        voiceReminderSection
                            .padding(.horizontal)
                        
                        // Quick Add - Clean
                        quickActionsSection
                            .padding(.horizontal)
                        
                        // Quick Access Cards
                        quickAccessSection
                            .padding(.horizontal)
                        
                        // Pro Upgrade Banner (if needed)
                        proUpgradeSection
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Section("Features") {
                            NavigationLink(destination: CompletedRemindersView()) {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                            }
                            
                            NavigationLink(destination: SmartSearchView()) {
                                Label("Smart Search", systemImage: "magnifyingglass.circle")
                            }
                            
                            NavigationLink(destination: TimeTrackingView()) {
                                Label("Time Tracking", systemImage: "timer")
                            }

                            NavigationLink(destination: FocusDashboardView()) {
                                Label("Focus", systemImage: "target")
                            }

                            NavigationLink(destination: ShadowInboxView()) {
                                Label("Shadow Inbox", systemImage: "tray.full")
                            }
                            
                            Button {
                                showingCollaboration = true
                            } label: {
                                Label("Collaboration", systemImage: "person.2.circle")
                            }
                        }
                        
                        Section("AI Features") {
                            Button {
                                if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                                    showingAIInsights = true
                                } else {
                                    showingPaywall = true
                                }
                            } label: {
                                Label("AI Insights", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showingReminderForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                            .font(.title3)
                    }
                    .accessibilityLabel("Add Reminder")
                }
            }
            .onAppear {
                cloudKitManager.loadSyncSetting(context: context)
                loadRemindersAsync()
            }
            .task {
                await loadRemindersInBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReminderCreated"))) { _ in
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
    }
    
    // MARK: - Greeting Header
    struct GreetingHeader: View {
        let name: String
        
        var greeting: String {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 0..<12: return "Good Morning"
            case 12..<17: return "Good Afternoon"
            default: return "Good Evening"
            }
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(AppTheme.Typography.title1)
                        .primaryText()
                    Text("\(greeting), \(name).")
                        .font(AppTheme.Typography.subheadline)
                        .secondaryText()
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Voice Reminder Section
    private var voiceReminderSection: some View {
        GlassCard {
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
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AudioManager.shared.isRecording ? Color.red : AppTheme.Colors.primary)
                            .frame(width: 48, height: 48)
                            .shadow(color: (AudioManager.shared.isRecording ? Color.red : AppTheme.Colors.primary).opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: AudioManager.shared.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AudioManager.shared.isRecording ? "Recording..." : "Voice Reminder")
                            .font(.headline)
                            .primaryText()
                        
                        if AudioManager.shared.isRecording {
                            Text("\(Int(AudioManager.shared.recordingDuration))s")
                                .font(.caption)
                                .secondaryText()
                        } else {
                            Text("Tap to speak")
                                .font(.caption)
                                .secondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    if AudioManager.shared.isTranscribing {
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Quick reminder...", text: $viewModel.quickTitle)
                        .textFieldStyle(.plain)
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
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                }
                .padding(12)
                .background(AppTheme.Colors.surfaceLight)
                .cornerRadius(12)
                
                // Quick Date Options
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
                                    .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surfaceLight)
                                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if let dueDate = viewModel.quickDueDate {
                            Button {
                                viewModel.clearQuickDueDate()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Quick Access Section
    private var quickAccessSection: some View {
        VStack(spacing: 12) {
            // Row 1: Inbox and Today
            HStack(spacing: 12) {
                NavigationLink(destination: InboxView()) {
                    QuickAccessCard(
                        title: "Inbox",
                        icon: "tray.fill",
                        color: .blue,
                        count: inboxReminders.count
                    )
                }
                
                NavigationLink(destination: TodayView()) {
                    QuickAccessCard(
                        title: "Today",
                        icon: "calendar",
                        color: .orange,
                        count: todayReminders.count
                    )
                }
            }
            
            // Row 2: Lists and Templates
            HStack(spacing: 12) {
                NavigationLink(destination: ListsView()) {
                    QuickAccessCard(
                        title: "Lists",
                        icon: "folder.fill",
                        color: .purple,
                        count: nil
                    )
                }
                
                NavigationLink(destination: TemplatesView()) {
                    QuickAccessCard(
                        title: "Templates",
                        icon: "doc.text.below.ecg",
                        color: .indigo,
                        count: nil
                    )
                }
            }

            // Row 3: Focus and Time Tracking
            HStack(spacing: 12) {
                NavigationLink(destination: FocusDashboardView()) {
                    QuickAccessCard(
                        title: "Focus",
                        icon: "target",
                        color: .mint,
                        count: nil
                    )
                }

                NavigationLink(destination: TimeTrackingView()) {
                    QuickAccessCard(
                        title: "Time Tracking",
                        icon: "timer",
                        color: .cyan,
                        count: nil
                    )
                }
            }
            
            // Row 4: AI Suggestions and Daily Planning (Pro features)
            HStack(spacing: 12) {
                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAISuggestions = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    QuickAccessCard(
                        title: "AI Suggestions",
                        icon: "sparkles",
                        color: .pink,
                        count: nil,
                        isLocked: !EntitlementManager.shared.hasAccess(to: .advancedNLP)
                    )
                }
                
                Button {
                    if EntitlementManager.shared.hasAccess(to: .dailyPlanning) {
                        showingDailyPlanning = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    QuickAccessCard(
                        title: "Daily Planning",
                        icon: "sun.max.fill",
                        color: .yellow,
                        count: nil,
                        isLocked: !EntitlementManager.shared.hasAccess(to: .dailyPlanning)
                    )
                }
            }
            
            // Row 5: Morning Briefing (Pro feature)
            Button {
                if EntitlementManager.shared.isProUser {
                    showingMorningBriefing = true
                } else {
                    showingPaywall = true
                }
            } label: {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning Briefing")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(.white)
                        Text("Your personalized daily overview")
                            .font(AppTheme.Typography.caption1)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if !EntitlementManager.shared.isProUser {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Pro Upgrade Section
    private var proUpgradeSection: some View {
        Group {
            if !EntitlementManager.shared.isProUser {
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .primaryText()
                            Text("Unlock AI features & unlimited habits")
                                .font(.caption)
                                .secondaryText()
                        }
                        Spacer()
                        Button {
                            showingPaywall = true
                        } label: {
                            Text("Upgrade")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.Gradients.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
            }
        }
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
        // Wait for recording and transcription to complete
        while AudioManager.shared.isRecording || AudioManager.shared.isTranscribing {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
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

        var createdAny = false
        for (index, baseRequest) in parsedRequests.enumerated() {
            var request = baseRequest
            if request.dueDate == nil {
                request.dueDate = viewModel.quickDueDate
            }

            // Attach the recording to the first generated task.
            if index == 0, let audioFileURL = AudioManager.shared.getAudioFileURL() {
                request.voiceReminder = VoiceReminder(
                    audioFileName: audioFileURL.lastPathComponent,
                    transcribedText: text,
                    recordingDuration: AudioManager.shared.recordingDuration
                )
            }

            do {
                _ = try await ReminderCreationService.shared.createReminder(request: request, in: context)
                createdAny = true
            } catch {
                Logger(subsystem: "a-do", category: "HomeView").error("Voice reminder creation failed: \(error.localizedDescription)")
            }
        }

        if createdAny {
            AudioManager.shared.transcribedText = ""
        }
    }
    
    private func stopQuickVoiceMemo() {
        AudioManager.shared.stopRecording()
    }
}

// MARK: - Quick Access Card Component
struct QuickAccessCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int?
    var isLocked: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                if let count = count {
                    Text("\(count) items")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let count = count, count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
}
