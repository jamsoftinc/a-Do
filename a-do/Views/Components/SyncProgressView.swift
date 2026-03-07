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
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 64, 420)

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.accentColor)
                            .scaleEffect(1.0 + sin(animationOffset) * 0.06)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationOffset)

                        Text("a-do")
                            .font(.largeTitle.bold())
                    }

                    VStack(spacing: 20) {
                        Text(syncManager.currentSyncOperation)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: syncManager.currentSyncOperation)

                        VStack(spacing: 12) {
                            ProgressView(value: syncManager.syncProgress, total: 1.0)
                                .tint(.accentColor)
                                .frame(maxWidth: contentWidth)
                                .animation(.easeInOut(duration: 0.5), value: syncManager.syncProgress)

                            Text("\(Int(syncManager.syncProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

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
                    .frame(maxWidth: contentWidth)

                    if syncManager.hasErrors, let error = syncManager.syncError {
                        VStack(spacing: 8) {
                            Label("Sync Warning", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: contentWidth)
                        .background(Color.orange.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            animationOffset = 1.0
        }
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
                .foregroundStyle(foregroundColor)
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .opacity(isActive || isCompleted ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.15)
        } else if isActive {
            return Color.accentColor.opacity(0.15)
        } else {
            return Color(.tertiarySystemFill)
        }
    }

    private var foregroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .accentColor
        } else {
            return Color(.tertiaryLabel)
        }
    }
}

#Preview {
    SyncProgressView()
}
