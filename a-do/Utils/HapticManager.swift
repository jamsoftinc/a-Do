import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        notificationGenerator.prepare()
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    func play(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
    
    func impact() {
        impactGenerator.impactOccurred()
    }
    
    func selection() {
        selectionGenerator.selectionChanged()
    }
}
