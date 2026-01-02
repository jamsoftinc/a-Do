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
    
    var body: some View {
        ZStack {
            Color(AppTheme.Colors.background).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("Weekly Executive Review")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top)
                
                if let review = reviewManager.currentReview {
                    // Report Card
                    VStack(spacing: 30) {
                        // Grade
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
                        
                        // Analysis
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
                    .padding()
                    
                    Spacer()
                    
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
                    
                } else if reviewManager.isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing productivity metrics...")
                            .font(.caption)
                    }
                } else {
                    Button("Generate Review (Debug)") {
                        Task {
                            await reviewManager.generateReview(context: modelContext)
                        }
                    }
                }
            }
        }
    }
    
    private func gradeColor(for grade: String) -> Color {
        if grade.starts(with: "A") { return .green }
        if grade.starts(with: "B") { return .blue }
        if grade.starts(with: "C") { return .yellow }
        return .red
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
