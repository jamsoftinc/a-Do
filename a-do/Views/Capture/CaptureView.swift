import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted })
    private var recentReminders: [Reminder]

    @State private var captureText = ""
    @State private var showingReminderForm = false
    @State private var showingPaywall = false
    @State private var showingSettings = false
    @FocusState private var isTextFieldFocused: Bool

    @State private var viewModel = ReminderHomeViewModel()

    private var inboxReminders: [Reminder] {
        Array(recentReminders.filter { $0.dueDate == nil }.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    inputCard
                    suggestedContextSection
                    quickActionsSection
                    inboxSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { profileAvatar }
                }
                ToolbarItem(placement: .principal) {
                    Text("A-do")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
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
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack { ReminderFormView() }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsPageView() }
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEW ENTRY")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .tracking(1.0)

            Text("What's on your\nmind?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 16) {
            TextField("Type a task, thought, or memo...", text: $captureText, axis: .vertical)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(3...6)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    if !captureText.isEmpty {
                        createReminder()
                    }
                }

            Divider()

            HStack(spacing: 24) {
                Button {
                    if EntitlementManager.shared.hasAccess(to: .voiceReminders) {
                        Task { await startVoiceCapture() }
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Label("Voice", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .buttonStyle(.plain)

                Button {
                    showingReminderForm = true
                } label: {
                    Label("Handwrite", systemImage: "pencil.line")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .buttonStyle(.plain)

                Button {
                    showingReminderForm = true
                } label: {
                    Label("Scan", systemImage: "doc.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Suggested Context

    private var suggestedContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUGGESTED CONTEXT")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    contextChip(icon: "briefcase.fill", label: "Work Project", color: .orange)
                    contextChip(icon: "cart.fill", label: "Groceries", color: AppTheme.Colors.primary)
                    contextChip(icon: "figure.walk", label: "Wellness", color: .purple)
                    contextChip(icon: "exclamationmark.triangle.fill", label: "Urgent", color: AppTheme.Colors.error)
                }
            }
        }
    }

    private func contextChip(icon: String, label: String, color: Color) -> some View {
        Button {
            captureText += captureText.isEmpty ? label : " #\(label)"
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.bold))
                Text("QUICK ACTIONS")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundStyle(AppTheme.Colors.textTertiary)

            GlassCard {
                VStack(spacing: 0) {
                    quickActionRow(label: "Remind me tonight") {
                        captureText = captureText.isEmpty ? "Remind me tonight" : captureText
                        viewModel.quickDueDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())
                        createReminder()
                    }
                    Divider().padding(.leading, 16)
                    quickActionRow(label: "Add to Shared List") {
                        showingReminderForm = true
                    }
                    Divider().padding(.leading, 16)
                    quickActionRow(label: "Email to Self") {
                        showingReminderForm = true
                    }
                }
            }
        }
    }

    private func quickActionRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inbox Section

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UNORGANIZED INBOX")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .tracking(0.5)

                Spacer()

                Button("Clear all") {}
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.error)
            }

            if inboxReminders.isEmpty {
                GlassCard {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                            Text("Inbox is empty")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(inboxReminders, id: \.uuid) { reminder in
                        inboxItemRow(reminder: reminder)
                    }
                }
            }
        }
    }

    private func inboxItemRow(reminder: Reminder) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(captureSourceColor(for: reminder).opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: captureSourceIcon(for: reminder))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(captureSourceColor(for: reminder))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("Captured \(timeAgo(from: reminder.createdAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private func captureSourceIcon(for reminder: Reminder) -> String {
        if reminder.voiceReminder != nil { return "mic.fill" }
        return "text.justify.left"
    }

    private func captureSourceColor(for reminder: Reminder) -> Color {
        if reminder.voiceReminder != nil { return .red }
        return AppTheme.Colors.primary
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    // MARK: - Actions

    private func createReminder() {
        guard !captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.quickTitle = captureText
        viewModel.addQuickReminder(context: context)
        captureText = ""
        isTextFieldFocused = false
    }

    private func startVoiceCapture() async {
        await AudioManager.shared.startRecording()
    }
}
