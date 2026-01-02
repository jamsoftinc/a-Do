import Foundation
import SwiftData

struct MagicInputResult {
    var title: String
    var priority: Priority = .medium
    var dueDate: Date?
    var tags: [String] = []
}

struct MagicInputParser {
    static func parse(_ text: String) -> MagicInputResult {
        var title = text
        var priority: Priority = .medium
        var dueDate: Date?
        var tags: [String] = []
        
        // 1. Parse Priority (!urgent, !high, !medium, !low)
        if title.contains("!urgent") || title.contains("!high") {
            priority = .high
            title = title.replacingOccurrences(of: "!urgent", with: "", options: .caseInsensitive)
            title = title.replacingOccurrences(of: "!high", with: "", options: .caseInsensitive)
        } else if title.contains("!medium") {
            priority = .medium
            title = title.replacingOccurrences(of: "!medium", with: "", options: .caseInsensitive)
        } else if title.contains("!low") {
            priority = .low
            title = title.replacingOccurrences(of: "!low", with: "", options: .caseInsensitive)
        }
        
        // 2. Parse Tags (#tag)
        let tagRegex = try? NSRegularExpression(pattern: "#\\w+")
        if let regex = tagRegex {
            let matches = regex.matches(in: title, range: NSRange(title.startIndex..., in: title))
            for match in matches.reversed() { // Reverse to avoid range issues when removing
                if let range = Range(match.range, in: title) {
                    let tag = String(title[range]).replacingOccurrences(of: "#", with: "")
                    tags.append(tag)
                    title.removeSubrange(range)
                }
            }
        }
        
        // 3. Parse Dates (today, tomorrow, tonight, next week)
        // Note: Simple keyword matching. Production would use NSDataDetector or NaturalLanguage
        let lowerTitle = title.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if lowerTitle.contains("today") || lowerTitle.contains("tonight") {
            dueDate = calendar.startOfDay(for: now).addingTimeInterval(18 * 3600) // Default to 6 PM
            title = replaceCaseInsensitive(title, "today")
            title = replaceCaseInsensitive(title, "tonight")
        } else if lowerTitle.contains("tomorrow") {
            if let date = calendar.date(byAdding: .day, value: 1, to: now) {
                dueDate = calendar.startOfDay(for: date).addingTimeInterval(9 * 3600) // Default to 9 AM
                title = replaceCaseInsensitive(title, "tomorrow")
            }
        } else if lowerTitle.contains("next week") {
             if let date = calendar.date(byAdding: .day, value: 7, to: now) {
                dueDate = calendar.startOfDay(for: date).addingTimeInterval(9 * 3600)
                title = replaceCaseInsensitive(title, "next week")
            }
        }
        
        // Cleanup whitespace
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            
        return MagicInputResult(title: title, priority: priority, dueDate: dueDate, tags: tags)
    }
    
    private static func replaceCaseInsensitive(_ text: String, _ needle: String) -> String {
        guard let range = text.range(of: needle, options: .caseInsensitive) else { return text }
        var newText = text
        newText.removeSubrange(range)
        return newText
    }
}
