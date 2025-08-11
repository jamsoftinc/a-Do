import SwiftUI

struct FlowLayout<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], alignment: alignment, spacing: spacing, content: content)
    }
}


