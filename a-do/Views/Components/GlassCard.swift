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
            .background(AppTheme.Gradients.card, in: RoundedRectangle(cornerRadius: adaptiveCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: adaptiveCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Colors.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}


