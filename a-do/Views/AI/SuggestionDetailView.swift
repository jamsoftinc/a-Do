//
//  SuggestionDetailView.swift
//  a-do
//
//  Detailed view for AI suggestions with context and explanations
//

import SwiftUI
import SwiftData

struct SuggestionDetailView: View {
    let suggestion: AISuggestion
    let onAction: (SuggestionAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingFullAnalysis = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    headerCard
                    
                    // Confidence and metrics
                    confidenceSection
                    
                    // Target context
                    if hasTargetContext {
                        targetContextSection
                    }
                    
                    // Suggested breakdown or actions
                    if let contextData = suggestion.contextData,
                       let breakdown = try? JSONDecoder().decode([String: [String]].self, from: contextData) {
                        suggestedActionsSection(breakdown)
                    }
                    
                    // AI Rationale (if available)
                    aiRationaleSection
                    
                    // User feedback section
                    if suggestion.status == .applied || suggestion.status == .dismissed {
                        userFeedbackSection
                    }
                }
                .padding()
            }
            .navigationTitle("AI Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    actionMenu
                }
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .font(.title2)
                    .foregroundColor(priorityColor)
                    .frame(width: 32, height: 32)
                    .background(priorityColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.type.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge
                    priorityBadge
                }
            }
            
            Text(suggestion.aiDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Confidence Section
    
    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confidence & Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Confidence Level")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                }
                
                // Confidence bar
                ProgressView(value: suggestion.confidence)
                    .tint(confidenceColor)
                
                HStack {
                    Text("Created")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(suggestion.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                }
                
                if let expiresAt = suggestion.expiresAt {
                    HStack {
                        Text("Expires")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(expiresAt.formatted(.relative(presentation: .named)))
                            .font(.body.weight(.medium))
                            .foregroundColor(suggestion.isExpired ? .red : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Target Context Section
    
    private var hasTargetContext: Bool {
        suggestion.targetReminder != nil || suggestion.targetHabit != nil
    }
    
    private var targetContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Item")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let reminder = suggestion.targetReminder {
                reminderContextCard(reminder)
            } else if let habit = suggestion.targetHabit {
                habitContextCard(habit)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func reminderContextCard(_ reminder: Reminder) -> some View {
        HStack {
            Image(systemName: "checklist")
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                if let details = reminder.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let dueDate = reminder.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func habitContextCard(_ habit: Habit) -> some View {
        HStack {
            Image(systemName: "repeat")
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Current streak: \(habit.currentStreak) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Suggested Actions Section
    
    private func suggestedActionsSection(_ breakdown: [String: [String]]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let suggestedTasks = breakdown["suggestedTasks"] {
                ForEach(Array(suggestedTasks.enumerated()), id: \.offset) { index, task in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                        
                        Text(task)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - AI Rationale Section
    
    private var aiRationaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Analysis")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(showingFullAnalysis ? "Less" : "More") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFullAnalysis.toggle()
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.accentColor)
            }
            
            Text(aiRationaleText)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(showingFullAnalysis ? nil : 3)
                .animation(.easeInOut(duration: 0.3), value: showingFullAnalysis)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - User Feedback Section
    
    private var userFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Feedback")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let rating = suggestion.userRating {
                HStack {
                    Text("Rating:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= rating ? .yellow : .gray)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            if !suggestion.userFeedback.isEmpty {
                Text(suggestion.userFeedback)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if let wasHelpful = suggestion.wasHelpful {
                HStack {
                    Text("Helpful:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(wasHelpful ? "Yes" : "No")
                        .font(.body.weight(.medium))
                        .foregroundColor(wasHelpful ? .green : .red)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Computed Properties
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private var confidenceColor: Color {
        switch suggestion.confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var statusBadge: some View {
        Text(suggestion.status.displayName.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
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
    
    private var statusColor: Color {
        switch suggestion.status {
        case .pending: return .blue
        case .applied: return .green
        case .dismissed: return .gray
        case .expired: return .red
        }
    }
    
    private var aiRationaleText: String {
        switch suggestion.type {
        case .scheduleConflictResolution:
            return "I analyzed your scheduled tasks and found overlapping time slots that might cause stress or rushing. Research shows that spacing tasks with buffer time improves completion quality and reduces anxiety."
        case .taskBreakdown:
            return "Complex tasks with multiple components benefit from being broken into smaller, actionable steps. This approach leverages the psychology of progress momentum - completing smaller tasks builds motivation for the next step."
        case .optimalTaskTiming:
            return "Based on your historical completion patterns and productivity data, certain times of day show higher success rates for similar tasks. This suggestion aims to align your energy levels with task demands."
        case .habitTiming:
            return "Your habit completion data reveals optimal timing patterns. Consistency in timing helps build stronger neural pathways, making the habit more automatic over time."
        case .workloadBalance:
            return "I've detected an imbalance in your task distribution that could lead to burnout or missed deadlines. Redistributing workload helps maintain sustainable productivity levels."
        default:
            return "This suggestion is based on analysis of your productivity patterns, task completion history, and established behavioral psychology principles. The AI considers multiple factors to provide personalized recommendations."
        }
    }
    
    private var actionMenu: some View {
        Menu {
            if suggestion.status == .pending {
                Button("Apply Suggestion") {
                    onAction(.apply)
                    dismiss()
                }
                
                Button("Dismiss") {
                    onAction(.dismiss)
                    dismiss()
                }
                
                Divider()
            }
            
            Button("Provide Feedback") {
                onAction(.provideFeedback)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

#Preview {
    SuggestionDetailView(
        suggestion: AISuggestion(
            type: .taskBreakdown,
            title: "Break Down Complex Task",
            description: "This task seems complex and could benefit from being broken into smaller steps.",
            confidence: 0.85
        )
    ) { _ in }
}