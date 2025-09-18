//
//  RecurringReminderDetailView.swift
//  a-do
//
//  Recurring reminder details and management
//

import SwiftUI
import SwiftData

struct RecurringReminderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    let recurringReminder: RecurringReminder
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Recurring Reminder Header
                    reminderHeader
                    
                    // Recurrence Info
                    recurrenceInfo
                    
                    // Statistics
                    statistics
                    
                    // Generated Reminders
                    generatedReminders
                    
                    // Quick Actions
                    quickActions
                }
                .padding()
            }
            .navigationTitle("Recurring Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Recurring") {
                            showingEditView = true
                        }
                        
                        Button(recurringReminder.isActive ? "Pause" : "Resume") {
                            toggleActive()
                        }
                        
                        Button("Delete Recurring", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditRecurringReminderView(recurringReminder: recurringReminder)
        }
        .alert("Delete Recurring Reminder", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecurringReminder()
            }
        } message: {
            Text("Are you sure you want to delete this recurring reminder? This will also delete all generated reminders.")
        }
    }
    
    private var reminderHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(recurringReminder.isActive ? .green : .gray)
            
            VStack(spacing: 8) {
                Text(recurringReminder.templateTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .primaryText()
                    .multilineTextAlignment(.center)
                
                HStack {
                    Text(recurringReminder.templateCategory)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.primary.opacity(0.2))
                        .foregroundColor(AppTheme.Colors.primary)
                        .cornerRadius(8)
                    
                    Text(recurringReminder.isActive ? "Active" : "Paused")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(recurringReminder.isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(recurringReminder.isActive ? .green : .gray)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var recurrenceInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recurrence Information")
                .font(.headline)
                .primaryText()
            
            VStack(alignment: .leading, spacing: 12) {
                if let rule = recurringReminder.recurrenceRule {
                    InfoRow(label: "Pattern", value: rule.pattern.displayName)
                    
                    if let endDate = rule.endDate {
                        InfoRow(label: "Ends", value: endDate.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        InfoRow(label: "Ends", value: "Never")
                    }
                }
                
                if let nextDue = recurringReminder.nextDue {
                    InfoRow(label: "Next Due", value: nextDue.formatted(date: .abbreviated, time: .omitted))
                }
                
                if let lastGenerated = recurringReminder.lastGenerated {
                    InfoRow(label: "Last Generated", value: lastGenerated.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var statistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .primaryText()
            
            HStack(spacing: 20) {
                StatCard(title: "Generated", value: "\(recurringReminder.generatedReminders?.count ?? 0)", icon: "plus.circle", color: .blue)
                StatCard(title: "Completed", value: "\(completedCount)", icon: "checkmark.circle", color: .green)
                StatCard(title: "Pending", value: "\(pendingCount)", icon: "clock", color: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var generatedReminders: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generated Reminders")
                .font(.headline)
                .primaryText()
            
            let reminders = recurringReminder.generatedReminders ?? []
            
            if reminders.isEmpty {
                Text("No reminders generated yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(reminders.prefix(5), id: \.id) { reminder in
                        GeneratedReminderRow(reminder: reminder)
                    }
                    
                    if reminders.count > 5 {
                        Text("And \(reminders.count - 5) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .primaryText()
            
            VStack(spacing: 12) {
                Button {
                    recurringManager.generateRemindersForRecurring(recurringReminder, context: context)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Generate Next Reminder")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
                }
                
                Button {
                    toggleActive()
                } label: {
                    HStack {
                        Image(systemName: recurringReminder.isActive ? "pause.circle.fill" : "play.circle.fill")
                        Text(recurringReminder.isActive ? "Pause Recurring" : "Resume Recurring")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var completedCount: Int {
        (recurringReminder.generatedReminders ?? []).filter { $0.isCompleted }.count
    }
    
    private var pendingCount: Int {
        (recurringReminder.generatedReminders ?? []).filter { !$0.isCompleted }.count
    }
    
    private func toggleActive() {
        recurringReminder.isActive.toggle()
        try? context.save()
    }
    
    private func deleteRecurringReminder() {
        // Delete all generated reminders first
        for reminder in recurringReminder.generatedReminders ?? [] {
            context.delete(reminder)
        }
        
        // Delete the recurring reminder
        context.delete(recurringReminder)
        
        try? context.save()
        dismiss()
    }
}

struct GeneratedReminderRow: View {
    let reminder: Reminder
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                    .primaryText()
                    .lineLimit(1)
                
                if let dueDate = reminder.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : .gray)
                
                Text(reminder.isCompleted ? "Done" : "Pending")
                    .font(.caption)
                    .foregroundColor(reminder.isCompleted ? .green : .secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let recurring = RecurringReminder(title: "Daily Standup", details: "Team meeting", priority: .medium, recurrenceRule: RecurrenceRule())
    recurring.templateCategory = "Work"
    recurring.isActive = true
    
    return RecurringReminderDetailView(recurringReminder: recurring)
        .modelContainer(for: [RecurringReminder.self, Reminder.self])
}
