import SwiftUI

/// Utility for device-specific adaptations
struct DeviceAdaptive {
    
    /// Returns appropriate spacing for different device sizes
    static func spacing(compact: CGFloat, regular: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regular : compact
    }
    
    /// Returns appropriate padding for different device sizes
    static func padding(compact: CGFloat, regular: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regular : compact
    }
    
    /// Returns appropriate corner radius for different device sizes
    static func cornerRadius(compact: CGFloat, regular: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regular : compact
    }
    
    /// Returns appropriate font size for different device sizes
    static func fontSize(compact: CGFloat, regular: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regular : compact
    }
    
    /// Returns appropriate grid columns for different device sizes
    static func gridColumns(compact: Int, regular: Int, sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let count = sizeClass == .regular ? regular : compact
        return Array(repeating: GridItem(.flexible(), spacing: 20), count: count)
    }
    
    /// Returns appropriate minimum width for adaptive grids
    static func adaptiveMinimum(compact: CGFloat, regular: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regular : compact
    }
}

/// View modifier for device-adaptive padding
struct AdaptivePadding: ViewModifier {
    let compact: CGFloat
    let regular: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content.padding(DeviceAdaptive.padding(compact: compact, regular: regular, sizeClass: horizontalSizeClass))
    }
}

/// View modifier for device-adaptive corner radius
struct AdaptiveCornerRadius: ViewModifier {
    let compact: CGFloat
    let regular: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content.cornerRadius(DeviceAdaptive.cornerRadius(compact: compact, regular: regular, sizeClass: horizontalSizeClass))
    }
}

extension View {
    /// Apply device-adaptive padding
    func adaptivePadding(compact: CGFloat, regular: CGFloat) -> some View {
        modifier(AdaptivePadding(compact: compact, regular: regular))
    }
    
    /// Apply device-adaptive corner radius
    func adaptiveCornerRadius(compact: CGFloat, regular: CGFloat) -> some View {
        modifier(AdaptiveCornerRadius(compact: compact, regular: regular))
    }
}
