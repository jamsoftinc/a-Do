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
    
    // MARK: - Device Adaptive Design Tokens
    
    /// Adaptive spacing values
    enum Spacing {
        static let small = DeviceAdaptive.spacing(compact: 8, regular: 12, sizeClass: nil)
        static let medium = DeviceAdaptive.spacing(compact: 16, regular: 24, sizeClass: nil)
        static let large = DeviceAdaptive.spacing(compact: 20, regular: 32, sizeClass: nil)
        static let extraLarge = DeviceAdaptive.spacing(compact: 24, regular: 40, sizeClass: nil)
    }
    
    /// Adaptive padding values
    enum Padding {
        static let small = DeviceAdaptive.padding(compact: 12, regular: 16, sizeClass: nil)
        static let medium = DeviceAdaptive.padding(compact: 16, regular: 24, sizeClass: nil)
        static let large = DeviceAdaptive.padding(compact: 20, regular: 32, sizeClass: nil)
    }
    
    /// Adaptive corner radius values
    enum CornerRadius {
        static let small = DeviceAdaptive.cornerRadius(compact: 8, regular: 12, sizeClass: nil)
        static let medium = DeviceAdaptive.cornerRadius(compact: 12, regular: 16, sizeClass: nil)
        static let large = DeviceAdaptive.cornerRadius(compact: 16, regular: 20, sizeClass: nil)
    }
    
    /// Returns adaptive spacing for given size class
    static func adaptiveSpacing(_ size: SpacingSize, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        switch size {
        case .small: return DeviceAdaptive.spacing(compact: 8, regular: 12, sizeClass: sizeClass)
        case .medium: return DeviceAdaptive.spacing(compact: 16, regular: 24, sizeClass: sizeClass)
        case .large: return DeviceAdaptive.spacing(compact: 20, regular: 32, sizeClass: sizeClass)
        case .extraLarge: return DeviceAdaptive.spacing(compact: 24, regular: 40, sizeClass: sizeClass)
        }
    }
    
    /// Returns adaptive padding for given size class
    static func adaptivePadding(_ size: SpacingSize, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        switch size {
        case .small: return DeviceAdaptive.padding(compact: 12, regular: 16, sizeClass: sizeClass)
        case .medium: return DeviceAdaptive.padding(compact: 16, regular: 24, sizeClass: sizeClass)
        case .large: return DeviceAdaptive.padding(compact: 20, regular: 32, sizeClass: sizeClass)
        case .extraLarge: return DeviceAdaptive.padding(compact: 24, regular: 40, sizeClass: sizeClass)
        }
    }
}

enum SpacingSize {
    case small, medium, large, extraLarge
}


