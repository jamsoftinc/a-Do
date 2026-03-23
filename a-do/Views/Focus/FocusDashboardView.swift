import SwiftUI
import SwiftData

struct FocusDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\FocusSession.startTime, order: .reverse)]) private var recentSessions: [FocusSession]
    @Query(sort: [SortDescriptor(\Reminder.dueDate), SortDescriptor(\Reminder.createdAt, order: .reverse)]) private var reminders: [Reminder]

    @State private var aiManager = AIManager.shared
    @State private var focusManager = FocusModeManager.shared
    @State private var selectedDurationMinutes: Int = 25
    @State private var selectedFocusType: FocusType = .work
    @State private var optimizedOrder: [UUID] = []
    @State private var isOptimizingQueue = false

    private let quickDurations = [15, 25, 45, 60]

    private var focusStats: FocusStatistics {
        focusManager.getFocusStatistics(context: context, days: 7)
    }

    private var sessionCandidates: [Reminder] {
        let baseCandidates = reminders
            .filter { !$0.isCompleted }
            .sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (lhs?, rhs?): return lhs < rhs
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return $0.createdAt > $1.createdAt
                }
            }
        let ranked: [Reminder]
        if optimizedOrder.isEmpty {
            ranked = baseCandidates
        } else {
            let rankMap = Dictionary(uniqueKeysWithValues: optimizedOrder.enumerated().map { ($1, $0) })
            ranked = baseCandidates.sorted { lhs, rhs in
                let lhsRank = rankMap[lhs.uuid] ?? Int.max
                let rhsRank = rankMap[rhs.uuid] ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.createdAt > rhs.createdAt
                }
            }
        }

        return Array(ranked.prefix(8))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                activeSessionCard
                quickStartCard
                statsCard
                reminderQueueCard
                recentSessionsCard
            }
            .padding()
        }
        .background(AppTheme.Gradients.background.ignoresSafeArea())
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            optimizeSessionQueue()
        }
        .onChange(of: selectedFocusType) { _, _ in
            optimizeSessionQueue()
        }
        .onChange(of: reminders.count) { _, _ in
            optimizeSessionQueue()
        }
        .onDisappear {
            focusManager.cleanup()
        }
    }

    private var activeSessionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Active Session", systemImage: "target")
                        .font(.headline)
                    Spacer()
                    statusBadge
                }

                if let session = focusManager.currentSession {
                    Text(session.name)
                        .font(AppTheme.Typography.title3)
                        .primaryText()

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(formattedTime(focusManager.sessionTimeRemaining))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Colors.primary)
                    }

                    HStack(spacing: 10) {
                        if focusManager.isSessionActive {
                            Button("Pause") {
                                focusManager.pauseSession(context: context)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Resume") {
                                focusManager.resumeSession(context: context)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Complete") {
                            focusManager.endSession(context: context)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("No active session. Start one below to enter focused work mode.")
                        .font(.subheadline)
                        .secondaryText()
                }
            }
            .padding()
        }
    }

    private var statusBadge: some View {
        Text(focusManager.isSessionActive ? "Running" : "Idle")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(focusManager.isSessionActive ? AppTheme.Colors.success.opacity(0.2) : AppTheme.Colors.surfaceLight)
            .foregroundStyle(focusManager.isSessionActive ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
            .clipShape(Capsule())
    }

    private var quickStartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start")
                    .font(.headline)
                    .primaryText()

                Picker("Focus Type", selection: $selectedFocusType) {
                    ForEach(FocusType.allCases, id: \.self) { focusType in
                        Text(focusType.displayName).tag(focusType)
                    }
                }
                .pickerStyle(.menu)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickDurations, id: \.self) { duration in
                            Button {
                                selectedDurationMinutes = duration
                            } label: {
                                Text("\(duration)m")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedDurationMinutes == duration ? AppTheme.Colors.primary : AppTheme.Colors.surfaceLight)
                                    .foregroundStyle(selectedDurationMinutes == duration ? Color.white : AppTheme.Colors.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Button {
                    startQuickSession()
                } label: {
                    Label("Start \(selectedDurationMinutes)-Minute Session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(focusManager.isSessionActive)
            }
            .padding()
        }
    }

    private var statsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 Days")
                    .font(.headline)
                    .primaryText()

                HStack(spacing: 12) {
                    statPill(title: "Sessions", value: "\(focusStats.totalSessions)")
                    statPill(title: "Completion", value: "\(Int(focusStats.completionRate * 100))%")
                    statPill(title: "Focus Time", value: "\(Int(focusStats.totalFocusTime / 3600))h")
                }
            }
            .padding()
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .primaryText()
            Text(title)
                .font(.caption)
                .secondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    private var reminderQueueCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Suggested Session Queue")
                        .font(.headline)
                        .primaryText()

                    Spacer()

                    if EntitlementManager.shared.isProUser {
                        Label(isOptimizingQueue ? "Optimizing" : "AI Optimized", systemImage: isOptimizingQueue ? "hourglass" : "sparkles")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                if sessionCandidates.isEmpty {
                    Text("No open reminders. Great time for planning or deep work.")
                        .font(.subheadline)
                        .secondaryText()
                } else {
                    ForEach(sessionCandidates) { reminder in
                        HStack {
                            Circle()
                                .fill(AppTheme.priorityColor(reminder.priority))
                                .frame(width: 8, height: 8)
                            Text(reminder.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            if let dueDate = reminder.dueDate {
                                Text(dueDate, style: .time)
                                    .font(.caption)
                                    .secondaryText()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var recentSessionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Sessions")
                    .font(.headline)
                    .primaryText()

                if recentSessions.isEmpty {
                    Text("No focus sessions yet.")
                        .font(.subheadline)
                        .secondaryText()
                } else {
                    ForEach(recentSessions.prefix(5)) { session in
                        HStack {
                            Text(session.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(session.actualDuration / 60)) min")
                                .font(.caption)
                                .secondaryText()
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func startQuickSession() {
        let duration = Double(selectedDurationMinutes * 60)
        let template = FocusTemplate(
            name: "\(selectedFocusType.displayName) Focus",
            focusType: selectedFocusType,
            duration: duration
        )
        let selectedReminders = Array(sessionCandidates.prefix(6))
        focusManager.startSession(template: template, reminders: selectedReminders, context: context)
    }

    private func optimizeSessionQueue() {
        guard EntitlementManager.shared.isProUser else {
            optimizedOrder = []
            return
        }

        let candidates = reminders.filter { !$0.isCompleted }
        guard !candidates.isEmpty else {
            optimizedOrder = []
            return
        }

        guard !isOptimizingQueue else { return }
        isOptimizingQueue = true

        Task {
            let ordered = await aiManager.rankRemindersForFocus(candidates, focusType: selectedFocusType)
            await MainActor.run {
                optimizedOrder = ordered
                isOptimizingQueue = false
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let safeInterval = max(0, Int(interval))
        let minutes = safeInterval / 60
        let seconds = safeInterval % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        FocusDashboardView()
            .modelContainer(for: [FocusSession.self, Reminder.self], inMemory: true)
    }
}
