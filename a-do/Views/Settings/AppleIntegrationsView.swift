import SwiftUI
import SwiftData

struct AppleIntegrationsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: AppSettings?
    @State private var showingResetAlert = false
    @State private var showingDisableAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "apple.logo")
                            .foregroundColor(AppTheme.Colors.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Integrations")
                                .font(AppTheme.Typography.headline)
                                .primaryText()
                            Text("Connect with Apple's ecosystem")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Reminders Integration") {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Reminders")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .primaryText()
                            Text("Sync reminders with Apple Reminders app")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings?.appleRemindersEnabled ?? true },
                            set: { newValue in
                                if newValue {
                                    SettingsManager.shared.setAppleRemindersEnabled(true, context: context)
                                } else {
                                    alertMessage = "Disabling Apple Reminders will stop syncing with the Reminders app. Existing synced reminders will remain but won't update."
                                    showingDisableAlert = true
                                }
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                    
                    if settings?.appleRemindersEnabled == true {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Features:")
                                .font(AppTheme.Typography.caption1)
                                .fontWeight(.medium)
                                .primaryText()
                            
                            Text("• Import reminders from Apple Reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Export new reminders to Apple Reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Sync changes in both directions")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Automatic background sync")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        .padding(.leading, 32)
                    }
                }
                
                Section("Calendar Integration") {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Calendar")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .primaryText()
                            Text("Create calendar events from reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings?.appleCalendarEnabled ?? true },
                            set: { newValue in
                                if newValue {
                                    SettingsManager.shared.setAppleCalendarEnabled(true, context: context)
                                } else {
                                    alertMessage = "Disabling Apple Calendar will stop creating calendar events from reminders."
                                    showingDisableAlert = true
                                }
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                    
                    if settings?.appleCalendarEnabled == true {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Features:")
                                .font(AppTheme.Typography.caption1)
                                .fontWeight(.medium)
                                .primaryText()
                            
                            Text("• Create calendar events from reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Include reminder details in events")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Add attendees to calendar events")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Location-based calendar events")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        .padding(.leading, 32)
                    }
                }
                
                Section("Notes Integration") {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Notes")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .primaryText()
                            Text("Attach Apple Notes to reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings?.appleNotesEnabled ?? true },
                            set: { newValue in
                                if newValue {
                                    SettingsManager.shared.setAppleNotesEnabled(true, context: context)
                                } else {
                                    alertMessage = "Disabling Apple Notes will prevent attaching notes to reminders."
                                    showingDisableAlert = true
                                }
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                    
                    if settings?.appleNotesEnabled == true {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Features:")
                                .font(AppTheme.Typography.caption1)
                                .fontWeight(.medium)
                                .primaryText()
                            
                            Text("• Attach existing Apple Notes to reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Create new notes from reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• View note content in reminder details")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                            Text("• Sync note changes automatically")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        .padding(.leading, 32)
                    }
                }
                
                Section("Sync Settings") {
                    HStack {
                        Text("Auto Sync")
                            .primaryText()
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings?.autoSyncEnabled ?? true },
                            set: { SettingsManager.shared.setAutoSyncEnabled($0, context: context) }
                        ))
                    }
                    
                    if settings?.autoSyncEnabled == true {
                        HStack {
                            Text("Sync Interval")
                                .primaryText()
                            Spacer()
                            Picker("", selection: Binding(
                                get: { settings?.syncInterval ?? 300 },
                                set: { SettingsManager.shared.setSyncInterval($0, context: context) }
                            )) {
                                Text("5 minutes").tag(300)
                                Text("15 minutes").tag(900)
                                Text("30 minutes").tag(1800)
                                Text("1 hour").tag(3600)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                Section("Integration Status") {
                    let status = settings?.integrationStatus ?? [:]
                    
                    ForEach(Array(status.keys.sorted()), id: \.self) { integration in
                        HStack {
                            Text(integration)
                                .primaryText()
                            Spacer()
                            if status[integration] == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.error)
                            }
                        }
                    }
                    
                    if let warnings = settings?.validateSettings(), !warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Warnings:")
                                .font(AppTheme.Typography.caption1)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.Colors.warning)
                            
                            ForEach(warnings, id: \.self) { warning in
                                Text("• \(warning)")
                                    .font(AppTheme.Typography.caption1)
                                    .foregroundColor(AppTheme.Colors.warning)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(AppTheme.Colors.error)
                    }
                }
            }
            .navigationTitle("Apple Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            settings = SettingsManager.shared.getSettings(context: context)
        }
        .alert("Disable Integration", isPresented: $showingDisableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                // Handle the disable action based on the alert message
                if alertMessage.contains("Apple Reminders") {
                    SettingsManager.shared.setAppleRemindersEnabled(false, context: context)
                } else if alertMessage.contains("Apple Calendar") {
                    SettingsManager.shared.setAppleCalendarEnabled(false, context: context)
                } else if alertMessage.contains("Apple Notes") {
                    SettingsManager.shared.setAppleNotesEnabled(false, context: context)
                }
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                SettingsManager.shared.resetToDefaults(context: context)
                settings = SettingsManager.shared.getSettings(context: context)
            }
        } message: {
            Text("This will reset all Apple integration settings to their default values. This action cannot be undone.")
        }
    }
}

#Preview {
    AppleIntegrationsView()
}
