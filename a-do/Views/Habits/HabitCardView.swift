//
//  HabitCardView.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let onTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    @State private var showingQuickActions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Card Content
            HStack(spacing: 16) {
                // Icon and Color
                ZStack {
                    Circle()
                        .fill(Color(hex: habit.color) ?? AppTheme.Colors.primary)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: habit.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Habit Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(habit.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !habit.isActive {
                            Text("Inactive")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.gray)
                                .cornerRadius(8)
                        }
                    }
                    
                    if !habit.habitDescription.isEmpty {
                        Text(habit.habitDescription)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    // Progress and Stats
                    HStack(spacing: 16) {
                        // Today's Progress
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            HStack(spacing: 4) {
                                Text("\(habit.todayEntry?.count ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("/ \(habit.targetCount) \(habit.unit)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        
                        // Streak
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text("\(habit.currentStreak)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Quick Actions
                VStack(spacing: 8) {
                    // Increment Button
                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(habit.isCompletedToday ? Color.green : AppTheme.Colors.primary)
                            .clipShape(Circle())
                    }
                    .disabled(!habit.isActive)
                    
                    // Decrement Button
                    Button(action: onDecrement) {
                        Image(systemName: "minus")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .disabled(!habit.isActive || (habit.todayEntry?.count ?? 0) <= 0)
                }
            }
            .padding()
            .background(AppTheme.Colors.background)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .onTapGesture {
                onTap()
            }
            
            // Progress Bar
            ProgressView(value: habit.progressToday)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: habit.color) ?? AppTheme.Colors.primary))
                .frame(height: 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(2)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Habit Quick Actions View
struct HabitQuickActionsView: View {
    let habit: Habit
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Increment Button
            Button(action: onIncrement) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Add")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            .disabled(!habit.isActive)
            
            // Decrement Button
            Button(action: onDecrement) {
                VStack(spacing: 4) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Remove")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            .disabled(!habit.isActive || (habit.todayEntry?.count ?? 0) <= 0)
            
            Spacer()
            
            // Edit Button
            Button(action: onEdit) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            // Delete Button
            Button(action: onDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Delete")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.background)
        .cornerRadius(16)
    }
}

// MARK: - Habit Progress Ring
struct HabitProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    
    init(progress: Double, color: Color, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
                .frame(width: size, height: size)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Progress Text
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

// MARK: - Habit Streak Badge
struct HabitStreakBadge: View {
    let streak: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("\(streak)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        HabitCardView(
            habit: Habit(title: "Drink Water", description: "Stay hydrated", icon: "drop.fill", color: "#007AFF"),
            onTap: {},
            onIncrement: {},
            onDecrement: {}
        )
        
        HabitCardView(
            habit: Habit(title: "Exercise", description: "30 minutes of physical activity", icon: "figure.run", color: "#FF3B30"),
            onTap: {},
            onIncrement: {},
            onDecrement: {}
        )
    }
    .padding()
    .background(AppTheme.Colors.surface)
}
