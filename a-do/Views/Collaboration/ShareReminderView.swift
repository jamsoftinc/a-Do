//
//  ShareReminderView.swift
//  a-do
//
//  Share reminder interface for workspaces
//

import SwiftUI
import SwiftData

struct ShareReminderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var collaborationManager = CollaborationManager.shared
    
    @State private var selectedReminder: Reminder?
    @State private var participantEmails: [String] = []
    @State private var newEmail: String = ""
    @State private var selectedPermission: SharingPermission = .edit
    @State private var shareMessage: String = ""
    @State private var isSharing = false
    @State private var showingReminderPicker = false
    
    @Query private var reminders: [Reminder]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Reminder") {
                    if let selectedReminder = selectedReminder {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                            
                            VStack(alignment: .leading) {
                                Text(selectedReminder.title)
                                    .font(AppTheme.Typography.body)
                                    .fontWeight(.medium)
                                
                                if let details = selectedReminder.details, !details.isEmpty {
                                    Text(details)
                                        .font(AppTheme.Typography.caption1)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingReminderPicker = true
                            }
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.accent)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showingReminderPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(AppTheme.Colors.accent)
                                
                                Text("Select Reminder to Share")
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Participants") {
                    ForEach(participantEmails, id: \.self) { email in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                            
                            Text(email)
                                .font(AppTheme.Typography.body)
                            
                            Spacer()
                            
                            Button("Remove") {
                                participantEmails.removeAll { $0 == email }
                            }
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        TextField("Enter email address", text: $newEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Add") {
                            addParticipant()
                        }
                        .disabled(newEmail.isEmpty || !isValidEmail(newEmail))
                    }
                }
                
                Section("Permissions") {
                    Picker("Permission Level", selection: $selectedPermission) {
                        ForEach(SharingPermission.allCases, id: \.self) { permission in
                            Text(permission.displayName).tag(permission)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Message (Optional)") {
                    TextField("Add a message for participants", text: $shareMessage, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Share Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareReminder()
                    }
                    .disabled(selectedReminder == nil || participantEmails.isEmpty || isSharing)
                }
            }
            .sheet(isPresented: $showingReminderPicker) {
                ReminderPickerView(selectedReminder: $selectedReminder)
            }
            .overlay {
                if isSharing {
                    ProgressView("Sharing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    private func addParticipant() {
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidEmail(trimmedEmail) && !participantEmails.contains(trimmedEmail) {
            participantEmails.append(trimmedEmail)
            newEmail = ""
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func shareReminder() {
        guard let reminder = selectedReminder else { return }
        
        isSharing = true
        
        Task {
            let sharedReminder = await collaborationManager.shareReminder(
                reminder,
                with: participantEmails,
                permission: selectedPermission,
                context: context
            )
            
            await MainActor.run {
                isSharing = false
                
                if sharedReminder != nil {
                    dismiss()
                } else {
                    // Show error message
                    // Handle error silently in production
                }
            }
        }
    }
}

struct ReminderPickerView: View {
    @Binding var selectedReminder: Reminder?
    @Environment(\.dismiss) private var dismiss
    
    @Query private var reminders: [Reminder]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders.filter { !$0.isCompleted }) { reminder in
                    Button {
                        selectedReminder = reminder
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title)
                                    .font(AppTheme.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                if let details = reminder.details, !details.isEmpty {
                                    Text(details)
                                        .font(AppTheme.Typography.caption1)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                                
                                if let dueDate = reminder.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(AppTheme.Typography.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedReminder?.id == reminder.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ShareReminderView()
        .modelContainer(for: [Reminder.self, SharedReminder.self])
}
