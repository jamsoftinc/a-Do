//
//  EditHabitView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

struct EditHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let habit: Habit
    
    @State private var title: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var selectedFrequency: HabitFrequency
    @State private var targetCount: Int
    @State private var unit: String
    @State private var isActive: Bool
    
    init(habit: Habit) {
        self.habit = habit
        self._title = State(initialValue: habit.title)
        self._description = State(initialValue: habit.habitDescription)
        self._selectedIcon = State(initialValue: habit.icon)
        self._selectedColor = State(initialValue: habit.color)
        self._selectedFrequency = State(initialValue: habit.frequency ?? .daily)
        self._targetCount = State(initialValue: habit.targetCount)
        self._unit = State(initialValue: habit.unit)
        self._isActive = State(initialValue: habit.isActive)
    }
    
    private let availableIcons = [
        "star.fill", "heart.fill", "drop.fill", "figure.run", "book.fill",
        "pencil.fill", "camera.fill", "music.note", "gamecontroller.fill",
        "car.fill", "house.fill", "leaf.fill", "sun.max.fill", "moon.fill",
        "flame.fill", "bolt.fill", "leaf.arrow.circlepath", "brain.head.profile",
        "lungs.fill", "eye.fill", "ear.fill", "hand.raised.fill", "foot.fill"
    ]
    
    private let availableColors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500", "#AF52DE",
        "#FF2D92", "#5AC8FA", "#FFCC00", "#FF6B6B", "#4ECDC4",
        "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Edit Habit")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Update your habit settings")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top)
                    
                    // Basic Information
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Basic Information", icon: "info.circle")
                        
                        VStack(spacing: 16) {
                            // Title
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField("Enter habit title", text: $title)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField("Enter description", text: $description, axis: .vertical)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                            
                            // Active Toggle
                            HStack {
                                Text("Active")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isActive)
                                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.background)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Appearance
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Appearance", icon: "paintbrush")
                        
                        VStack(spacing: 16) {
                            // Icon Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Icon")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                    ForEach(availableIcons, id: \.self) { icon in
                                        IconButton(
                                            icon: icon,
                                            isSelected: selectedIcon == icon
                                        ) {
                                            selectedIcon = icon
                                        }
                                    }
                                }
                            }
                            
                            // Color Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Color")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                                    ForEach(availableColors, id: \.self) { color in
                                        ColorButton(
                                            color: color,
                                            isSelected: selectedColor == color
                                        ) {
                                            selectedColor = color
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Tracking Settings
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Tracking Settings", icon: "slider.horizontal.3")
                        
                        VStack(spacing: 16) {
                            // Frequency
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Frequency")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack(spacing: 12) {
                                    ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                                        FrequencyButton(
                                            frequency: frequency,
                                            isSelected: selectedFrequency == frequency
                                        ) {
                                            selectedFrequency = frequency
                                        }
                                    }
                                }
                            }
                            
                            // Target Count
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Count")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack {
                                    Stepper(value: $targetCount, in: 1...100) {
                                        Text("\(targetCount)")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    TextField("Unit", text: $unit)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .frame(width: 80)
                                }
                            }
                        }
                    }
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Preview", icon: "eye")
                        
                        HabitPreviewCard(
                            title: title.isEmpty ? "Habit Title" : title,
                            description: description.isEmpty ? "Habit description" : description,
                            icon: selectedIcon,
                            color: selectedColor,
                            frequency: selectedFrequency,
                            targetCount: targetCount,
                            unit: unit
                        )
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveHabit() {
        habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.habitDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.icon = selectedIcon
        habit.color = selectedColor
        habit.frequency = selectedFrequency
        habit.targetCount = max(1, targetCount)
        habit.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.isActive = isActive
        habit.updatedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

#Preview {
    EditHabitView(habit: Habit(title: "Drink Water", description: "Stay hydrated", icon: "drop.fill", color: "#007AFF"))
}
