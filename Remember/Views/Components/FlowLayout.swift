import SwiftUI

struct FlowLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content
    
    private var adaptiveMinimum: CGFloat {
        horizontalSizeClass == .regular ? 100 : 80
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: adaptiveMinimum), spacing: spacing)], 
            alignment: alignment, 
            spacing: spacing, 
            content: content
        )
    }
}


