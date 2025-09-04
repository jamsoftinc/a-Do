//
//  AddHabitEntryView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData

struct AddHabitEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let habit: Habit
    
    @State private var count: Int = 1
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Add Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Record your progress for \(habit.title)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Habit Info Card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: habit.color) ?? AppTheme.Colors.primary)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: habit.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if !habit.habitDescription.isEmpty {
                            Text(habit.habitDescription)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Text("Target: \(habit.targetCount) \(habit.unit)")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppTheme.Colors.background)
                .cornerRadius(16)
                
                // Entry Form
                VStack(spacing: 20) {
                    // Date Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text(selectedDate, style: .date)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.background)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Count Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Count")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 16) {
                            // Decrement Button
                            Button(action: {
                                if count > 0 {
                                    count -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                            .disabled(count <= 0)
                            
                            // Count Display
                            VStack(spacing: 4) {
                                Text("\(count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text(habit.unit)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .frame(minWidth: 80)
                            
                            // Increment Button
                            Button(action: {
                                count += 1
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.background)
                        .cornerRadius(12)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextField("Add a note about this entry...", text: $notes, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                
                Spacer()
                
                // Save Button
                Button(action: saveEntry) {
                    Text("Save Entry")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(12)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
    }
    
    private func saveEntry() {
        habit.addEntry(count: count, notes: notes, date: selectedDate)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Date")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top)
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(AppTheme.Colors.background)
                .cornerRadius(16)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    AddHabitEntryView(habit: Habit(title: "Drink Water", description: "Stay hydrated", icon: "drop.fill", color: "#007AFF"))
}
