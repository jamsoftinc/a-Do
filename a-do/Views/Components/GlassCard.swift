import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    private var adaptiveCornerRadius: CGFloat {
        horizontalSizeClass == .regular ? 20 : 16
    }

    var body: some View {
        content
            .padding(adaptivePadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: adaptiveCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: adaptiveCornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
