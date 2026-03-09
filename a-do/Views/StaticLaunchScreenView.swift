import SwiftUI

/// Static launch screen view optimized for fast startup
/// This view is designed to be lightweight and render quickly
struct StaticLaunchScreenView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        ZStack {
            // Background gradient
            AppTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: adaptiveSpacing) {
                Spacer()
                
                // App icon - static, no animations for fast rendering
                appIconView
                
                // App title
                Text("a-do")
                    .font(adaptiveFont)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Views
    
    private var appIconView: some View {
        Group {
            if let appIcon = UIImage(named: "AppLogo") {
                Image(uiImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                // Fallback using SF Symbols
                Image(systemName: "bell.fill")
                    .font(.system(size: iconSize * 0.6))
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        RoundedRectangle(cornerRadius: iconCornerRadius)
                            .fill(AppTheme.Colors.surface)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    // MARK: - Device Adaptive Properties
    
    private var iconSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 140 // iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .compact {
            return 110 // iPhone landscape or iPad compact
        } else {
            return 90 // iPhone portrait
        }
    }
    
    private var iconCornerRadius: CGFloat {
        iconSize * 0.2237 // Apple's standard app icon corner radius ratio
    }
    
    private var adaptiveSpacing: CGFloat {
        if horizontalSizeClass == .regular {
            return 40
        } else {
            return 28
        }
    }
    
    private var adaptiveFont: Font {
        if horizontalSizeClass == .regular {
            return .system(size: 38, weight: .bold, design: .rounded)
        } else {
            return .system(size: 28, weight: .bold, design: .rounded)
        }
    }
}

// MARK: - Preview

#Preview("iPhone") {
    StaticLaunchScreenView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("iPad") {
    StaticLaunchScreenView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("iPhone Landscape") {
    StaticLaunchScreenView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .compact)
}
