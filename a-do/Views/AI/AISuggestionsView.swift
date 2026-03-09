//
//  AISuggestionsView.swift
//  a-do
//
//  AI suggestions interface with interactive features
//

import SwiftUI
import SwiftData
import Observation

struct AISuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var aiManager = AIManager.shared
    @State private var behavioralLearning = BehavioralLearningManager.shared
    @State private var selectedSuggestion: AISuggestion?
    @State private var showingFeedback = false
    @State private var feedbackText = ""
    @State private var feedbackRating = 3
    @State private var showingActionFeedback = false
    @State private var actionFeedbackMessage = ""
    
    // Filter states
    @State private var selectedPriority: AISuggestionPriority? = nil
    @State private var selectedType: AISuggestionType? = nil
    @State private var showOnlyActive = true
    
    @Query(sort: [
        SortDescriptor(\AISuggestion.priorityRaw, order: .reverse),
        SortDescriptor(\AISuggestion.confidence, order: .reverse),
        SortDescriptor(\AISuggestion.createdAt, order: .reverse)
    ]) private var allSuggestions: [AISuggestion]
    
    private var filteredSuggestions: [AISuggestion] {
        allSuggestions.filter { suggestion in
            if showOnlyActive && !suggestion.isActive {
                return false
            }
            
            if let priority = selectedPriority, suggestion.priority != priority {
                return false
            }
            
            if let type = selectedType, suggestion.type != type {
                return false
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with filters
                headerSection
                
                // Suggestions list
                if filteredSuggestions.isEmpty {
                    emptyStateView
                } else {
                    suggestionsList
                }
            }
            .navigationTitle("AI Suggestions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(item: $selectedSuggestion) { suggestion in
                SuggestionDetailView(suggestion: suggestion) { action in
                    handleSuggestionAction(suggestion: suggestion, action: action)
                }
            }
            .alert("Provide Feedback", isPresented: $showingFeedback) {
                feedbackAlert
            }
            .alert("Suggestion Updated", isPresented: $showingActionFeedback) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(actionFeedbackMessage)
            }
            .onAppear {
                refreshSuggestions()
            }
        }
    }

    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Stats overview
            statsOverview
            
            // Filters
            filtersSection
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var statsOverview: some View {
        HStack {
            statCard(
                title: "Active",
                value: "\(filteredSuggestions.filter { $0.isActive }.count)",
                color: .blue
            )
            
            statCard(
                title: "High Priority",
                value: "\(filteredSuggestions.filter { $0.priority == .high }.count)",
                color: .orange
            )
            
            statCard(
                title: "Applied Today",
                value: "\(suggestionsAppliedToday)",
                color: .green
            )
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Active toggle
                FilterChip(
                    title: "Active Only",
                    isSelected: showOnlyActive,
                    action: { showOnlyActive.toggle() }
                )
                
                // Priority filter
                Menu {
                    Button("All Priorities") {
                        selectedPriority = nil
                    }
                    
                    ForEach(AISuggestionPriority.allCases, id: \.self) { priority in
                        Button(priority.displayName) {
                            selectedPriority = priority
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedPriority?.displayName ?? "All Priorities",
                        isSelected: selectedPriority != nil,
                        action: {}
                    )
                }
                
                // Type filter
                Menu {
                    Button("All Types") {
                        selectedType = nil
                    }
                    
                    ForEach(AISuggestionType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            selectedType = type
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedType?.displayName ?? "All Types",
                        isSelected: selectedType != nil,
                        action: {}
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Suggestions List
    
    private var suggestionsList: some View {
        List {
            ForEach(filteredSuggestions, id: \.id) { suggestion in
                SuggestionRowView(suggestion: suggestion) { action in
                    handleSuggestionAction(suggestion: suggestion, action: action)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshSuggestionsAsync()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Suggestions")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("AI is analyzing your productivity patterns. Check back later for personalized suggestions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Generate Suggestions") {
                refreshSuggestions()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Computed Properties
    
    private var suggestionsAppliedToday: Int {
        let calendar = Calendar.current
        return allSuggestions.filter { suggestion in
            guard let appliedAt = suggestion.appliedAt else { return false }
            return calendar.isDateInToday(appliedAt)
        }.count
    }
    
    // MARK: - Actions
    
    private var refreshButton: some View {
        Button {
            refreshSuggestions()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(aiManager.isProcessing)
    }
    
    private func refreshSuggestions() {
        Task {
            await refreshSuggestionsAsync()
        }
    }
    
    private func refreshSuggestionsAsync() async {
        await aiManager.generateSuggestions(
            userId: SecurityUtils.getCurrentUserID(),
            context: modelContext
        )
    }
    
    private func handleSuggestionAction(suggestion: AISuggestion, action: SuggestionAction) {
        switch action {
        case .apply:
            Task {
                behavioralLearning.trackSuggestionInteraction(
                    suggestion: suggestion,
                    interaction: .applied,
                    modelContext: modelContext
                )

                let resultMessage = await applySuggestionEffect(suggestion)
                suggestion.apply()
                try? modelContext.save()

                await MainActor.run {
                    actionFeedbackMessage = resultMessage
                    showingActionFeedback = true
                }
            }
            
        case .dismiss:
            // Track user interaction before dismissing
            behavioralLearning.trackSuggestionInteraction(
                suggestion: suggestion,
                interaction: .dismissed,
                modelContext: modelContext
            )
            
            suggestion.dismiss()
            try? modelContext.save()
            
        case .showDetails:
            // Track implicit feedback for viewing details
            behavioralLearning.collectImplicitFeedback(
                suggestion: suggestion,
                action: .clickedDetails,
                modelContext: modelContext
            )
            
            selectedSuggestion = suggestion
            
        case .provideFeedback:
            selectedSuggestion = suggestion
            showingFeedback = true
        }
    }

    private func applySuggestionEffect(_ suggestion: AISuggestion) async -> String {
        switch suggestion.type {
        case .scheduleConflictResolution, .optimalTaskTiming, .dueDateOptimization, .deadlineWarning:
            guard let reminder = suggestion.targetReminder else {
                return "Applied. No target reminder was attached."
            }

            let proposedDate = CalendarManager.shared.suggestTimeForReminder(reminder) ??
                reminder.dueDate?.addingTimeInterval(60 * 60) ??
                Date().addingTimeInterval(60 * 60)

            reminder.dueDate = proposedDate

            if EntitlementManager.shared.canUseCalendarBlocking {
                await CalendarManager.shared.requestAccess()
                if CalendarManager.shared.accessGranted {
                    try? await CalendarManager.shared.updateTimeBlock(
                        for: reminder,
                        newStartDate: proposedDate,
                        newDuration: 30 * 60,
                        context: modelContext
                    )
                }
            }

            return "Rescheduled '\(reminder.title)' to \(proposedDate.formatted(date: .abbreviated, time: .shortened))."

        case .taskBreakdown:
            guard let reminder = suggestion.targetReminder else {
                return "Applied. No reminder found for task breakdown."
            }
            let breakdown = suggestion.getContextData(as: [String: [String]].self)?["suggestedTasks"] ?? []
            guard !breakdown.isEmpty else {
                return "Applied. No suggested subtasks were available."
            }

            let existing = Set((reminder.subtasks ?? []).map { $0.title.lowercased() })
            var added = 0
            for title in breakdown where !existing.contains(title.lowercased()) {
                if SubtasksManager.shared.addSubtask(to: reminder, title: title, context: modelContext) != nil {
                    added += 1
                }
            }
            return added > 0
                ? "Added \(added) subtasks to '\(reminder.title)'."
                : "No new subtasks were added."

        case .priorityAdjustment:
            guard let reminder = suggestion.targetReminder else {
                return "Applied. No reminder found for priority adjustment."
            }
            reminder.priority = .high
            return "Marked '\(reminder.title)' as high priority."

        case .workloadBalance:
            let descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate { !$0.isCompleted }
            )
            let reminders = (try? modelContext.fetch(descriptor)) ?? []
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            var movedCount = 0

            for reminder in reminders where movedCount < 3 {
                guard reminder.isOverdue || (reminder.dueDate.map { calendar.isDateInToday($0) } ?? false) else { continue }
                guard reminder.priority != .high else { continue }
                let hour = 10 + movedCount
                reminder.dueDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)
                movedCount += 1
            }
            return movedCount > 0
                ? "Rescheduled \(movedCount) lower-priority tasks to tomorrow."
                : "No tasks needed balancing."

        case .habitTiming, .habitStacking, .habitStreak, .habitDifficulty:
            guard let habit = suggestion.targetHabit else {
                return "Applied. No target habit was attached."
            }
            let note = "AI tip applied (\(Date().formatted(date: .abbreviated, time: .omitted))): \(suggestion.aiDescription)"
            habit.habitDescription = [habit.habitDescription, note]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            habit.updatedAt = Date()
            return "Updated habit plan for '\(habit.title)'."

        case .delegationSuggestion, .collaborationOpportunity:
            guard let reminder = suggestion.targetReminder else {
                return "Applied. No reminder found for collaboration suggestion."
            }
            reminder.autoTextTaggedContacts = true
            return "Enabled collaborator outreach for '\(reminder.title)'."

        case .tagSuggestion:
            let tagCandidates = extractSuggestedTags(from: suggestion.aiDescription)
            guard !tagCandidates.isEmpty else {
                return "Applied. No suggested tags could be parsed."
            }

            let reminderDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate { !$0.isCompleted }
            )
            let reminders = (try? modelContext.fetch(reminderDescriptor)) ?? []
            let untagged = reminders.filter { ($0.tags ?? []).isEmpty }
            guard !untagged.isEmpty else {
                return "Applied. No untagged reminders were found."
            }

            let tagDescriptor = FetchDescriptor<Tag>()
            let existingTags = (try? modelContext.fetch(tagDescriptor)) ?? []
            var tagByName = Dictionary(uniqueKeysWithValues: existingTags.map { ($0.name.lowercased(), $0) })

            var applied = 0
            for reminder in untagged.prefix(10) {
                var currentTags = reminder.tags ?? []
                for candidate in tagCandidates {
                    let normalized = candidate.lowercased()
                    let tag: Tag
                    if let existing = tagByName[normalized] {
                        tag = existing
                    } else {
                        let newTag = Tag(name: candidate)
                        modelContext.insert(newTag)
                        tagByName[normalized] = newTag
                        tag = newTag
                    }

                    if !currentTags.contains(where: { $0.name.lowercased() == normalized }) {
                        currentTags.append(tag)
                        applied += 1
                    }
                }
                reminder.tags = currentTags
            }

            return applied > 0
                ? "Applied \(applied) tag assignments to untagged reminders."
                : "No new tags were applied."

        default:
            return "Suggestion marked as applied."
        }
    }

    private func extractSuggestedTags(from description: String) -> [String] {
        let hashPattern = #"#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: hashPattern) {
            let nsRange = NSRange(description.startIndex..<description.endIndex, in: description)
            let tags = regex.matches(in: description, range: nsRange).compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: description) else { return nil }
                return String(description[range])
            }
            if !tags.isEmpty { return tags }
        }

        if let range = description.range(of: "like:", options: .caseInsensitive) {
            let trailing = description[range.upperBound...]
            let parsed = trailing
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !parsed.isEmpty { return parsed }
        }

        return []
    }
    
    private var feedbackAlert: some View {
        Group {
            TextField("Feedback", text: $feedbackText)
            
            Button("Submit") {
                if let suggestion = selectedSuggestion {
                    // Track explicit feedback
                    behavioralLearning.collectExplicitFeedback(
                        suggestion: suggestion,
                        rating: feedbackRating,
                        feedback: feedbackText,
                        wasHelpful: feedbackRating >= 3,
                        modelContext: modelContext
                    )
                    
                    suggestion.provideFeedback(
                        rating: feedbackRating,
                        feedback: feedbackText,
                        wasHelpful: feedbackRating >= 3
                    )
                    try? modelContext.save()
                }
                feedbackText = ""
                feedbackRating = 3
            }
            
            Button("Cancel", role: .cancel) {
                feedbackText = ""
                feedbackRating = 3
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct SuggestionRowView: View {
    let suggestion: AISuggestion
    let onAction: (SuggestionAction) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: suggestion.type.icon)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(suggestion.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        confidenceBadge
                    }
                    
                    Text(suggestion.aiDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    // Metadata
                    HStack {
                        priorityBadge
                        
                        Spacer()
                        
                        Text(suggestion.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action menu
                Menu {
                    Button("View Details") {
                        onAction(.showDetails)
                    }
                    
                    if suggestion.status == .pending {
                        Button("Apply Suggestion") {
                            onAction(.apply)
                        }
                        
                        Button("Dismiss") {
                            onAction(.dismiss)
                        }
                    }
                    
                    Button("Provide Feedback") {
                        onAction(.provideFeedback)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private var priorityBadge: some View {
        Text(suggestion.priority.displayName.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .clipShape(Capsule())
    }
    
    private var confidenceBadge: some View {
        Text("\(Int(suggestion.confidence * 100))%")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
}

enum SuggestionAction {
    case apply
    case dismiss
    case showDetails
    case provideFeedback
}

// MARK: - Supporting Types
// Analysis types are defined in AIManager.swift

#Preview {
    AISuggestionsView()
        .modelContainer(for: [AISuggestion.self, AIInsight.self, AIConfiguration.self])
}
