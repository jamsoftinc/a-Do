import SwiftUI

// MARK: - App Theme
struct AppTheme {

    // MARK: - Color Palette (System Semantic Colors)
    struct Colors {
        // Brand — uses the Asset Catalog AccentColor, overridable via @AppStorage
        static let primary = Color.accentColor
        static let primaryLight = Color.accentColor.opacity(0.7)
        static let primaryDark = Color.accentColor

        // Secondary colors — system palette
        static let secondary = Color.orange
        static let accent = Color.green

        // Backgrounds — system semantic (auto light/dark mode)
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let surfaceLight = Color(.tertiarySystemGroupedBackground)

        // Text — system semantic (auto light/dark mode + accessibility)
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)

        // Status colors — system
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Priority colors — matches Apple Reminders
        static let priorityHigh = Color.red
        static let priorityMedium = Color.orange
        static let priorityLow = Color.blue
        static let priorityNone = Color(.tertiaryLabel)
    }

    // MARK: - Gradients (Minimal — only for hero/immersive moments)
    struct Gradients {
        // Use ONLY for Morning Briefing, Paywall hero, onboarding — never content screens
        static let primary = LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondary = LinearGradient(
            colors: [Color.orange, Color.green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Flat system background — replaces the old gradient background
        static let background = LinearGradient(
            colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )

        static let card = LinearGradient(
            colors: [Color(.secondarySystemGroupedBackground), Color(.secondarySystemGroupedBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cardShadow = LinearGradient(
            colors: [Color.clear, Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography (System Default — .rounded only for display numbers)
    struct Typography {
        static let largeTitle = Font.largeTitle.bold()
        static let title1 = Font.title.bold()
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption1 = Font.caption
        static let caption2 = Font.caption2

        // Rounded — for large numeric displays (counts, percentages, timers)
        static let roundedNumber = Font.system(.title, design: .rounded).weight(.bold)
        static let roundedCaption = Font.system(.caption, design: .rounded).weight(.semibold)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Shadows (Minimal — Apple uses very subtle shadows)
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Priority Color Helper
extension AppTheme {
    static func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high:
            return Colors.priorityHigh
        case .medium:
            return Colors.priorityMedium
        case .low:
            return Colors.priorityLow
        case .none:
            return Colors.priorityNone
        }
    }
}

// MARK: - View Modifiers
extension View {
    func appBackground() -> some View {
        self.background(Color(.systemGroupedBackground))
    }

    func appCard() -> some View {
        self.background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(AppTheme.CornerRadius.medium)
    }

    func primaryText() -> some View {
        self.foregroundStyle(Color(.label))
    }

    func secondaryText() -> some View {
        self.foregroundStyle(Color(.secondaryLabel))
    }

    func tertiaryText() -> some View {
        self.foregroundStyle(Color(.tertiaryLabel))
    }
}
