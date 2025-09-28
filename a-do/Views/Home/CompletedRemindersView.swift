import SwiftUI
import SwiftData
import os
import AVFoundation

struct CompletedRemindersView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var reminderToDelete: Reminder?
    @State private var showingCleanupConfirmation = false
    @State private var completedReminders: [Reminder] = []
    @State private var isLoading = false
    
    private var filteredCompletedReminders: [Reminder] {
        let filtered = completedReminders
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { reminder in
                reminder.title.localizedCaseInsensitiveContains(searchText) ||
                (reminder.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Gradients.background.ignoresSafeArea()
                
                if completedReminders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        VStack(spacing: 8) {
                            Text("No Completed Reminders")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Text("Completed reminders will appear here for 30 days before being automatically cleaned up.")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredCompletedReminders) { reminder in
                                CompletedReminderCard(reminder: reminder) {
                                    // Uncomplete action
                                    uncompleteReminder(reminder)
                                } onDelete: {
                                    // Delete action
                                    reminderToDelete = reminder
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Completed")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search completed reminders...")
            .task {
                await loadCompletedReminders()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingCleanupConfirmation = true
                        } label: {
                            Label("Clean Up Old Reminders", systemImage: "trash.circle")
                        }
                        
                        Button {
                            // Export completed reminders
                            exportCompletedReminders()
                        } label: {
                            Label("Export List", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Reminder?",
            isPresented: $showingDeleteConfirmation,
            presenting: reminderToDelete
        ) { reminder in
            Button("Delete", role: .destructive) {
                deleteReminder(reminder)
            }
        } message: { reminder in
            Text("Are you sure you want to delete '\(reminder.title)'? This action cannot be undone.")
        }
        .confirmationDialog(
            "Clean Up Old Reminders?",
            isPresented: $showingCleanupConfirmation
        ) {
            Button("Clean Up", role: .destructive) {
                Task {
                    await ReminderCleanupManager.shared.cleanupOldReminders(in: context)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all completed reminders older than 30 days.")
        }
    }
    
    // MARK: - Actions
    
    private func uncompleteReminder(_ reminder: Reminder) {
        reminder.isCompleted = false
        reminder.completedAt = nil
        
        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Completed").info("Reminder marked incomplete: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Completed").error("Failed to mark reminder incomplete: \(String(describing: error))")
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        // Cancel any notifications for this reminder
        NotificationManager.shared.cancelNotifications(for: reminder.id)
        
        // Stop location monitoring if this reminder has location triggers
        // Temporarily disabled - locationTrigger relationship commented out
        // if let locationTrigger = reminder.locationTrigger {
        //     LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
        // }
        
        // Delete voice recording file if it exists
        // Temporarily disabled - voiceReminder relationship commented out
        // if let voiceReminder = reminder.voiceReminder,
        //    let audioFileURL = voiceReminder.audioFileURL {
        //     try? FileManager.default.removeItem(at: audioFileURL)
        // }
        
        // Delete from context
        context.delete(reminder)
        
        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Completed").info("Reminder deleted: '\(reminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Completed").error("Failed to delete reminder: \(String(describing: error))")
        }
    }
    
    private func loadCompletedReminders() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Load completed reminders on background thread
        let reminders = await Task.detached {
            let backgroundContext = ModelContext(self.context.container)
            
            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.isCompleted && reminder.completedAt != nil
                },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200 // Limit to prevent memory issues
            
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
        
        await MainActor.run {
            self.completedReminders = reminders
        }
    }
    
    private func exportCompletedReminders() {
        // Create a text representation of completed reminders
        let exportText = filteredCompletedReminders.map { reminder in
            let completionDate = reminder.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
            let dueDate = reminder.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "No due date"
            return """
            ✅ \(reminder.title)
               Completed: \(completionDate)
               Due: \(dueDate)
               \(reminder.details ?? "")
            """
        }.joined(separator: "\n\n")
        
        // Share the text
        let activityVC = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Completed Reminder Card

private struct CompletedReminderCard: View {
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    let reminder: Reminder
    let onUncomplete: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    // Priority indicator (dimmed)
                    Circle()
                        .fill(AppTheme.priorityColor(reminder.priority).opacity(0.5))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    // Title and completion info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                            .font(.headline)
                            .strikethrough(true)
                            .foregroundStyle(.secondary)
                        
                        if let completedAt = reminder.completedAt {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(.green)
                                Text("Completed \(completedAt, style: .relative)")
                            }
                                                    .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            onUncomplete()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundStyle(.white)
                                .imageScale(.large)
                        }
                        
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash.circle")
                                .foregroundStyle(.red)
                                .imageScale(.large)
                        }
                    }
                }
                
                // Details
                if let details = reminder.details, !details.isEmpty {
                    Text(details)
                        .font(.body)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .strikethrough(true)
                }
                
                // Metadata
                HStack(spacing: 12) {
                    if let due = reminder.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .imageScale(.small)
                            Text("Was due: \(due, style: .date)")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary.opacity(0.8))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .imageScale(.small)
                        Text("Created: \(reminder.createdAt, style: .date)")
                    }
                                            .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary.opacity(0.8))
                }
                
                // Tags and attachments
                HStack(spacing: 8) {
                    // Temporarily disabled - tags relationship commented out
                    // if !(reminder.tags?.isEmpty ?? true) {
                    //     HStack(spacing: 4) {
                    //         Image(systemName: "tag")
                    //             .imageScale(.small)
                    //         Text("\(reminder.tags?.count ?? 0) tags")
                    //     }
                    //     .font(.caption)
                    //     .foregroundStyle(.white.opacity(0.7))
                    // }
                    
                    if reminder.autoTextTaggedContacts || reminder.autoTextMe {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                            Text("Auto")
                        }
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.7))
                    }
                    
                    // Temporarily disabled - appleNote relationship commented out
                    // if reminder.appleNote != nil {
                    //     HStack(spacing: 4) {
                    //         Image(systemName: "note.text")
                    //         Text("Note")
                    //     }
                    //     .font(.caption)
                    //     .foregroundStyle(.white.opacity(0.7))
                    // }
                    
                    if reminder.calendarInviteCreated {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                            Text("Event")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.7))
                    }
                    
                    // Temporarily disabled - voiceReminder relationship commented out
                    // if reminder.voiceReminder != nil {
                    //     HStack(spacing: 4) {
                    //         Image(systemName: "waveform")
                    //         Text("Voice")
                    //     }
                    //     .font(.caption)
                    //     .foregroundStyle(.purple.opacity(0.7))
                    // }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ReminderFormView(existingReminder: reminder)
            }
        }
        .contextMenu {
            Button {
                onUncomplete()
            } label: { Label("Mark Incomplete", systemImage: "arrow.uturn.backward") }
            
            Button {
                showingEditSheet = true
            } label: { Label("Edit", systemImage: "pencil") }
            
            // Temporarily disabled - appleNote relationship commented out
            // if reminder.appleNote != nil {
            //     Button {
            //         NotesManager.shared.openNoteInNotesApp(noteIdentifier: reminder.appleNote!.noteIdentifier)
            //     } label: { Label("Open Apple Note", systemImage: "note.text") }
            // }
            
            // Temporarily disabled - voiceReminder relationship commented out
            // if reminder.voiceReminder != nil {
            //     Button {
            //         Task {
            //             if let voiceReminder = reminder.voiceReminder, let audioFileURL = voiceReminder.audioFileURL {
            //                 do {
            //                     let player = try AVAudioPlayer(contentsOf: audioFileURL)
            //                     player.play()
            //                 } catch {
            //                     Logger(subsystem: "a-do", category: "Voice").error("Failed to play voice recording: \(String(describing: error))")
            //                 }
            //             }
            //         }
            //     } label: { Label("Play Voice Recording", systemImage: "play.circle") }
            // }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

#Preview {
    CompletedRemindersView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
