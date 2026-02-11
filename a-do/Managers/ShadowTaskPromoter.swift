import Foundation
import SwiftData

struct ShadowTaskPromoter {
    
    static func promote(_ shadowTask: ShadowTask) -> Reminder {
        // 1. Analyze content for keywords
        let content = shadowTask.content
        var title = content
        var priority: Priority = .none
        var dueDate: Date? = nil
        
        // Very basic "AI" (Keyword matching)
        if content.localizedCaseInsensitiveContains("urgent") || content.localizedCaseInsensitiveContains("asap") {
            priority = .high
            title = title.replacingOccurrences(of: "urgent", with: "", options: .caseInsensitive)
            title = title.replacingOccurrences(of: "asap", with: "", options: .caseInsensitive)
        } else if content.localizedCaseInsensitiveContains("important") {
            priority = .medium
            title = title.replacingOccurrences(of: "important", with: "", options: .caseInsensitive)
        }
        
        // Date detection using system date detector plus common relative keywords.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)),
           let extractedDate = match.date {
            dueDate = extractedDate
            if let range = Range(match.range, in: title) {
                title.removeSubrange(range)
            }
        } else if content.localizedCaseInsensitiveContains("tomorrow") {
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            title = title.replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
        } else if content.localizedCaseInsensitiveContains("today") {
            dueDate = Date()
            title = title.replacingOccurrences(of: "today", with: "", options: .caseInsensitive)
        }
        
        // Clean up title
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = "Untitled Task" }
        
        // Create Reminder
        let reminder = Reminder(
            title: title,
            dueDate: dueDate,
            priority: priority,
            energyLevel: .medium // Default
        )
        
        return reminder
    }
}
