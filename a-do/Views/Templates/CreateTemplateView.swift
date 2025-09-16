//
//  CreateTemplateView.swift
//  a-do
//
//  Create new reminder template
//

import SwiftUI
import SwiftData

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    @State private var templateName = ""
    @State private var templateTitle = ""
    @State private var templateDetails = ""
    @State private var selectedCategory = "Personal"
    @State private var selectedIcon = "doc.text"
    @State private var selectedColor = "#007AFF"
    @State private var selectedPriority = Priority.medium
    
    let categories = ["Personal", "Work", "Health", "Home", "Finance", "Social", "Learning", "Other"]
    let icons = ["doc.text", "calendar", "clock", "bell", "star", "heart", "house", "briefcase", "book", "gamecontroller"]
    let colors = ["#007AFF", "#FF3B30", "#34C759", "#FF9500", "#AF52DE", "#FF2D92", "#5AC8FA", "#FFCC00"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template Name", text: $templateName)
                    TextField("Reminder Title", text: $templateTitle)
                    TextField("Details (Optional)", text: $templateDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Appearance") {
                    iconSelectionView
                    colorSelectionView
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priorityIcon(for: priority))
                                Text(priority.title)
                            }.tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Create Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(templateName.isEmpty || templateTitle.isEmpty)
                }
            }
        }
    }
    
    private func saveTemplate() {
        let template = ReminderTemplate(
            name: templateName,
            title: templateTitle,
            category: selectedCategory
        )
        template.details = templateDetails.isEmpty ? nil : templateDetails
        template.icon = selectedIcon
        template.colorHex = selectedColor
        template.priority = selectedPriority.rawValue
        
        context.insert(template)
        
        do {
            try context.save()
            dismiss()
        } catch {
            // Handle error - could show alert
            // Handle error silently in production
        }
    }
    
    private func priorityIcon(for priority: Priority) -> String {
        switch priority {
        case .none: return "circle"
        case .low: return "1.circle"
        case .medium: return "2.circle"
        case .high: return "3.circle"
        }
    }
    
    private var iconSelectionView: some View {
        HStack {
            Text("Icon")
            Spacer()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(selectedIcon == icon ? .white : .primary)
                            .frame(width: 40, height: 40)
                            .background(
                                selectedIcon == icon ? (Color(hex: selectedColor) ?? .blue) : Color.gray.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
            }
        }
    }
    
    private var colorSelectionView: some View {
        HStack {
            Text("Color")
            Spacer()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(Color(hex: color) ?? .blue)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? .primary : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    CreateTemplateView()
        .modelContainer(for: [ReminderTemplate.self])
}
