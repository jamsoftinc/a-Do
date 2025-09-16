//
//  CreateTimeGoalView.swift
//  a-do
//
//  Create new time tracking goal
//

import SwiftUI
import SwiftData

struct CreateTimeGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var timeManager = TimeTrackingManager.shared
    
    @State private var goalName = ""
    @State private var selectedCategory = "Work"
    @State private var targetHours = 1
    @State private var targetMinutes = 0
    @State private var goalDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
    
    let categories = ["Work", "Study", "Exercise", "Reading", "Creative", "Personal", "Health", "Social", "Travel", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name", text: $goalName)
                    TextField("Description (Optional)", text: $goalDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            HStack {
                                Image(systemName: categoryIcon(for: category))
                                Text(category)
                            }.tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Target Time") {
                    HStack {
                        Picker("Hours", selection: $targetHours) {
                            ForEach(0...24, id: \.self) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Minutes", selection: $targetMinutes) {
                            ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 100)
                }
                
                Section("Timeline") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(goalName.isEmpty ? "Goal Name" : goalName)
                            .font(.headline)
                        
                        Text(selectedCategory)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Target: \(targetHours)h \(targetMinutes)m")
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Duration: \(formatDuration())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Create Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGoal()
                    }
                    .disabled(goalName.isEmpty)
                }
            }
        }
    }
    
    private func createGoal() {
        let targetDuration = TimeInterval(targetHours * 3600 + targetMinutes * 60)
        
        let goal = TimeGoal(
            title: goalName,
            targetDuration: targetDuration,
            category: selectedCategory
        )
        goal.startDate = startDate
        goal.endDate = endDate
        
        context.insert(goal)
        
        do {
            try context.save()
            dismiss()
        } catch {
            // Handle error - could show alert
            // Handle error silently in production
        }
    }
    
    private func formatDuration() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        let days = components.day ?? 0
        
        if days == 0 {
            return "Same day"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Work": return "briefcase.fill"
        case "Study": return "book.fill"
        case "Exercise": return "figure.run"
        case "Reading": return "text.book.closed.fill"
        case "Creative": return "paintbrush.fill"
        case "Personal": return "person.fill"
        case "Health": return "heart.fill"
        case "Social": return "person.2.fill"
        case "Travel": return "airplane"
        default: return "clock.fill"
        }
    }
}

#Preview {
    CreateTimeGoalView()
        .modelContainer(for: [TimeGoal.self])
}
