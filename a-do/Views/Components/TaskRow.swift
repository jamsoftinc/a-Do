import SwiftUI

struct TaskRow: View {
    let title: String
    let isCompleted: Bool
    var priority: Priority = .none
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onToggle?()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isCompleted ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isCompleted {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(isCompleted ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                .strikethrough(isCompleted)
                .lineLimit(2)

            Spacer()

            if priority == .high {
                Text("HIGH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.error)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.error.opacity(0.12), in: Capsule())
            } else if priority == .medium {
                Text("MED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.warning.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }
}
