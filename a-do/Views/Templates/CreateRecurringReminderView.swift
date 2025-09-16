//
//  CreateRecurringReminderView.swift
//  a-do
//
//  Create new recurring reminder
//

import SwiftUI
import SwiftData

struct CreateRecurringReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    @State private var selectedTemplate: ReminderTemplate?
    @State private var selectedPattern = RecurrencePattern.daily
    @State private var startDate = Date()
    @State private var endDate: Date?
    @State private var hasEndDate = false
    
    @Query private var templates: [ReminderTemplate]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    if templates.isEmpty {
                        Text("No templates available. Create a template first.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Template", selection: $selectedTemplate) {
                            Text("Select Template").tag(nil as ReminderTemplate?)
                            ForEach(templates, id: \.id) { template in
                                HStack {
                                    Image(systemName: template.icon)
                                        .foregroundColor(Color(hex: template.colorHex) ?? .blue)
                                    Text(template.name)
                                }.tag(template as ReminderTemplate?)
                            }
                        }
                    }
                }
                
                if selectedTemplate != nil {
                    Section("Recurrence Pattern") {
                        Picker("Pattern", selection: $selectedPattern) {
                            ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                                Text(pattern.displayName).tag(pattern)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section("Schedule") {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        
                        Toggle("Has End Date", isOn: $hasEndDate)
                        
                        if hasEndDate {
                            DatePicker("End Date", selection: Binding(
                                get: { endDate ?? Date() },
                                set: { endDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                    
                    Section("Preview") {
                        if let template = selectedTemplate {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: template.icon)
                                        .foregroundColor(Color(hex: template.colorHex) ?? .blue)
                                    Text(template.name)
                                        .font(.headline)
                                }
                                
                                Text(template.title)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Text("Repeats: \(selectedPattern.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Starts: \(startDate, style: .date)")
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
                }
            }
            .navigationTitle("Create Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createRecurringReminder()
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
        }
    }
    
    private func createRecurringReminder() {
        guard let template = selectedTemplate else { return }
        
        let recurring = recurringManager.createRecurringReminder(
            template: template,
            pattern: selectedPattern,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            context: context
        )
        
        // Generate initial reminder
        recurringManager.generateRemindersForRecurring(recurring, context: context)
        
        dismiss()
    }
}

#Preview {
    CreateRecurringReminderView()
        .modelContainer(for: [ReminderTemplate.self, RecurringReminder.self, RecurrenceRule.self])
}
