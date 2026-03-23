import SwiftUI
import UIKit

// MARK: - App Theme
struct AppTheme {
    private static let defaultAccentHex = "#67A2DC"

    private enum Palette {
        static let robotBlue = "#67A2DC"
        static let eyeBlue = "#46BCFA"
        static let frost = "#91D0EA"
        static let copper = "#D1915B"
        static let cream = "#F7F3EC"
        static let mist = "#EAF6FB"
        static let sky = "#D6EEF9"
        static let slate = "#4E6885"
        static let steel = "#82717D"
        static let midnight = "#10233C"
        static let deepSurface = "#14253A"
        static let deepSurfaceAlt = "#1B3550"
        static let deepText = "#F2F8FF"
        static let deepSecondaryText = "#B7D2E9"
        static let deepTertiaryText = "#7E9BB8"
        static let success = "#28B86F"
        static let error = "#D94F57"
    }

    fileprivate static func color(_ hex: String, alpha: Double = 1.0) -> Color {
        Color(hex: hex, alpha: alpha) ?? .accentColor
    }

    fileprivate static func dynamicColor(light: String, dark: String) -> Color {
        Color(uiColor: dynamicUIColor(light: light, dark: dark))
    }

    fileprivate static func dynamicUIColor(light: String, dark: String) -> UIColor {
        UIColor { traitCollection in
            UIColor(hex: traitCollection.userInterfaceStyle == .dark ? dark : light) ?? .systemBackground
        }
    }

    fileprivate static var currentAccentHex: String {
        let stored = UserDefaults.standard.string(forKey: "appAccentColor")?.uppercased()
        if let stored, !stored.isEmpty {
            return stored
        }

        return defaultAccentHex
    }

    // MARK: - Color Palette
    struct Colors {
        static var primary: Color { AppTheme.color(AppTheme.currentAccentHex) }
        static var primaryLight: Color { AppTheme.color(Palette.eyeBlue) }
        static var primaryDark: Color { AppTheme.color("#4D86C1") }

        static let secondary = AppTheme.color(Palette.copper)
        static let accent = AppTheme.color(Palette.frost)

        static let background = AppTheme.dynamicColor(light: Palette.mist, dark: Palette.midnight)
        static let surface = AppTheme.dynamicColor(light: Palette.cream, dark: Palette.deepSurface)
        static let surfaceLight = AppTheme.dynamicColor(light: Palette.sky, dark: Palette.deepSurfaceAlt)

        static let textPrimary = AppTheme.dynamicColor(light: "#16324A", dark: Palette.deepText)
        static let textSecondary = AppTheme.dynamicColor(light: Palette.slate, dark: Palette.deepSecondaryText)
        static let textTertiary = AppTheme.dynamicColor(light: "#7A93AA", dark: Palette.deepTertiaryText)

        static let success = AppTheme.color(Palette.success)
        static let warning = AppTheme.color(Palette.copper)
        static let error = AppTheme.color(Palette.error)
        static let info = AppTheme.color(Palette.eyeBlue)

        static let priorityHigh = error
        static let priorityMedium = warning
        static let priorityLow = primary
        static let priorityNone = textTertiary
    }

    // MARK: - UIKit Colors
    struct UIColors {
        static let primary = AppTheme.dynamicUIColor(light: Palette.robotBlue, dark: Palette.eyeBlue)
        static let background = AppTheme.dynamicUIColor(light: Palette.mist, dark: Palette.midnight)
        static let surface = AppTheme.dynamicUIColor(light: Palette.cream, dark: Palette.deepSurface)
        static let textPrimary = AppTheme.dynamicUIColor(light: "#16324A", dark: Palette.deepText)
        static let textSecondary = AppTheme.dynamicUIColor(light: Palette.slate, dark: Palette.deepSecondaryText)
    }

    // MARK: - Gradients
    struct Gradients {
        static let primary = LinearGradient(
            colors: [Colors.primaryLight, Colors.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondary = LinearGradient(
            colors: [AppTheme.color("#F0C48A"), Colors.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let background = LinearGradient(
            colors: [
                AppTheme.dynamicColor(light: "#E8F7FF", dark: "#0A1730"),
                AppTheme.dynamicColor(light: "#B7E3F7", dark: "#173357")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let card = LinearGradient(
            colors: [Colors.surface, Colors.surfaceLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cardShadow = LinearGradient(
            colors: [Colors.primary.opacity(0.08), Colors.accent.opacity(0.02)],
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
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
    }

    // MARK: - Shadows (Neutral-tinted for clean card aesthetic)
    struct Shadows {
        static let small = Shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
        static let large = Shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 8)
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
        self.background(AppTheme.Colors.background)
    }

    func appCard() -> some View {
        self.background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.medium)
    }

    func primaryText() -> some View {
        self.foregroundStyle(AppTheme.Colors.textPrimary)
    }

    func secondaryText() -> some View {
        self.foregroundStyle(AppTheme.Colors.textSecondary)
    }

    func tertiaryText() -> some View {
        self.foregroundStyle(AppTheme.Colors.textTertiary)
    }
}

private extension UIColor {
    convenience init?(hex: String, alpha: CGFloat = 1.0) {
        var formatted = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if formatted.count == 3 {
            let chars = Array(formatted)
            formatted = String([chars[0], chars[0], chars[1], chars[1], chars[2], chars[2]])
        }

        guard formatted.count == 6, let intCode = Int(formatted, radix: 16) else { return nil }

        let red = CGFloat((intCode >> 16) & 0xFF) / 255.0
        let green = CGFloat((intCode >> 8) & 0xFF) / 255.0
        let blue = CGFloat(intCode & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
