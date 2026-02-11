import Foundation
import SwiftData

// MARK: - Shadow Task (Unstructured Thought)
@Model
final class ShadowTask {
    var id: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()
    var suggestedReminderID: UUID?
    var isPromoted: Bool = false
    var promotedAt: Date?
    
    init(content: String) {
        self.content = content
        self.createdAt = Date()
    }
    
    func promote(to reminderID: UUID) {
        self.suggestedReminderID = reminderID
        self.isPromoted = true
        self.promotedAt = Date()
    }
}
