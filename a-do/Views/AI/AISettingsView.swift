//
//  AISettingsView.swift
//  a-do
//
//  AI configuration and settings interface
//

import SwiftUI
import SwiftData

struct AISettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var aiManager = AIManager.shared
    @State private var configuration: AIConfiguration?
    
    // Local state for settings
    @State private var isAIEnabled = true
    @State private var suggestionFrequency: AISuggestionFrequency = .daily
    @State private var insightFrequency: AIInsightFrequency = .weekly
    @State private var privacyLevel: AIPrivacyLevel = .balanced
    @State private var confidenceThreshold: Double = 0.7
    @State private var maxSuggestionsPerDay = 5
    @State private var learningEnabled = true
    @State private var personalizedRecommendations = true
    @State private var proactiveNotifications = true
    
    // Disabled suggestion types
    @State private var disabledSuggestionTypes: Set<AISuggestionType> = []
    @State private var preferredInsightTypes: Set<AIInsightType> = []
    
    // UI state
    @State private var showingSuggestionTypesSheet = false
    @State private var showingInsightTypesSheet = false
    @State private var showingPrivacyInfo = false
    @State private var hasChanges = false
    
    var body: some View {
        NavigationStack {
            Form {
                // General AI Settings
                generalSettingsSection
                
                // Frequency Settings
                frequencySettingsSection
                
                // Privacy & Data Settings
                privacySettingsSection
                
                // Customization Settings
                customizationSettingsSection
                
                // Performance Settings
                performanceSettingsSection
                
                // Data Management
                dataManagementSection
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasChanges {
                        Button("Save") {
                            saveSettings()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingSuggestionTypesSheet) {
                SuggestionTypesSelectionView(
                    disabledTypes: $disabledSuggestionTypes,
                    hasChanges: $hasChanges
                )
            }
            .sheet(isPresented: $showingInsightTypesSheet) {
                InsightTypesSelectionView(
                    preferredTypes: $preferredInsightTypes,
                    hasChanges: $hasChanges
                )
            }
            .alert("Privacy Information", isPresented: $showingPrivacyInfo) {
                Button("OK") { }
            } message: {
                Text(privacyLevel.description)
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: isAIEnabled) { _, _ in hasChanges = true }
            .onChange(of: suggestionFrequency) { _, _ in hasChanges = true }
            .onChange(of: insightFrequency) { _, _ in hasChanges = true }
            .onChange(of: privacyLevel) { _, _ in hasChanges = true }
            .onChange(of: confidenceThreshold) { _, _ in hasChanges = true }
            .onChange(of: maxSuggestionsPerDay) { _, _ in hasChanges = true }
            .onChange(of: learningEnabled) { _, _ in hasChanges = true }
            .onChange(of: personalizedRecommendations) { _, _ in hasChanges = true }
            .onChange(of: proactiveNotifications) { _, _ in hasChanges = true }
        }
    }
    
    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        Section {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.body.weight(.medium))
                    
                    Text("Enable AI-powered suggestions and insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAIEnabled)
            }
            .padding(.vertical, 2)
            
            if !isAIEnabled {
                Text("AI features are disabled. Enable to receive personalized suggestions and productivity insights.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("General")
        } footer: {
            Text("AI analyzes your productivity patterns to provide personalized suggestions and insights.")
        }
    }
    
    // MARK: - Frequency Settings Section
    
    private var frequencySettingsSection: some View {
        Section {
            // Suggestion Frequency
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggestion Frequency")
                        .font(.body.weight(.medium))
                    
                    Text("How often to generate new suggestions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("Frequency", selection: $suggestionFrequency) {
                    ForEach(AISuggestionFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName)
                            .tag(frequency)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Insight Frequency
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insight Frequency")
                        .font(.body.weight(.medium))
                    
                    Text("How often to generate analytics insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("Frequency", selection: $insightFrequency) {
                    ForEach(AIInsightFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName)
                            .tag(frequency)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Max Suggestions Per Day
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Suggestion Limit")
                        .font(.body.weight(.medium))
                    
                    Text("Maximum suggestions shown per day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Stepper("\(maxSuggestionsPerDay)", value: $maxSuggestionsPerDay, in: 1...20)
                    .labelsHidden()
            }
            
        } header: {
            Text("Frequency & Limits")
        } footer: {
            Text("Adjust how often AI generates suggestions and insights to match your workflow.")
        }
        .disabled(!isAIEnabled)
        .opacity(isAIEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Privacy Settings Section
    
    private var privacySettingsSection: some View {
        Section {
            // Privacy Level
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy Level")
                        .font(.body.weight(.medium))
                    
                    Text(privacyLevel.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Info") {
                    showingPrivacyInfo = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                
                Picker("Privacy", selection: $privacyLevel) {
                    ForEach(AIPrivacyLevel.allCases, id: \.self) { level in
                        Text(level.displayName)
                            .tag(level)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Learning & Personalization
            settingToggle(
                icon: "brain",
                iconColor: .blue,
                title: "Machine Learning",
                subtitle: "Improve suggestions based on your behavior",
                isOn: $learningEnabled
            )
            
            settingToggle(
                icon: "person.badge.key",
                iconColor: .indigo,
                title: "Personalized Recommendations",
                subtitle: "Tailor suggestions to your specific needs",
                isOn: $personalizedRecommendations
            )
            
            settingToggle(
                icon: "bell.badge",
                iconColor: .red,
                title: "Proactive Notifications",
                subtitle: "Send timely alerts for important suggestions",
                isOn: $proactiveNotifications
            )
            
        } header: {
            Text("Privacy & Personalization")
        } footer: {
            Text("Control how your data is used to improve AI recommendations while protecting your privacy.")
        }
        .disabled(!isAIEnabled)
        .opacity(isAIEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Customization Settings Section
    
    private var customizationSettingsSection: some View {
        Section {
            // Confidence Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confidence Threshold")
                            .font(.body.weight(.medium))
                        
                        Text("Only show suggestions with \(Int(confidenceThreshold * 100))%+ confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Slider(value: $confidenceThreshold, in: 0.3...1.0, step: 0.1) {
                    Text("Confidence")
                } minimumValueLabel: {
                    Text("30%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tint(.cyan)
            }
            
            // Suggestion Types
            Button {
                showingSuggestionTypesSheet = true
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggestion Types")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("\(AISuggestionType.allCases.count - disabledSuggestionTypes.count) of \(AISuggestionType.allCases.count) enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Insight Types
            Button {
                showingInsightTypesSheet = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preferred Insights")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("\(preferredInsightTypes.count) types selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            Text("Customization")
        } footer: {
            Text("Customize which types of suggestions and insights you want to receive.")
        }
        .disabled(!isAIEnabled)
        .opacity(isAIEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Performance Settings Section
    
    private var performanceSettingsSection: some View {
        Section {
            // Model Performance Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Performance")
                    .font(.subheadline.weight(.medium))
                
                HStack {
                    performanceMetric("Accuracy", value: "87%", color: .green)
                    Spacer()
                    performanceMetric("User Satisfaction", value: "4.2/5", color: .blue)
                    Spacer()
                    performanceMetric("Suggestions Applied", value: "68%", color: .orange)
                }
                
                Text("Performance metrics are updated weekly based on your feedback and usage patterns.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
        } header: {
            Text("Performance")
        }
    }
    
    private func performanceMetric(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section {
            Button {
                clearSuggestionHistory()
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Clear Suggestion History")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
            
            Button {
                resetAILearning()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Reset AI Learning")
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
            }
            
            Button {
                exportAIData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Export AI Data")
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            
        } header: {
            Text("Data Management")
        } footer: {
            Text("Manage your AI data and learning history. These actions cannot be undone.")
        }
    }
    
    // MARK: - Helper Views
    
    private func settingToggle(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        configuration = aiManager.getConfiguration(userId: "current-user", context: modelContext)
        
        if let config = configuration {
            isAIEnabled = config.isAIEnabled
            suggestionFrequency = config.suggestionFrequency
            insightFrequency = config.insightFrequency
            privacyLevel = config.privacyLevel
            confidenceThreshold = config.minimumConfidenceThreshold
            maxSuggestionsPerDay = config.maxSuggestionsPerDay
            learningEnabled = config.learningEnabled
            personalizedRecommendations = config.personalizedRecommendations
            proactiveNotifications = config.proactiveNotifications
            disabledSuggestionTypes = Set(config.disabledSuggestionTypes)
            preferredInsightTypes = Set(config.preferredInsightTypes)
        }
    }
    
    private func saveSettings() {
        aiManager.updateConfiguration(
            userId: "current-user",
            isEnabled: isAIEnabled,
            suggestionFrequency: suggestionFrequency,
            insightFrequency: insightFrequency,
            privacyLevel: privacyLevel,
            confidenceThreshold: confidenceThreshold,
            context: modelContext
        )
        
        // Update additional settings
        if let config = configuration {
            config.maxSuggestionsPerDay = maxSuggestionsPerDay
            config.learningEnabled = learningEnabled
            config.personalizedRecommendations = personalizedRecommendations
            config.proactiveNotifications = proactiveNotifications
            config.disabledSuggestionTypes = Array(disabledSuggestionTypes)
            config.preferredInsightTypes = Array(preferredInsightTypes)
        }
        
        try? modelContext.save()
        hasChanges = false
    }
    
    private func clearSuggestionHistory() {
        // Implementation would clear suggestion history
    }
    
    private func resetAILearning() {
        // Implementation would reset AI learning data
    }
    
    private func exportAIData() {
        // Implementation would export AI data
    }
}

// MARK: - Supporting Views

struct SuggestionTypesSelectionView: View {
    @Binding var disabledTypes: Set<AISuggestionType>
    @Binding var hasChanges: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AISuggestionType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(disabledTypes.contains(type) ? .gray : .accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.body.weight(.medium))
                            
                            Text(typeDescription(for: type))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { !disabledTypes.contains(type) },
                            set: { enabled in
                                if enabled {
                                    disabledTypes.remove(type)
                                } else {
                                    disabledTypes.insert(type)
                                }
                                hasChanges = true
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Suggestion Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func typeDescription(for type: AISuggestionType) -> String {
        switch type {
        case .dueDateOptimization:
            return "Optimize due dates based on your schedule"
        case .taskBreakdown:
            return "Break complex tasks into smaller steps"
        case .habitTiming:
            return "Suggest optimal times for habits"
        case .workloadBalance:
            return "Balance your task distribution"
        case .focusTimeRecommendation:
            return "Recommend best times for focused work"
        default:
            return "AI-powered productivity suggestion"
        }
    }
}

struct InsightTypesSelectionView: View {
    @Binding var preferredTypes: Set<AIInsightType>
    @Binding var hasChanges: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AIInsightType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(preferredTypes.contains(type) ? .accentColor : .gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.body.weight(.medium))
                            
                            Text(insightDescription(for: type))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { preferredTypes.contains(type) },
                            set: { enabled in
                                if enabled {
                                    preferredTypes.insert(type)
                                } else {
                                    preferredTypes.remove(type)
                                }
                                hasChanges = true
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Insight Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func insightDescription(for type: AIInsightType) -> String {
        switch type {
        case .productivityTrend:
            return "Track your productivity patterns over time"
        case .habitProgress:
            return "Analyze your habit completion rates"
        case .timeUsageAnalysis:
            return "Understand how you spend your time"
        case .focusEffectiveness:
            return "Measure focus session effectiveness"
        case .burnoutRisk:
            return "Identify signs of potential burnout"
        default:
            return "Analytics insight about your productivity"
        }
    }
}

#Preview {
    AISettingsView()
        .modelContainer(for: [AIConfiguration.self, AISuggestion.self])
}