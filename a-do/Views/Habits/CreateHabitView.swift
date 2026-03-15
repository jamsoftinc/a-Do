//
//  CreateHabitView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI

struct CreateHabitView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "#007AFF"
    @State private var selectedFrequency = HabitFrequency.daily
    @State private var targetCount = 1
    @State private var unit = "times"
    
    let onSave: (String, String, String, String, HabitFrequency, Int, String) -> Void
    
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
                        Text("Create New Habit")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Build a positive routine that sticks")
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
                                
                                TextField(
                                    "",
                                    text: $title,
                                    prompt: Text("Enter habit title")
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                )
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                TextField(
                                    "",
                                    text: $description,
                                    prompt: Text("Enter description")
                                        .foregroundStyle(AppTheme.Colors.textTertiary),
                                    axis: .vertical
                                )
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                        }
                    }
                    
                    // Appearance
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Appearance", icon: "paintbrush")
                        
                        VStack(spacing: 16) {
                            // Icon Selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Icon")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    if !EntitlementManager.shared.isProUser {
                                        ProFeaturesAvailableBadge()
                                    }
                                }
                                
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
                                    
                                    TextField(
                                        "",
                                        text: $unit,
                                        prompt: Text("Unit")
                                            .foregroundStyle(AppTheme.Colors.textTertiary)
                                    )
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
                    .foregroundStyle(AppTheme.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveHabit() {
        onSave(
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            description.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedIcon,
            selectedColor,
            selectedFrequency,
            targetCount,
            unit.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(AppTheme.Colors.primary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - Color Button
struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: color) ?? AppTheme.Colors.primary)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.primary, lineWidth: isSelected ? 2 : 0)
                )
        }
    }
}

// MARK: - Frequency Button
struct FrequencyButton: View {
    let frequency: HabitFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: frequency.icon)
                    .font(.title3)
                
                Text(frequency.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Habit Preview Card
struct HabitPreviewCard: View {
    let title: String
    let description: String
    let icon: String
    let color: String
    let frequency: HabitFrequency
    let targetCount: Int
    let unit: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: color) ?? AppTheme.Colors.primary)
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    Text("\(frequency.displayName)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("\(targetCount) \(unit)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.background)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: color)?.opacity(0.3) ?? AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surfaceLight)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.Colors.primary.opacity(0.24), lineWidth: 1)
            )
    }
}

#Preview {
    CreateHabitView { _, _, _, _, _, _, _ in }
}
