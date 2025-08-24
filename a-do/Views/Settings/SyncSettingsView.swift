import SwiftUI
import SwiftData

struct SyncSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSyncing = false
    @State private var lastSyncDate: Date?
    @State private var syncError: String?
    @State private var showingSyncAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppTheme.Colors.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Reminders Sync")
                                .font(AppTheme.Typography.headline)
                                .primaryText()
                            Text("Keep your reminders synchronized with Apple Reminders")
                                .font(AppTheme.Typography.caption1)
                                .secondaryText()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Sync Status") {
                    HStack {
                        Text("Last Sync")
                            .primaryText()
                        Spacer()
                        if let lastSync = AppleRemindersSyncManager.shared.lastSync {
                            Text(lastSync, style: .relative)
                                .secondaryText()
                        } else {
                            Text("Never")
                                .secondaryText()
                        }
                    }
                    
                    if AppleRemindersSyncManager.shared.isCurrentlySyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .secondaryText()
                        }
                    }
                    
                    if let error = AppleRemindersSyncManager.shared.currentSyncError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.Colors.error)
                            Text(error)
                                .font(AppTheme.Typography.caption1)
                                .foregroundColor(AppTheme.Colors.error)
                        }
                    }
                }
                
                Section("Sync Actions") {
                    Button {
                        Task {
                            await performManualSync()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                    }
                    .disabled(AppleRemindersSyncManager.shared.isCurrentlySyncing)
                    
                    Button {
                        showingSyncAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import from Apple Reminders")
                        }
                    }
                }
                
                Section("Sync Settings") {
                    Toggle("Auto Sync", isOn: .constant(true))
                        .onChange(of: true) { _, _ in
                            // This would be connected to the actual auto sync setting
                        }
                    
                    HStack {
                        Text("Sync Interval")
                            .primaryText()
                        Spacer()
                        Picker("", selection: .constant(300)) {
                            Text("5 minutes").tag(300)
                            Text("15 minutes").tag(900)
                            Text("30 minutes").tag(1800)
                            Text("1 hour").tag(3600)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("About Sync") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .primaryText()
                        
                        Text("• New reminders created in a-do are automatically synced to Apple Reminders")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                        
                        Text("• New reminders from Apple Reminders are imported into a-do")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                        
                        Text("• Changes to existing reminders are synced in both directions")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                        
                        Text("• Duplicate reminders are automatically detected and skipped")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Sync Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Import Reminders", isPresented: $showingSyncAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                Task {
                    await performImport()
                }
            }
        } message: {
            Text("This will import all reminders from Apple Reminders that aren't already in a-do. Duplicates will be skipped.")
        }
    }
    
    private func performManualSync() async {
        isSyncing = true
        syncError = nil
        
        do {
            await AppleRemindersSyncManager.shared.performFullSync(context: context)
            lastSyncDate = AppleRemindersSyncManager.shared.lastSync
        } catch {
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    private func performImport() async {
        isSyncing = true
        syncError = nil
        
        do {
            // This would trigger the import process
            await AppleRemindersSyncManager.shared.performFullSync(context: context)
            lastSyncDate = AppleRemindersSyncManager.shared.lastSync
        } catch {
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
}

#Preview {
    SyncSettingsView()
}
