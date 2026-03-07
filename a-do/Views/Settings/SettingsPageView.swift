import SwiftUI
import SwiftData

struct SettingsPageView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @State private var showingAppleIntegrations = false
    @State private var showingImportReminders = false
    @State private var showingAISettings = false
    @State private var showingSubscription = false
    @State private var showingEditName = false
    @State private var newName = ""

    private let themeOptions: [(name: String, value: String)] = [
        ("System", "system"),
        ("Light", "light"),
        ("Dark", "dark")
    ]

    private let accentOptions: [(name: String, value: String)] = [
        ("Ocean", "#336BDB"),
        ("Emerald", "#1FA971"),
        ("Sunset", "#E28A2E"),
        ("Rose", "#D64D74"),
        ("Graphite", "#4A5568")
    ]

    var body: some View {
        List {
            // Profile
            if let profile = profiles.first {
                Section("Profile") {
                    Button {
                        newName = profile.displayName
                        showingEditName = true
                    } label: {
                        HStack {
                            Text("Name")
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Text(profile.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Configuration Settings
            Section("Configuration") {
                Button {
                    if EntitlementManager.shared.hasAccess(to: .advancedNLP) {
                        showingAISettings = true
                    } else {
                        showingSubscription = true
                    }
                } label: {
                    HStack {
                        Label("AI Settings", systemImage: "brain.head.profile")
                        if !EntitlementManager.shared.isProUser {
                            Spacer()
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showingAppleIntegrations = true
                } label: {
                    Label("Sync Settings", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            // Data Management
            Section("Data") {
                Button {
                    showingImportReminders = true
                } label: {
                    Label("Import from Reminders", systemImage: "square.and.arrow.down")
                }
                
                Button {
                    Task {
                        await ReminderCleanupManager.shared.cleanupOldReminders(in: context)
                    }
                } label: {
                    Label("Clean Up Old Reminders", systemImage: "trash")
                }
            }
            
            // Preferences
            Section("Preferences") {
                Picker("Theme", selection: Binding(
                    get: { SettingsManager.shared.getTheme(context: context) },
                    set: { SettingsManager.shared.setTheme($0, context: context) }
                )) {
                    ForEach(themeOptions, id: \.value) { option in
                        Text(option.name).tag(option.value)
                    }
                }

                Picker("Accent Color", selection: Binding(
                    get: { SettingsManager.shared.getAccentColor(context: context) },
                    set: { SettingsManager.shared.setAccentColor($0, context: context) }
                )) {
                    ForEach(accentOptions, id: \.value) { option in
                        Text(option.name).tag(option.value)
                    }
                }

                Picker("Temperature Unit", selection: Binding(
                    get: { SettingsManager.shared.getTemperatureUnit(context: context) },
                    set: { SettingsManager.shared.setTemperatureUnit($0, context: context) }
                )) {
                    Text("Fahrenheit").tag("fahrenheit")
                    Text("Celsius").tag("celsius")
                }
            }
            
            // Subscription
            Section {
                NavigationLink(destination: SubscriptionManagementView()) {
                    Label("Subscription", systemImage: "crown.fill")
                        .foregroundStyle(Color.accentColor)
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
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showingAppleIntegrations) {
            AppleIntegrationsView()
        }
        .fullScreenCover(isPresented: $showingImportReminders) {
            ImportRemindersView()
        }
        .fullScreenCover(isPresented: $showingAISettings) {
            AISettingsViewWrapper()
        }
        .fullScreenCover(isPresented: $showingSubscription) {
            PaywallView()
        }
        .alert("Change Name", isPresented: $showingEditName) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let profile = profiles.first {
                    profile.displayName = newName
                    try? context.save()
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
