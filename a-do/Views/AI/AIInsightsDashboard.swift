//
//  AIInsightsDashboard.swift
//  a-do
//
//  AI-powered insights and analytics dashboard
//

import SwiftUI
import SwiftData
import Charts

struct AIInsightsDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var aiManager = AIManager.shared
    @State private var aiDataService = AIDataService.shared
    @State private var selectedTimeframe: AIInsightTimeframe = .week
    @State private var selectedInsight: AIInsight?
    
    // Real data state
    @State private var productivityMetrics: ProductivityMetrics?
    @State private var habitMetrics: HabitMetrics?
    @State private var timeUsageMetrics: TimeUsageMetrics?
    @State private var focusMetrics: FocusEffectivenessMetrics?
    
    @Query(sort: [
        SortDescriptor(\AIInsight.createdAt, order: .reverse)
    ]) private var allInsights: [AIInsight]
    
    private var filteredInsights: [AIInsight] {
        allInsights.filter { insight in
            insight.timeframe == selectedTimeframe
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with timeframe selector
                    headerSection
                    
                    // Quick stats overview
                    quickStatsSection
                    
                    // Key insights cards
                    if !filteredInsights.isEmpty {
                        insightsCardsSection
                        
                        // Detailed charts section
                        chartsSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(item: $selectedInsight) { insight in
                InsightDetailView(insight: insight)
            }
            .onAppear {
                refreshInsights()
                loadRealData()
            }
            .onChange(of: selectedTimeframe) { _, _ in
                loadRealData()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Timeframe picker
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(AIInsightTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName)
                        .tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            
            // Processing indicator
            if aiManager.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Analyzing your data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            statCard(
                title: "Insights Generated",
                value: "\(filteredInsights.count)",
                trend: insightsTrend,
                icon: "brain.head.profile",
                color: .blue
            )
            
            statCard(
                title: "Productivity Score",
                value: "\(averageProductivityScore)",
                trend: productivityTrend,
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            statCard(
                title: "Habits Tracked",
                value: "\(activeHabitsCount)",
                trend: habitsTrend,
                icon: "repeat.circle",
                color: .orange
            )
            
            statCard(
                title: "Focus Sessions",
                value: "\(focusSessionsCount)",
                trend: focusTrend,
                icon: "target",
                color: .purple
            )
        }
    }
    
    private func statCard(title: String, value: String, trend: TrendDirection, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Insights Cards Section
    
    private var insightsCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(filteredInsights.prefix(3), id: \.id) { insight in
                    InsightRowView(insight: insight) {
                        selectedInsight = insight
                    }
                }
            }
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Analytics")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            // Productivity trend chart
            if let productivityInsight = filteredInsights.first(where: { $0.type == .productivityTrend }) {
                productivityChartSection(productivityInsight)
            }
            
            // Habit progress chart
            if let habitInsight = filteredInsights.first(where: { $0.type == .habitProgress }) {
                habitProgressChartSection(habitInsight)
            }
            
            // Time usage chart
            if let timeInsight = filteredInsights.first(where: { $0.type == .timeUsageAnalysis }) {
                timeUsageChartSection(timeInsight)
            }
        }
    }
    
    private func productivityChartSection(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Productivity Trend")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    selectedInsight = insight
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.accentColor)
            }
            
            Chart {
                ForEach(Array(realProductivityData.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Score", value)
                    )
                    .foregroundStyle(.blue)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func habitProgressChartSection(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Habit Completion")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    selectedInsight = insight
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.accentColor)
            }
            
            Chart(realHabitData, id: \.name) { habit in
                BarMark(
                    x: .value("Completion", habit.completion),
                    y: .value("Habit", habit.name)
                )
                .foregroundStyle(habit.color)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func timeUsageChartSection(_ insight: AIInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Time Distribution")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    selectedInsight = insight
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.accentColor)
            }
            
            Chart(realTimeData, id: \.category) { data in
                SectorMark(
                    angle: .value("Hours", data.hours),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(data.color)
                .opacity(0.8)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Insights Yet")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("AI needs more data to generate meaningful insights. Complete some tasks and habits to see your analytics.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Generate Insights") {
                refreshInsights()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
    }
    
    // MARK: - Computed Properties
    
    private var insightsTrend: TrendDirection {
        // Simple trend calculation - in real app would compare with previous period
        filteredInsights.count > 2 ? .up : .down
    }
    
    private var averageProductivityScore: Int {
        Int(productivityMetrics?.averageProductivityScore ?? 0)
    }
    
    private var productivityTrend: TrendDirection {
        guard let metrics = productivityMetrics else { return .steady }
        return metrics.averageProductivityScore > 75 ? .up : (metrics.averageProductivityScore < 60 ? .down : .steady)
    }
    
    private var activeHabitsCount: Int {
        habitMetrics?.totalHabits ?? 0
    }
    
    private var habitsTrend: TrendDirection {
        guard let metrics = habitMetrics else { return .steady }
        return metrics.overallCompletionRate > 0.8 ? .up : (metrics.overallCompletionRate < 0.6 ? .down : .steady)
    }
    
    private var focusSessionsCount: Int {
        focusMetrics?.totalSessions ?? 0
    }
    
    private var focusTrend: TrendDirection {
        guard let metrics = focusMetrics else { return .steady }
        return metrics.completionRate > 0.8 ? .up : (metrics.completionRate < 0.6 ? .down : .steady)
    }
    
    // MARK: - Real Data Properties
    
    private var realProductivityData: [Double] {
        aiDataService.getProductivityTrendData(context: modelContext, days: 7)
            .map { $0.score }
    }
    
    private var realHabitData: [HabitChartData] {
        aiDataService.getHabitCompletionData(context: modelContext, days: 7)
            .map { habitData in
                HabitChartData(
                    name: habitData.name,
                    completion: habitData.completionRate,
                    color: Color(hex: habitData.color) ?? .blue
                )
            }
    }
    
    private var realTimeData: [TimeChartData] {
        aiDataService.getTimeDistributionData(context: modelContext, days: 7)
            .map { timeData in
                TimeChartData(
                    category: timeData.category,
                    hours: timeData.hours,
                    color: Color(hex: timeData.color) ?? .blue
                )
            }
    }
    
    // MARK: - Actions
    
    private var refreshButton: some View {
        Button {
            refreshInsights()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(aiManager.isProcessing)
    }
    
    private func refreshInsights() {
        Task {
            await aiManager.generateInsights(userId: "current-user", context: modelContext)
        }
    }
    
    private func loadRealData() {
        productivityMetrics = aiDataService.getProductivityMetrics(context: modelContext, timeframe: selectedTimeframe)
        habitMetrics = aiDataService.getHabitMetrics(context: modelContext, timeframe: selectedTimeframe)
        timeUsageMetrics = aiDataService.getTimeUsageMetrics(context: modelContext, timeframe: selectedTimeframe)
        focusMetrics = aiDataService.getFocusEffectivenessMetrics(context: modelContext, timeframe: selectedTimeframe)
    }
}

// MARK: - Supporting Views

struct InsightRowView: View {
    let insight: AIInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: insight.type.icon)
                    .font(.title3)
                    .foregroundColor(typeColor)
                    .frame(width: 32, height: 32)
                    .background(typeColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(insight.summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(insight.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        confidenceBadge
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var typeColor: Color {
        switch insight.type {
        case .productivityTrend: return .blue
        case .habitProgress: return .green
        case .timeUsageAnalysis: return .orange
        case .focusEffectiveness: return .purple
        case .burnoutRisk: return .red
        default: return .gray
        }
    }
    
    private var confidenceBadge: some View {
        Text("\(Int(insight.confidence * 100))%")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Supporting Types

enum TrendDirection {
    case up, down, steady
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill" 
        case .steady: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .steady: return .orange
        }
    }
}

struct HabitChartData {
    let name: String
    let completion: Double
    let color: Color
}

struct TimeChartData {
    let category: String
    let hours: Double
    let color: Color
}

// MARK: - Extensions

extension AIInsightType {
    var icon: String {
        switch self {
        case .productivityTrend: return "chart.line.uptrend.xyaxis"
        case .completionPattern: return "checkmark.circle.badge.xmark"
        case .timeUsageAnalysis: return "clock.badge.checkmark"
        case .habitProgress: return "repeat.circle"
        case .focusEffectiveness: return "target"
        case .collaborationMetrics: return "person.2.badge.gearshape"
        case .burnoutRisk: return "heart.circle"
        case .goalProgress: return "flag.checkered"
        case .workloadDistribution: return "scale.3d"
        case .procrastinationPattern: return "clock.badge.exclamationmark"
        }
    }
}

#Preview {
    AIInsightsDashboard()
        .modelContainer(for: [AIInsight.self, AISuggestion.self])
}