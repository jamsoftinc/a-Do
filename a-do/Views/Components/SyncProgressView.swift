//
//  SyncProgressView.swift
//  a-do
//
//  Sync progress indicator for initial app launch
//

import SwiftUI

struct SyncProgressView: View {
    @State private var syncManager = SyncProgressManager.shared
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App Logo/Icon
                VStack(spacing: 16) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(1.0 + sin(animationOffset) * 0.1)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationOffset)
                    
                    Text("a-do")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Progress Section
                VStack(spacing: 20) {
                    // Current Operation
                    Text(syncManager.currentSyncOperation)
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: syncManager.currentSyncOperation)
                    
                    // Progress Bar
                    VStack(spacing: 12) {
                        ProgressView(value: syncManager.syncProgress, total: 1.0)
                            .progressViewStyle(CustomProgressViewStyle())
                            .animation(.easeInOut(duration: 0.5), value: syncManager.syncProgress)
                        
                        // Progress Percentage
                        Text("\(Int(syncManager.syncProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .animation(.easeInOut(duration: 0.3), value: syncManager.syncProgress)
                    }
                    
                    // Stage Indicators
                    HStack(spacing: 16) {
                        SyncStageIndicator(
                            icon: "tray.and.arrow.down",
                            isActive: syncManager.isLoadingData,
                            isCompleted: syncManager.completedOperations > 0
                        )
                        
                        SyncStageIndicator(
                            icon: "checklist",
                            isActive: syncManager.isAppleRemindersSync,
                            isCompleted: syncManager.completedOperations > 1
                        )
                        
                        SyncStageIndicator(
                            icon: "icloud",
                            isActive: syncManager.isCloudKitSync,
                            isCompleted: syncManager.completedOperations > 2
                        )
                        
                        SyncStageIndicator(
                            icon: "calendar",
                            isActive: syncManager.isCalendarSync,
                            isCompleted: syncManager.completedOperations > 3
                        )
                        
                        SyncStageIndicator(
                            icon: "sparkles",
                            isActive: syncManager.completedOperations == 4,
                            isCompleted: syncManager.completedOperations > 4
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                
                // Error Message (if any)
                if syncManager.hasErrors, let error = syncManager.syncError {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Sync Warning")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .onAppear {
            animationOffset = 1.0
        }
    }
}

// MARK: - Custom Progress View Style
struct CustomProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.surfaceLight.opacity(0.3))
                .frame(height: 8)
            
            // Progress
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: (configuration.fractionCompleted ?? 0) * 280, height: 8)
                .animation(.easeInOut(duration: 0.5), value: configuration.fractionCompleted)
        }
        .frame(width: 280)
    }
}

// MARK: - Sync Stage Indicator
struct SyncStageIndicator: View {
    let icon: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
            
            Image(systemName: isCompleted ? "checkmark" : icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(foregroundColor)
                .scaleEffect(isActive ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .opacity(isActive || isCompleted ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.2)
        } else if isActive {
            return AppTheme.Colors.accent.opacity(0.2)
        } else {
            return AppTheme.Colors.surfaceLight.opacity(0.3)
        }
    }
    
    private var foregroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return AppTheme.Colors.accent
        } else {
            return AppTheme.Colors.textSecondary
        }
    }
}

#Preview {
    SyncProgressView()
}


