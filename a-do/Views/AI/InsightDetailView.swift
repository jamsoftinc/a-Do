//
//  InsightDetailView.swift
//  a-do
//
//  Detailed view for AI insights with metrics and actionable recommendations
//

import SwiftUI
import SwiftData
import Charts

struct InsightDetailView: View {
    let insight: AIInsight
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingBookmarkTooltip = false
    
    private let aiDataService = AIDataService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header card
                    headerCard
                    
                    // Metrics visualization
                    metricsSection
                    
                    // Detailed analysis
                    analysisSection
                    
                    // Actionable recommendations
                    recommendationsSection
                    
                    // User interaction section
                    userInteractionSection
                }
                .padding()
            }
            .navigationTitle("Insight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    bookmarkButton
                }
            }
            .onAppear {
                markAsRead()
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: insight.type.icon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                    .frame(width: 40, height: 40)
                    .background(typeColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.type.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text(insight.title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    confidenceBadge
                    timeframeBadge
                }
            }
            
            Text(insight.summary)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Metadata
            HStack {
                Label {
                    Text(insight.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if insight.viewCount > 0 {
                    Label {
                        Text("Viewed \(insight.viewCount) time\(insight.viewCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics & Visualization")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Chart based on visualization type
            chartView
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch insight.visualizationType {
        case .lineChart:
            lineChartView
        case .barChart:
            barChartView
        case .pieChart:
            pieChartView
        case .gauge:
            gaugeView
        default:
            emptyChart(message: "Visualization is not available for this insight")
        }
    }
    
    private var lineChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            if trendDataPoints.isEmpty {
                emptyChart(message: "No trend data yet")
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(trendDataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(typeColor)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(typeColor.opacity(0.15))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: trendChartYDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
        }
    }
    
    private var barChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comparison Analysis")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            if habitCompletionBars.isEmpty {
                emptyChart(message: "No habit progress data yet")
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(habitCompletionBars, id: \.category) { data in
                        BarMark(
                            x: .value("Category", data.category),
                            y: .value("Completion", data.value)
                        )
                        .foregroundStyle(data.color)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...100)
            }
        }
    }
    
    private var pieChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribution Analysis")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            if timeDistributionSlices.isEmpty {
                emptyChart(message: "No time distribution data yet")
                    .frame(height: 180)
            } else {
                HStack {
                    Chart {
                        ForEach(timeDistributionSlices, id: \.category) { data in
                            SectorMark(
                                angle: .value("Value", data.value),
                                innerRadius: .ratio(0.4),
                                angularInset: 1
                            )
                            .foregroundStyle(data.color)
                            .opacity(0.85)
                        }
                    }
                    .frame(width: 150, height: 150)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(timeDistributionSlices, id: \.category) { data in
                            HStack {
                                Circle()
                                    .fill(data.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(data.category)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(Int(data.value))%")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private var gaugeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Indicator")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Gauge(value: gaugeProgressValue, in: 0...1) {
                Text("Progress")
                    .font(.caption)
            } currentValueLabel: {
                Text("\(Int(gaugeProgressValue * 100))%")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(typeColor)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(typeColor)
            .frame(height: 150)
        }
    }
    
    private func emptyChart(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Analysis Section
    
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Analysis")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !insight.detailedAnalysis.isEmpty {
                Text(insight.detailedAnalysis)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(defaultAnalysisText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recommendations Section
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actionable Recommendations")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    recommendationCard(recommendation, index: index + 1)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func recommendationCard(_ text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(typeColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action buttons could be added here
                HStack {
                    Button("Apply") {
                        // Handle recommendation application
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(typeColor.opacity(0.1))
                    .foregroundColor(typeColor)
                    .clipShape(Capsule())
                    
                    Button("Learn More") {
                        // Handle learn more action
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - User Interaction Section
    
    private var userInteractionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Notes & Rating")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Rating section
            ratingSection
            
            // Notes section
            notesSection
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How helpful was this insight?")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            HStack {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rateInsight(star)
                    } label: {
                        Image(systemName: star <= (insight.userRating ?? 0) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(star <= (insight.userRating ?? 0) ? .yellow : .gray)
                    }
                }
                
                Spacer()
                
                if let rating = insight.userRating {
                    Text("\(rating)/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal Notes")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if insight.userNotes.isEmpty {
                Button("Add notes about this insight...") {
                    // Handle add notes
                }
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(insight.userNotes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Edit Notes") {
                    // Handle edit notes
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var typeColor: Color {
        switch insight.type {
        case .productivityTrend: return .blue
        case .habitProgress: return .green
        case .timeUsageAnalysis: return .orange
        case .focusEffectiveness: return .purple
        case .burnoutRisk: return .red
        case .goalProgress: return .indigo
        default: return .gray
        }
    }
    
    private var confidenceBadge: some View {
        Text("\(Int(insight.confidence * 100))% confidence")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor.opacity(0.2))
            .foregroundColor(confidenceColor)
            .clipShape(Capsule())
    }
    
    private var timeframeBadge: some View {
        Text(insight.timeframe.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
    
    private var confidenceColor: Color {
        switch insight.confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var recommendations: [String] {
        if let data = insight.actionableRecommendations,
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return defaultRecommendations
    }
    
    private var defaultRecommendations: [String] {
        switch insight.type {
        case .productivityTrend:
            return [
                "Schedule important tasks during your most productive hours",
                "Take regular breaks to maintain focus",
                "Consider batch processing similar tasks"
            ]
        case .habitProgress:
            return [
                "Focus on consistency over perfection",
                "Set up environmental cues for better habit execution",
                "Celebrate small wins to build momentum"
            ]
        case .timeUsageAnalysis:
            return [
                "Block time for deep work sessions",
                "Minimize context switching between tasks",
                "Use time tracking to identify productivity patterns"
            ]
        default:
            return [
                "Review this insight regularly",
                "Apply recommendations gradually",
                "Track your progress over time"
            ]
        }
    }
    
    private var defaultAnalysisText: String {
        switch insight.type {
        case .productivityTrend:
            return "Your productivity patterns show consistent performance with some variation throughout the week. Peak productivity occurs during mid-morning hours, with a secondary peak in early afternoon."
        case .habitProgress:
            return "Your habit tracking shows strong commitment to routine building. Current completion rates indicate good momentum, with room for optimization in timing and consistency."
        case .timeUsageAnalysis:
            return "Time allocation analysis reveals patterns in how you distribute effort across different activities. There are opportunities to optimize your schedule for better work-life balance."
        default:
            return "This insight provides valuable information about your productivity patterns and suggests areas for improvement."
        }
    }
    
    // MARK: - Data Mapping
    
    private var trendDataPoints: [ProductivityDataPoint] {
        aiDataService.getProductivityTrendData(
            context: modelContext,
            days: max(3, daysForTimeframe)
        )
    }
    
    private var habitCompletionBars: [BarData] {
        aiDataService.getHabitCompletionData(context: modelContext, days: daysForTimeframe)
            .map { habitData in
                BarData(
                    category: habitData.name,
                    value: min(100, max(0, habitData.completionRate * 100)),
                    color: Color(hex: habitData.color) ?? typeColor
                )
            }
            .prefix(6)
            .map { $0 }
    }
    
    private var timeDistributionSlices: [PieData] {
        aiDataService.getTimeDistributionData(context: modelContext, days: daysForTimeframe)
            .map { distribution in
                PieData(
                    category: distribution.category,
                    value: distribution.percentage,
                    color: Color(hex: distribution.color) ?? typeColor
                )
            }
            .filter { $0.value > 0 }
            .prefix(6)
            .map { $0 }
    }
    
    private var trendChartYDomain: ClosedRange<Double> {
        let values = trendDataPoints.map(\.score)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }
        
        let lower = max(0, minValue - 10)
        let upper = min(100, maxValue + 10)
        if lower == upper {
            return lower...(upper + 1)
        }
        return lower...upper
    }
    
    private var daysForTimeframe: Int {
        switch insight.timeframe {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
    
    private var decodedMetrics: [String: Double] {
        guard let data = insight.metricsData else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
    
    private var gaugeProgressValue: Double {
        if let explicitProgress = decodedMetrics["progress"] {
            return min(1, max(0, explicitProgress))
        }
        
        if let completionRate = decodedMetrics["completionRate"] {
            return min(1, max(0, completionRate))
        }
        
        if insight.type == .burnoutRisk {
            return min(1, max(0, 1.0 - insight.confidence))
        }
        
        return min(1, max(0, insight.confidence))
    }
    
    // MARK: - Actions
    
    private var bookmarkButton: some View {
        Button {
            toggleBookmark()
        } label: {
            Image(systemName: insight.isBookmarked ? "bookmark.fill" : "bookmark")
                .foregroundColor(insight.isBookmarked ? .accentColor : .secondary)
        }
    }
    
    private func markAsRead() {
        insight.markAsRead()
        // Save context if needed
    }
    
    private func toggleBookmark() {
        insight.toggleBookmark()
        // Save context if needed
    }
    
    private func rateInsight(_ rating: Int) {
        insight.userRating = rating
        // Save context if needed
    }
}

// MARK: - Supporting Types

struct BarData {
    let category: String
    let value: Double
    let color: Color
}

struct PieData {
    let category: String
    let value: Double
    let color: Color
}

#Preview {
    InsightDetailView(
        insight: AIInsight(
            type: .productivityTrend,
            title: "Your Productivity This Week",
            summary: "Your productivity has increased by 15% compared to last week, with peak performance on Thursday morning.",
            confidence: 0.85
        )
    )
}
