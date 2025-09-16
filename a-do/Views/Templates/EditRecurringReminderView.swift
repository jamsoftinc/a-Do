//
//  EditRecurringReminderView.swift
//  a-do
//
//  Edit existing recurring reminder
//

import SwiftUI
import SwiftData

struct EditRecurringReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let recurringReminder: RecurringReminder
    
    @State private var templateTitle: String
    @State private var templateDetails: String
    @State private var selectedPattern: RecurrencePattern
    @State private var endDate: Date?
    @State private var hasEndDate: Bool
    
    init(recurringReminder: RecurringReminder) {
        self.recurringReminder = recurringReminder
        self._templateTitle = State(initialValue: recurringReminder.templateTitle)
        self._templateDetails = State(initialValue: recurringReminder.templateDetails ?? "")
        self._selectedPattern = State(initialValue: recurringReminder.recurrenceRule?.pattern ?? .daily)
        self._endDate = State(initialValue: recurringReminder.recurrenceRule?.endDate)
        self._hasEndDate = State(initialValue: recurringReminder.recurrenceRule?.endDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder Details") {
                    TextField("Title", text: $templateTitle)
                    TextField("Details (Optional)", text: $templateDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Recurrence Pattern") {
                    Picker("Pattern", selection: $selectedPattern) {
                        ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Schedule") {
                    Toggle("Has End Date", isOn: $hasEndDate)
                    
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(templateTitle)
                            .font(.headline)
                        
                        if !templateDetails.isEmpty {
                            Text(templateDetails)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Repeats: \(selectedPattern.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let endDate = endDate {
                            Text("Ends: \(endDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecurringReminder()
                    }
                    .disabled(templateTitle.isEmpty)
                }
            }
        }
    }
    
    private func saveRecurringReminder() {
        recurringReminder.templateTitle = templateTitle
        recurringReminder.templateDetails = templateDetails.isEmpty ? nil : templateDetails
        
        if let rule = recurringReminder.recurrenceRule {
            rule.pattern = selectedPattern
            rule.endDate = hasEndDate ? endDate : nil
        }
        
        do {
            try context.save()
            dismiss()
        } catch {
            // Handle error - could show alert
            // Handle error silently in production
        }
    }
}

#Preview {
    let recurring = RecurringReminder(title: "Daily Standup", details: "Team meeting", priority: .medium, recurrenceRule: RecurrenceRule())
    return EditRecurringReminderView(recurringReminder: recurring)
        .modelContainer(for: [RecurringReminder.self, RecurrenceRule.self])
}
