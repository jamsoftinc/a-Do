//
//  WeeklyReviewView.swift
//  a-do
//
//  Created for iOS 26+ AI Executive Weekly Review
//

import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var reviewManager = WeeklyReviewManager.shared
    @State private var showingPaywall = false
    @State private var showingPlanAppliedAlert = false
    @State private var planApplyMessage = ""
    
    var body: some View {
        ZStack {
            Color(AppTheme.Colors.background).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("Weekly Executive Review")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                if !reviewManager.isProEnabled {
                    proLockedView
                } else if reviewManager.isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing productivity metrics...")
                            .font(.caption)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            if let review = reviewManager.currentReview {
                                reviewCard(review)
                            } else {
                                Button("Generate Weekly Review") {
                                    Task {
                                        await reviewManager.generateReview(context: modelContext)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            nextWeekPlanSection
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        reviewManager.dismissReview()
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom)
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Plan Applied", isPresented: $showingPlanAppliedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(planApplyMessage)
        }
    }
    
    private func gradeColor(for grade: String) -> Color {
        if grade.starts(with: "A") { return .green }
        if grade.starts(with: "B") { return .blue }
        if grade.starts(with: "C") { return .yellow }
        return .red
    }

    private var proLockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42))
                .foregroundStyle(.yellow)

            Text("Weekly Executive Review is a Pro feature.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Upgrade to Pro") {
                showingPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(AppTheme.Colors.surface))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func reviewCard(_ review: WeeklyReviewContent) -> some View {
        VStack(spacing: 30) {
            VStack {
                Text(review.grade)
                    .font(.system(size: 80, weight: .black, design: .serif))
                    .foregroundStyle(gradeColor(for: review.grade))

                Text("Productivity Grade")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                Circle()
                    .fill(gradeColor(for: review.grade).opacity(0.1))
                    .frame(width: 160, height: 160)
            )

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                ReviewSection(title: "Analysis", icon: "chart.bar.doc.horizontal", text: review.summary)
                ReviewSection(title: "Highlight", icon: "star.fill", text: review.highlight, color: .yellow)
                ReviewSection(title: "To Improve", icon: "exclamationmark.triangle.fill", text: review.areaForImprovement, color: .orange)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(AppTheme.Colors.surface))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 10)
        .padding(.horizontal)
    }

    private var nextWeekPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Next Week Plan", systemImage: "calendar.badge.plus")
                    .font(.headline)
                Spacer()
                if reviewManager.isGeneratingNextWeekPlan {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let plan = reviewManager.currentNextWeekPlan {
                Text(plan.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                planPreview(title: "Reminders", items: Array(plan.reminders.prefix(3).map(\.title)))
                planPreview(title: "Focus Blocks", items: Array(plan.focusBlocks.prefix(3).map(\.title)))
                planPreview(title: "Habit Targets", items: Array(plan.habits.prefix(3).map(\.title)))

                HStack {
                    Button("Regenerate") {
                        Task {
                            await reviewManager.generateNextWeekPlan(context: modelContext)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Apply Plan") {
                        Task {
                            let result = await reviewManager.applyCurrentNextWeekPlan(context: modelContext)
                            await MainActor.run {
                                planApplyMessage = result.summary
                                showingPlanAppliedAlert = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Generate a concrete next-week plan from your review: reminders, focus blocks, and habit targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Generate Next Week Plan") {
                    Task {
                        await reviewManager.generateNextWeekPlan(context: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(AppTheme.Colors.surface))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func planPreview(title: String, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

struct ReviewSection: View {
    let title: String
    let icon: String
    let text: String
    var color: Color = .blue
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
    }
}
