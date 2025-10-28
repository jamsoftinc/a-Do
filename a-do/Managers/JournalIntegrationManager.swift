//
//  JournalIntegrationManager.swift
//  a-do
//
//  Apple Journal Integration - Content Formatting and Export Support
//

import Foundation
import Observation
import os
import CoreTransferable

/// Represents a journal entry that can be shared to Apple's Journal app
struct JournalEntry: Transferable {
    let title: String
    let content: String
    let date: Date
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entry in
            """
            \(entry.title)
            
            \(DateFormatter.localizedString(from: entry.date, dateStyle: .medium, timeStyle: .none))
            
            \(entry.content)
            """
        }
    }
}

@MainActor
@Observable
final class JournalIntegrationManager {
    static let shared = JournalIntegrationManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Journal")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseJournalIntegration
    }
    
    var lastExportDate: Date?
    
    private init() {}
    
    // MARK: - Export Functions
    
    /// Creates a JournalEntry for daily accomplishments that can be used with ShareLink
    func createJournalEntry(for accomplishments: [DailyAccomplishment]) -> JournalEntry? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        guard !accomplishments.isEmpty else {
            logger.warning("No accomplishments to export")
            return nil
        }

        let title = "Daily Accomplishments - \(formatDate(Date()))"
        let content = formatJournalEntry(accomplishments)
        
        logger.info("Created journal entry for \(accomplishments.count) accomplishments")
        return JournalEntry(title: title, content: content, date: Date())
    }
    
    /// Creates a JournalEntry for focus session summary that can be used with ShareLink
    func createJournalEntry(for session: FocusSession) -> JournalEntry? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        let title = "Focus Session: \(session.name)"
        let content = formatFocusSessionSummary(session)
        
        logger.info("Created journal entry for focus session")
        return JournalEntry(title: title, content: content, date: session.startTime)
    }
    
    /// Creates a JournalEntry for weekly review that can be used with ShareLink
    func createJournalEntry(for review: WeeklyReview) -> JournalEntry? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        let title = "Weekly Review - \(formatDate(Date()))"
        let content = formatWeeklyReview(review)
        
        logger.info("Created journal entry for weekly review")
        return JournalEntry(title: title, content: content, date: Date())
    }

    /// Formats daily accomplishments for export to Journal
    /// Returns the formatted content as a string that can be shared via ShareLink or UIActivityViewController
    func getFormattedDailyAccomplishments(_ accomplishments: [DailyAccomplishment]) -> String? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        guard !accomplishments.isEmpty else {
            logger.warning("No accomplishments to export")
            return nil
        }

        let content = formatJournalEntry(accomplishments)
        logger.info("Formatted \(accomplishments.count) accomplishments for Journal export")
        return content
    }
    
    /// Legacy method - formats and prepares daily accomplishments for export
    /// Note: Content must be shared manually via the UI (ShareLink or activity controller)
    func exportDailyAccomplishments(_ accomplishments: [DailyAccomplishment]) async -> Bool {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return false
        }

        guard !accomplishments.isEmpty else {
            logger.warning("No accomplishments to export")
            return false
        }

        logger.info("Preparing \(accomplishments.count) accomplishments for Journal export...")
        
        // Content is formatted and ready to be shared via UI
        lastExportDate = Date()
        logger.info("Content prepared for Journal export - use getFormattedDailyAccomplishments() to retrieve")
        
        return true
    }
    
    /// Formats focus session summary for export to Journal
    /// Returns the formatted content as a string that can be shared via ShareLink or UIActivityViewController
    func getFormattedFocusSessionSummary(_ session: FocusSession) -> String? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        let content = formatFocusSessionSummary(session)
        logger.info("Formatted focus session summary for Journal export")
        return content
    }
    
    /// Legacy method - formats and prepares focus session summary for export
    /// Note: Content must be shared manually via the UI (ShareLink or activity controller)
    func exportFocusSessionSummary(_ session: FocusSession) async -> Bool {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return false
        }

        logger.info("Preparing focus session summary for Journal export...")
        
        // Content is formatted and ready to be shared via UI
        logger.info("Content prepared for Journal export - use getFormattedFocusSessionSummary() to retrieve")
        
        return true
    }
    
    /// Formats weekly review for export to Journal
    /// Returns the formatted content as a string that can be shared via ShareLink or UIActivityViewController
    func getFormattedWeeklyReview(_ review: WeeklyReview) -> String? {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return nil
        }

        let content = formatWeeklyReview(review)
        logger.info("Formatted weekly review for Journal export")
        return content
    }
    
    /// Legacy method - formats and prepares weekly review for export
    /// Note: Content must be shared manually via the UI (ShareLink or activity controller)
    func exportWeeklyReview(_ review: WeeklyReview) async -> Bool {
        guard isProEnabled else {
            logger.warning("Journal Integration is a Pro feature")
            return false
        }

        logger.info("Preparing weekly review for Journal export...")
        
        // Content is formatted and ready to be shared via UI
        logger.info("Content prepared for Journal export - use getFormattedWeeklyReview() to retrieve")
        
        return true
    }
    
    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatJournalEntry(_ accomplishments: [DailyAccomplishment]) -> String {
        var text = "# Daily Accomplishments\n\n"
        text += "✨ Completed \(accomplishments.count) task\(accomplishments.count == 1 ? "" : "s") today!\n\n"

        for (index, accomplishment) in accomplishments.enumerated() {
            text += "\(index + 1). ✅ \(accomplishment.title)\n"
            if !accomplishment.notes.isEmpty {
                text += "   💭 \(accomplishment.notes)\n"
            }
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            text += "   ⏰ \(timeFormatter.string(from: accomplishment.timestamp))\n"
            if index < accomplishments.count - 1 {
                text += "\n"
            }
        }

        return text
    }
    
    private func formatFocusSessionSummary(_ session: FocusSession) -> String {
        let duration = Int(session.actualDuration / 60)
        let completionRate = session.plannedDuration > 0 ? Int((session.actualDuration / session.plannedDuration) * 100) : 0

        var summary = """
        # Focus Session: \(session.name)

        🎯 Session Details:
        • Duration: \(duration) minutes
        • Planned: \(Int(session.plannedDuration / 60)) minutes
        • Completion: \(completionRate)%
        • Status: \(session.wasCompleted ? "✅ Completed" : session.wasInterrupted ? "⚠️ Interrupted" : "In Progress")

        📊 Productivity:
        • Tasks Completed: \(session.tasksCompleted)
        • Tasks Started: \(session.tasksStarted)
        • Productivity Score: \(Int(session.productivityScore))%
        """

        if session.interruptionCount > 0 {
            summary += "\n• Interruptions: \(session.interruptionCount)"
        }

        if !session.sessionDescription.isEmpty {
            summary += "\n\n📝 Notes:\n\(session.sessionDescription)"
        }

        return summary
    }
    
    private func formatWeeklyReview(_ review: WeeklyReview) -> String {
        let focusHours = Int(review.totalFocusTime / 3600)
        let focusMinutes = Int((review.totalFocusTime.truncatingRemainder(dividingBy: 3600)) / 60)

        var text = """
        # Weekly Review

        📈 This Week's Progress:

        ✅ Tasks & Reminders:
        • Completed: \(review.remindersCompleted) reminders

        🎯 Habits:
        • Maintained: \(review.habitsMaintained) habits

        ⏱ Focus Time:
        • Total: \(focusHours)h \(focusMinutes)m of deep work
        """

        if let achievement = review.achievementUnlocked {
            text += "\n\n🏆 Achievement Unlocked:\n• \(achievement)"
        }

        text += "\n\n💭 Reflection:\nWhat went well this week? What could be improved?"

        return text
    }
}

// MARK: - Supporting Types

struct DailyAccomplishment {
    let title: String
    let notes: String
    let timestamp: Date
}

struct WeeklyReview {
    let remindersCompleted: Int
    let habitsMaintained: Int
    let totalFocusTime: TimeInterval
    let achievementUnlocked: String?
}
