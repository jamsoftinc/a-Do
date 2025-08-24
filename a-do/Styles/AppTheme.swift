import SwiftUI

// MARK: - App Theme
struct AppTheme {
    
    // MARK: - Color Palette
    struct Colors {
        // Primary brand colors
        static let primary = Color(red: 0.4, green: 0.2, blue: 0.8) // Deep purple
        static let primaryLight = Color(red: 0.5, green: 0.3, blue: 0.9) // Lighter purple
        static let primaryDark = Color(red: 0.3, green: 0.1, blue: 0.7) // Darker purple
        
        // Secondary colors
        static let secondary = Color(red: 0.9, green: 0.4, blue: 0.6) // Pink accent
        static let accent = Color(red: 0.2, green: 0.8, blue: 0.6) // Teal accent
        
        // Background colors - Much lighter for better readability
        static let background = Color(red: 0.98, green: 0.98, blue: 1.0) // Very light blue-white
        static let surface = Color.white // Pure white cards
        static let surfaceLight = Color(red: 0.97, green: 0.97, blue: 0.99) // Very light gray
        
        // Text colors - Dark for contrast against light backgrounds
        static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.2) // Dark blue-gray
        static let textSecondary = Color(red: 0.3, green: 0.3, blue: 0.4) // Medium gray
        static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.6) // Light gray
        
        // Status colors
        static let success = Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        static let warning = Color(red: 0.9, green: 0.6, blue: 0.2) // Orange
        static let error = Color(red: 0.9, green: 0.3, blue: 0.3) // Red
        static let info = Color(red: 0.2, green: 0.6, blue: 0.9) // Blue
        
        // Priority colors
        static let priorityHigh = Color(red: 0.9, green: 0.3, blue: 0.3) // Red
        static let priorityMedium = Color(red: 0.9, green: 0.6, blue: 0.2) // Orange
        static let priorityLow = Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        static let priorityNone = Color(red: 0.6, green: 0.6, blue: 0.7) // Gray
    }
    
    // MARK: - Gradients
    struct Gradients {
        static let primary = LinearGradient(
            colors: [Colors.primary, Colors.primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let secondary = LinearGradient(
            colors: [Colors.secondary, Colors.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let background = LinearGradient(
            colors: [Colors.background, Colors.surface],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let card = LinearGradient(
            colors: [Colors.surface, Colors.surfaceLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let cardShadow = LinearGradient(
            colors: [Color.black.opacity(0.05), Color.black.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .rounded)
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
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
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
        self.background(AppTheme.Gradients.background)
    }
    
    func appCard() -> some View {
        self.background(AppTheme.Gradients.card)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(radius: 8, x: 0, y: 4)
    }
    
    func primaryText() -> some View {
        self.foregroundColor(AppTheme.Colors.textPrimary)
    }
    
    func secondaryText() -> some View {
        self.foregroundColor(AppTheme.Colors.textSecondary)
    }
    
    func tertiaryText() -> some View {
        self.foregroundColor(AppTheme.Colors.textTertiary)
    }
}


