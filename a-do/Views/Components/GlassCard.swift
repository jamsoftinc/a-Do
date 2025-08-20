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
                    .strokeBorder(AppTheme.cardStroke.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 6)
    }
}


