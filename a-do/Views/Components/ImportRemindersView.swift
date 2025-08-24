import SwiftUI
import SwiftData

struct ImportRemindersView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var remindersManager = RemindersManager.shared
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                    
                    Text("Import from Apple Reminders")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text("Import your existing reminders from the Apple Reminders app. Duplicates will be skipped automatically.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Available reminders count
                    if remindersManager.availableRemindersCount > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(.white)
                            Text("\(remindersManager.availableRemindersCount) reminders available to import")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Import stats
                    if remindersManager.importedCount > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(remindersManager.importedCount) reminders imported")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Progress section
                if remindersManager.isImporting {
                    VStack(spacing: 16) {
                        ProgressView(value: remindersManager.importProgress)
                            .progressViewStyle(.linear)
                            .scaleEffect(1.2)
                        
                        Text("Importing reminders...")
                            .font(.headline)
                        
                        if remindersManager.importedCount > 0 {
                            Text("Imported \(remindersManager.importedCount) reminders")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await remindersManager.importReminders(into: context)
                            if remindersManager.lastImportError == nil {
                                showingSuccessAlert = true
                                // Refresh available count after successful import
                                await remindersManager.checkAvailableReminders(into: context)
                            } else {
                                showingErrorAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            if remindersManager.isImporting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text(remindersManager.isImporting ? "Importing..." : "Import Reminders")
                            if !remindersManager.isImporting && remindersManager.availableRemindersCount > 0 {
                                Text("(\(remindersManager.availableRemindersCount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remindersManager.isImporting)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Import Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await remindersManager.checkAvailableReminders(into: context)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Import Successful", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully imported \(remindersManager.importedCount) reminders from Apple Reminders.")
        }
        .alert("Import Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(remindersManager.lastImportError ?? "An unknown error occurred during import.")
        }
    }
}

#Preview {
    ImportRemindersView()
}

