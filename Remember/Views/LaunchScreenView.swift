import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isAnimating = false
    @State private var showTitle = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient matching the app theme
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: adaptiveSpacing) {
                    Spacer()
                    
                    // App icon with animation
                    appIconView
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.8), value: isAnimating)
                    
                    // App title with delayed animation
                    if showTitle {
                        Text("a-do")
                            .font(adaptiveFont)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .opacity(showTitle ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.6), value: showTitle)
                    }
                    
                    Spacer()
                    
                    // Loading indicator at bottom
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(progressViewScale)
                            .tint(.white.opacity(0.8))
                        
                        Text("Loading your reminders...")
                            .font(adaptiveSubtitleFont)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Computed Properties
    
    private var appIconView: some View {
        Group {
            if let appIcon = UIImage(named: "logo-bell-up") {
                Image(uiImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                // Fallback icon using SF Symbols
                Image(systemName: "bell.fill")
                    .font(.system(size: iconSize * 0.6))
                    .foregroundColor(.white)
                    .frame(width: iconSize, height: iconSize)
                    .background(
                        RoundedRectangle(cornerRadius: iconCornerRadius)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
    }
    
    // MARK: - Device Adaptive Properties
    
    private var iconSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 160 // iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .compact {
            return 120 // iPhone landscape or iPad compact
        } else {
            return 100 // iPhone portrait
        }
    }
    
    private var iconCornerRadius: CGFloat {
        iconSize * 0.2237 // Apple's standard app icon corner radius ratio
    }
    
    private var adaptiveSpacing: CGFloat {
        DeviceAdaptive.spacing(compact: 32, regular: 48, sizeClass: horizontalSizeClass)
    }
    
    private var adaptiveFont: Font {
        if horizontalSizeClass == .regular {
            return .system(size: 42, weight: .bold, design: .rounded)
        } else {
            return .system(size: 32, weight: .bold, design: .rounded)
        }
    }
    
    private var adaptiveSubtitleFont: Font {
        if horizontalSizeClass == .regular {
            return .system(size: 18, weight: .medium, design: .rounded)
        } else {
            return .system(size: 16, weight: .medium, design: .rounded)
        }
    }
    
    private var progressViewScale: CGFloat {
        horizontalSizeClass == .regular ? 1.2 : 1.0
    }
    
    private var bottomPadding: CGFloat {
        if horizontalSizeClass == .regular {
            return 80
        } else if verticalSizeClass == .compact {
            return 40
        } else {
            return 60
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        // Start icon animation immediately
        withAnimation(.easeInOut(duration: 0.8)) {
            isAnimating = true
        }
        
        // Delay title animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.6)) {
                showTitle = true
            }
        }
    }
}

// MARK: - Preview

#Preview("iPhone") {
    LaunchScreenView()
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("iPad") {
    LaunchScreenView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .regular)
}

#Preview("iPhone Landscape") {
    LaunchScreenView()
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .compact)
}
