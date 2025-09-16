//
//  EditTimeGoalView.swift
//  a-do
//
//  Edit existing time goal
//

import SwiftUI
import SwiftData

struct EditTimeGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let goal: TimeGoal
    
    @State private var goalTitle: String
    @State private var selectedCategory: String
    @State private var targetHours: Int
    @State private var targetMinutes: Int
    @State private var goalDescription: String
    @State private var startDate: Date
    @State private var endDate: Date
    
    let categories = ["Work", "Study", "Exercise", "Reading", "Creative", "Personal", "Health", "Social", "Travel", "Other"]
    
    init(goal: TimeGoal) {
        self.goal = goal
        self._goalTitle = State(initialValue: goal.title)
        self._selectedCategory = State(initialValue: goal.category)
        
        let totalMinutes = Int(goal.targetDuration / 60)
        self._targetHours = State(initialValue: totalMinutes / 60)
        self._targetMinutes = State(initialValue: totalMinutes % 60)
        
        self._goalDescription = State(initialValue: "")
        self._startDate = State(initialValue: goal.startDate)
        self._endDate = State(initialValue: goal.endDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Title", text: $goalTitle)
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
                        Text(goalTitle.isEmpty ? "Goal Title" : goalTitle)
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
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(goalTitle.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        goal.title = goalTitle
        goal.category = selectedCategory
        goal.targetDuration = TimeInterval(targetHours * 3600 + targetMinutes * 60)
        // goalDescription is not a property of TimeGoal, so we'll skip it
        goal.startDate = startDate
        goal.endDate = endDate
        
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
    let goal = TimeGoal(title: "Daily Work", targetDuration: 28800, category: "Work")
    EditTimeGoalView(goal: goal)
        .modelContainer(for: [TimeGoal.self])
}
