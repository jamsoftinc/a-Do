import SwiftUI

struct HabitProgressRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let progressText: String
    let progress: Double // 0.0 to 1.0
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Spacer()

                    if isCompleted {
                        Text("Completed")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.success)
                    } else {
                        Text(progressText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(iconColor.opacity(0.14))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(iconColor)
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 8)
    }
}
