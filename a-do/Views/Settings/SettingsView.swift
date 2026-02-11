import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var showingCollaboration = false
    @State private var showingAISuggestions = false
    @State private var showingAIInsights = false
    @State private var showingSubscription = false
    
    var body: some View {
        NavigationStack {
            List {
                // FEATURES - App functionality
                Section("Features") {
                    NavigationLink(destination: ListsView()) {
                        Label("Lists", systemImage: "folder.fill")
                    }
                    
                    NavigationLink(destination: CompletedRemindersView()) {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                    }
                    
                    NavigationLink(destination: TemplatesView()) {
                        Label("Templates", systemImage: "doc.text.below.ecg")
                    }
                    
                    NavigationLink(destination: SmartSearchView()) {
                        Label("Smart Search", systemImage: "magnifyingglass.circle")
                    }
                    
                    NavigationLink(destination: TimeTrackingView()) {
                        Label("Time Tracking", systemImage: "timer")
                    }
                    
                    Button {
                        showingCollaboration = true
                    } label: {
                        Label("Collaboration", systemImage: "person.2.circle")
                    }
                }
                
                // PREFERENCES - User customization
                Section("Preferences") {
                    Picker("Temperature Unit", selection: Binding(
                        get: { SettingsManager.shared.getTemperatureUnit(context: context) },
                        set: { SettingsManager.shared.setTemperatureUnit($0, context: context) }
                    )) {
                        Text("Fahrenheit").tag("fahrenheit")
                        Text("Celsius").tag("celsius")
                    }
                }
                
                // AI FEATURES - Pro functionality
                Section("AI Features") {
                    Button {
                        if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                            showingAISuggestions = true
                        } else {
                            showingSubscription = true
                        }
                    } label: {
                        HStack {
                            Label("AI Suggestions", systemImage: "sparkles")
                            if !EntitlementManager.shared.isProUser {
                                Spacer()
                                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                            showingAIInsights = true
                        } else {
                            showingSubscription = true
                        }
                    } label: {
                        HStack {
                            Label("AI Insights", systemImage: "chart.line.uptrend.xyaxis")
                            if !EntitlementManager.shared.isProUser {
                                Spacer()
                                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // App Info
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("a-do")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("More")
            .fullScreenCover(isPresented: $showingCollaboration) {
                NavigationStack {
                    CollaborationView()
                }
            }
            .fullScreenCover(isPresented: $showingAISuggestions) {
                NavigationStack {
                    AISuggestionsViewWrapper()
                }
            }
            .fullScreenCover(isPresented: $showingAIInsights) {
                AIInsightsDashboardWrapper()
            }
            .fullScreenCover(isPresented: $showingSubscription) {
                PaywallView()
            }
        }
    }
}
