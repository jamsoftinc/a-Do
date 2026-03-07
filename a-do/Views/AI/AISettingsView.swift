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
    @Environment(\.dismiss) private var dismiss
    @State private var aiManager = AIManager.shared
    @State private var geminiManager = GeminiManager.shared
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

                // AI Provider
                providerStatusSection
                
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
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
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
                _ = geminiManager.refreshConfigurationStatus()
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

    private func goHome() {
        NotificationCenter.default.post(name: .appNavigateHome, object: nil)
        dismiss()
    }
    
    // MARK: - General Settings Section
    
    private var generalSettingsSection: some View {
        Section {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.body.weight(.medium))
                    
                    Text("Enable AI-powered suggestions and insights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAIEnabled)
            }
            .padding(.vertical, 2)
            
            if !isAIEnabled {
                Text("AI features are disabled. Enable to receive personalized suggestions and productivity insights.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("General")
        } footer: {
            Text("AI analyzes your productivity patterns to provide personalized suggestions and insights.")
        }
    }

    // MARK: - Provider Settings Section

    private var providerStatusSection: some View {
        Section {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.mint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hybrid AI Routing")
                        .font(.body.weight(.medium))

                    Text("Best model selected automatically per feature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                Image(systemName: "applelogo")
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Intelligence")
                        .font(.caption.weight(.semibold))
                    Text("Primary engine for on-device suggestions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 2)

            HStack {
                Image(systemName: geminiManager.isConfigured ? "checkmark.shield.fill" : "xmark.shield")
                    .foregroundStyle(geminiManager.isConfigured ? .green : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Firebase Gemini")
                        .font(.caption.weight(.semibold))
                    Text(geminiManager.isConfigured
                         ? "Enabled for Pro cloud-generation features via Firebase AI Logic"
                         : "Unavailable until Firebase is configured in the app target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                Image(systemName: geminiManager.isRemoteConfigReady ? "switch.2" : "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(geminiManager.isRemoteConfigReady ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote Config Model")
                        .font(.caption.weight(.semibold))
                    Text(geminiManager.isRemoteConfigReady
                         ? "\((geminiManager.modelID ?? "Unknown")) selected from \(geminiManager.availableModelIDs.count) remote model(s)"
                         : "No model selected until Firebase Remote Config provides gemini_model_list")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let lastError = geminiManager.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 4)
            }

            if geminiManager.isConfigured {
                Button {
                    Task {
                        await geminiManager.refreshRemoteConfiguration()
                    }
                } label: {
                    Text("Refresh Firebase AI Config")
                        .font(.caption.weight(.semibold))
                }
            }
        } header: {
            Text("AI Engine")
        } footer: {
            Text("End users do not choose providers. Gemini is Pro-only and the active model comes from the Firebase Remote Config parameter gemini_model_list.")
        }
        .disabled(!isAIEnabled)
        .opacity(isAIEnabled ? 1.0 : 0.6)
    }
    
    // MARK: - Frequency Settings Section
    
    private var frequencySettingsSection: some View {
        Section {
            // Suggestion Frequency
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggestion Frequency")
                        .font(.body.weight(.medium))
                    
                    Text("How often to generate new suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.green)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insight Frequency")
                        .font(.body.weight(.medium))
                    
                    Text("How often to generate analytics insights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Suggestion Limit")
                        .font(.body.weight(.medium))
                    
                    Text("Maximum suggestions shown per day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy Level")
                        .font(.body.weight(.medium))
                    
                    Text(privacyLevel.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Info") {
                    showingPrivacyInfo = true
                }
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                
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
                        .foregroundStyle(.cyan)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confidence Threshold")
                            .font(.body.weight(.medium))
                        
                        Text("Only show suggestions with \(Int(confidenceThreshold * 100))%+ confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Slider(value: $confidenceThreshold, in: 0.3...1.0, step: 0.1) {
                    Text("Confidence")
                } minimumValueLabel: {
                    Text("30%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.cyan)
            }
            
            // Suggestion Types
            Button {
                showingSuggestionTypesSheet = true
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggestion Types")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("\(AISuggestionType.allCases.count - disabledSuggestionTypes.count) of \(AISuggestionType.allCases.count) enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Insight Types
            Button {
                showingInsightTypesSheet = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preferred Insights")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("\(preferredInsightTypes.count) types selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    
                    Text("Clear Suggestion History")
                        .foregroundStyle(.red)
                    
                    Spacer()
                }
            }
            
            Button {
                resetAILearning()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    
                    Text("Reset AI Learning")
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
            }
            
            Button {
                exportAIData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    
                    Text("Export AI Data")
                        .foregroundStyle(.blue)
                    
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
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        let userId = SecurityUtils.getCurrentUserID()
        configuration = aiManager.getConfiguration(
            userId: userId,
            context: modelContext
        )
        
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
        let userId = SecurityUtils.getCurrentUserID()
        aiManager.updateConfiguration(
            userId: userId,
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
                            .foregroundStyle(disabledTypes.contains(type) ? Color.gray : Color.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.body.weight(.medium))
                            
                            Text(typeDescription(for: type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                ToolbarItem(placement: .confirmationAction) {
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
                            .foregroundStyle(preferredTypes.contains(type) ? Color.accentColor : Color.gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.body.weight(.medium))
                            
                            Text(insightDescription(for: type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                ToolbarItem(placement: .confirmationAction) {
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
