import SwiftUI

struct TimelineEventCard: View {
    let title: String
    let subtitle: String
    let color: Color
    var hasVideoIcon: Bool = false
    var isDraggable: Bool = false
    var isReminder: Bool = false
    var isHighPriority: Bool = false
    var isCompleted: Bool = false
    var onToggleComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if isReminder {
                Button {
                    onToggleComplete?()
                } label: {
                    Circle()
                        .stroke(isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if isCompleted {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isReminder ? AppTheme.Colors.textPrimary : .white)

                HStack(spacing: 6) {
                    if isDraggable {
                        HStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal")
                                .font(.caption2)
                            Text("DRAGGABLE")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(AppTheme.Colors.primary)
                    } else if isHighPriority {
                        Text("HIGHPRIORITY")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.error)
                    } else {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isReminder ? AppTheme.Colors.textSecondary : .white.opacity(0.8))
                    }
                }
            }

            Spacer()

            if hasVideoIcon {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if isReminder {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .fill(isReminder ? AppTheme.Colors.surface : color)
                .shadow(color: .black.opacity(isReminder ? 0.04 : 0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .strokeBorder(isReminder ? AppTheme.Colors.textTertiary.opacity(0.2) : .clear, lineWidth: 1)
        )
    }
}

struct TimelineEmptySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
            .strokeBorder(AppTheme.Colors.textTertiary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
            .frame(height: 56)
    }
}
