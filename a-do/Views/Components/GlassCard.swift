import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
