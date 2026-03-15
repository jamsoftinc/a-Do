//
//  NaturalLanguageProcessor.swift
//  a-do
//
//  Advanced natural language processing for iOS 26
//

import Foundation
import NaturalLanguage
import Observation
import os

@MainActor
@Observable
final class NaturalLanguageProcessor {
    static let shared = NaturalLanguageProcessor()
    
    private let logger = Logger(subsystem: "a-do", category: "NLP")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseAdvancedNLP
    }
    
    private init() {}
    
    // MARK: - Main Processing
    
    func parseReminderText(_ text: String) async -> ParsedReminder {
        guard isProEnabled else {
            logger.warning("Advanced NLP is a Pro feature")
            return ParsedReminder(baseText: text)
        }
        
        logger.info("Parsing reminder text with advanced NLP: \(text)")

        var results = ParsedReminder(baseText: text)
        
        // Extract entities using Natural Language framework
        await extractEntities(from: text, into: &results)

        // Extract dates and times
        await extractDates(from: text, into: &results)

        // Extract priorities
        extractPriorities(from: text, into: &results)

        // Extract tags
        extractTags(from: text, into: &results)

        // Extract locations
        await extractLocations(from: text, into: &results)

        // Extract contacts
        extractContacts(from: text, into: &results)
        
        // Clean up final text
        results.cleanFinalText()
        
        logger.info("Parsing complete: title=\(results.title ?? "none"), dueDate=\(results.dueDate?.description ?? "none")")
        
        return results
    }
    
    // MARK: - Entity Extraction
    
    private func extractEntities(from text: String, into results: inout ParsedReminder) async {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        let range = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            // Find action words
            if tag == .verb, ["call", "buy", "pick", "meet", "send", "email", "read", "write"].contains(word.lowercased()) {
                results.actionWords.append(word)
            }
            
            return true
        }
    }
    
    // MARK: - Date and Time Extraction
    
    private func extractDates(from text: String, into results: inout ParsedReminder) async {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            if let date = match.date {
                // Determine if this is the main due date
                if results.dueDate == nil {
                    results.dueDate = date

                    // Check if there's context about when
                    let context = getSurroundingContext(in: text, around: match.range)
                    results.dueDateContext = context
                }
            }
        }
        
        // Parse relative dates
        await parseRelativeDates(from: text, into: &results)
    }
    
    private func parseRelativeDates(from text: String, into results: inout ParsedReminder) async {
        let calendar = Calendar.current
        let lowercaseText = text.lowercased()
        
        // Today
        if lowercaseText.contains("today") || lowercaseText.contains("tonight") {
            results.dueDate = calendar.startOfDay(for: Date())
            if lowercaseText.contains("tonight") {
                var components = DateComponents()
                components.hour = 19
                components.minute = 0
                results.dueDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date())
            }
            return
        }
        
        // Tomorrow
        if lowercaseText.contains("tomorrow") {
            results.dueDate = calendar.date(byAdding: .day, value: 1, to: Date())
            return
        }
        
        // Day names
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in dayNames.enumerated() {
            if lowercaseText.contains(day) {
                results.dueDate = findNextWeekday(index, in: calendar)
                return
            }
        }
        
        // Relative days
        if lowercaseText.contains("next monday") || lowercaseText.contains("this monday") {
            results.dueDate = findNextWeekday(1, in: calendar)
        } else if lowercaseText.contains("next week") {
            results.dueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
        } else if lowercaseText.contains("next month") {
            results.dueDate = calendar.date(byAdding: .month, value: 1, to: Date())
        }
        
        // "In X days/weeks/months"
        if let match = lowercaseText.range(of: #"\bin\s+(\d+)\s+(day|week|month)"#, options: .regularExpression) {
            let numbers = text[match].components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if let amount = numbers.first {
                if lowercaseText.contains("week") {
                    results.dueDate = calendar.date(byAdding: .weekOfYear, value: amount, to: Date())
                } else if lowercaseText.contains("month") {
                    results.dueDate = calendar.date(byAdding: .month, value: amount, to: Date())
                } else {
                    results.dueDate = calendar.date(byAdding: .day, value: amount, to: Date())
                }
            }
        }
    }
    
    private func findNextWeekday(_ weekday: Int, in calendar: Calendar) -> Date? {
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        var daysToAdd = weekday - currentWeekday + 7
        if currentWeekday >= weekday {
            daysToAdd -= 7 // Already passed this week
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today)
    }
    
    // MARK: - Priority Extraction
    
    private func extractPriorities(from text: String, into results: inout ParsedReminder) {
        let lowercaseText = text.lowercased()
        
        // High priority indicators
        if lowercaseText.contains("!high") || 
           lowercaseText.contains("urgent") || 
           lowercaseText.contains("important") ||
           lowercaseText.contains("asap") ||
           lowercaseText.contains("priority") {
            results.priority = .high
        }
        // Low priority indicators
        else if lowercaseText.contains("!low") || 
                lowercaseText.contains("eventually") ||
                lowercaseText.contains("someday") {
            results.priority = .low
        }
        // Medium priority
        else if lowercaseText.contains("!medium") ||
                lowercaseText.contains("normal") {
            results.priority = .medium
        }
    }
    
    // MARK: - Tag Extraction
    
    private func extractTags(from text: String, into results: inout ParsedReminder) {
        let tagPattern = #"#(\w+)"#
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [])
        let matches = regex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
        
        for match in matches {
            if match.numberOfRanges > 1,
               let tagRange = Range(match.range(at: 1), in: text) {
                let tag = String(text[tagRange])
                results.tags.append(tag)
            }
        }
    }
    
    // MARK: - Location Extraction
    
    private func extractLocations(from text: String, into results: inout ParsedReminder) async {
        let locationKeywords = [
            "at the", "near", "in", "to", "from",
            "grocery store", "supermarket", "gas station", "coffee shop",
            "office", "home", "work", "gym", "school"
        ]
        
        let lowercaseText = text.lowercased()
        
        for keyword in locationKeywords {
            if lowercaseText.contains(keyword) {
                let range = (lowercaseText as NSString).range(of: keyword)
                if range.location != NSNotFound {
                    let context = getSurroundingContext(in: text, around: range)
                    results.location = extractLocationName(from: context)
                    return
                }
            }
        }
    }
    
    private func extractLocationName(from context: String) -> String {
        // Simple extraction - could be enhanced with CoreLocation
        let components = context.components(separatedBy: " ")
        if components.count > 0, let lastWord = components.last {
            return lastWord.capitalized
        }
        return context
    }
    
    // MARK: - Contact Extraction
    
    private func extractContacts(from text: String, into results: inout ParsedReminder) {
        let contactKeywords = ["call", "text", "email", "meet"]
        let lowercaseText = text.lowercased()
        
        for keyword in contactKeywords {
            if lowercaseText.contains(keyword) {
                // Find the next proper noun (likely person's name)
                let tagger = NLTagger(tagSchemes: [.nameType])
                tagger.string = text
                
                let range = text.startIndex..<text.endIndex
                tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
                    if tag == .personalName {
                        let name = String(text[tokenRange])
                        results.contacts.append(name)
                        return false // Stop after first name
                    }
                    return true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSurroundingContext(in text: String, around range: NSRange) -> String {
        let start = max(0, range.location - 10)
        let length = min(text.count - start, range.length + 20)
        let contextRange = NSRange(location: start, length: length)
        
        if contextRange.location < text.count, contextRange.location + contextRange.length <= text.count {
            if let swiftRange = Range(contextRange, in: text) {
                return String(text[swiftRange])
            }
        }
        
        return ""
    }
}

// MARK: - Parsed Reminder Result

struct ParsedReminder {
    let baseText: String
    var title: String?
    var dueDate: Date?
    var dueDateContext: String?
    var priority: Priority = .none
    var tags: [String] = []
    var location: String?
    var contacts: [String] = []
    var actionWords: [String] = []
    
    var finalText: String {
        return title ?? baseText
    }
    
    mutating func cleanFinalText() {
        var cleanedText = baseText
        
        // Remove tags
        for tag in tags {
            cleanedText = cleanedText.replacingOccurrences(of: "#\(tag)", with: "", options: .caseInsensitive)
        }
        
        // Remove priority markers
        cleanedText = cleanedText.replacingOccurrences(of: "!high", with: "", options: .caseInsensitive)
        cleanedText = cleanedText.replacingOccurrences(of: "!low", with: "", options: .caseInsensitive)
        cleanedText = cleanedText.replacingOccurrences(of: "!medium", with: "", options: .caseInsensitive)
        
        // Trim whitespace
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedText = cleanedText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        title = cleanedText.isEmpty ? baseText : cleanedText
    }
    
    var hasEnrichedData: Bool {
        return dueDate != nil || priority != .none || !tags.isEmpty || location != nil || !contacts.isEmpty
    }
}
