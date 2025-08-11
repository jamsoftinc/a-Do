import SwiftUI

enum AppTheme {
    static let gradientColors: [Color] = [
        Color(red: 0.36, green: 0.10, blue: 0.85), // Indigo
        Color(red: 0.53, green: 0.20, blue: 0.92), // Purple
        Color(red: 1.00, green: 0.62, blue: 0.11)  // Amber
    ]

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return Color(red: 0.96, green: 0.27, blue: 0.33) // Red
        case .medium: return Color(red: 0.98, green: 0.66, blue: 0.15) // Orange
        case .low: return Color(red: 0.18, green: 0.80, blue: 0.44) // Green
        case .none: return Color.secondary
        }
    }

    static let cardBackground = Color(.secondarySystemBackground)
    static let cardStroke = Color(.systemFill)
}


