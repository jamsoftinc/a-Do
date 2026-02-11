//
//  TemplateDetailView.swift
//  a-do
//
//  Template details and management
//

import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    let template: ReminderTemplate
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Template Header
                    templateHeader
                    
                    // Template Info
                    templateInfo
                    
                    // Usage Statistics
                    usageStats
                    
                    // Quick Actions
                    quickActions
                }
                .padding()
            }
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Template") {
                            showingEditView = true
                        }
                        
                        Button("Delete Template", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditTemplateView(template: template)
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTemplate()
            }
        } message: {
            Text("Are you sure you want to delete this template? This action cannot be undone.")
        }
    }
    
    private var templateHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: template.icon)
                .font(.system(size: 60))
                .foregroundColor(Color(hex: template.colorHex) ?? .blue)
            
            VStack(spacing: 8) {
                Text(template.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .primaryText()
                
                Text(template.category)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(hex: template.colorHex)?.opacity(0.2) ?? Color.blue.opacity(0.2))
                    .foregroundColor(Color(hex: template.colorHex) ?? .blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var templateInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Information")
                .font(.headline)
                .primaryText()
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Title", value: template.title)
                
                if let details = template.details, !details.isEmpty {
                    InfoRow(label: "Details", value: details)
                }
                
                InfoRow(label: "Priority", value: template.priorityEnum.title)
                
                InfoRow(label: "Created", value: template.createdAt.formatted(date: .abbreviated, time: .omitted))
                
                if let lastUsed = template.lastUsed {
                    InfoRow(label: "Last Used", value: lastUsed.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var usageStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Statistics")
                .font(.headline)
                .primaryText()
            
            HStack(spacing: 20) {
                TemplateStatCard(title: "Times Used", value: "\(template.usageCount)", icon: "number", color: .blue)
                TemplateStatCard(title: "Last Used", value: template.lastUsed?.formatted(date: .abbreviated, time: .omitted) ?? "Never", icon: "clock", color: .green)
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
                    let _ = recurringManager.createReminderFromTemplate(template, context: context)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Reminder")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
                }
                
                Button {
                    // Navigate to create recurring reminder with this template
                } label: {
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                        Text("Create Recurring")
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
    
    private func deleteTemplate() {
        context.delete(template)
        try? context.save()
        dismiss()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .primaryText()
        }
    }
}

struct TemplateStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .primaryText()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    // Build a preview template in a local scope.
    let template: ReminderTemplate = {
        let t = ReminderTemplate(name: "Daily Standup", title: "Daily team standup meeting", category: "Work")
        t.icon = "calendar"
        t.colorHex = "#007AFF"
        t.usageCount = 15
        t.lastUsed = Date()
        return t
    }()

    return TemplateDetailView(template: template)
        .modelContainer(for: ReminderTemplate.self, inMemory: true)
}
