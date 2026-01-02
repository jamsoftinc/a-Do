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
            .sheet(isPresented: $showingCollaboration) {
                NavigationStack {
                    CollaborationView()
                }
            }
            .sheet(isPresented: $showingAISuggestions) {
                NavigationStack {
                    AISuggestionsViewWrapper()
                }
            }
            .sheet(isPresented: $showingAIInsights) {
                AIInsightsDashboardWrapper()
            }
            .sheet(isPresented: $showingSubscription) {
                PaywallView()
            }
        }
    }
}
