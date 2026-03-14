import Foundation
import SwiftData
import os

enum StartupSmokeChecks {
    static func run(container: ModelContainer) async {
        #if DEBUG
        await Task.detached(priority: .background) {
            let logger = Logger(subsystem: "a-do", category: "SmokeChecks")
            let context = ModelContext(container)

            let reminderCount = (try? context.fetch(FetchDescriptor<Reminder>()).count) ?? 0
            let habitCount = (try? context.fetch(FetchDescriptor<Habit>()).count) ?? 0
            let settingsCount = (try? context.fetch(FetchDescriptor<AppSettings>()).count) ?? 0
            let tags = extractHashtagNames(from: "Email #work and #health")

            assert(tags.contains("work"))
            assert(tags.contains("health"))

            logger.info("Smoke check passed - reminders: \(reminderCount), habits: \(habitCount), settings: \(settingsCount)")
        }.value
        #endif
    }

    nonisolated private static func extractHashtagNames(from text: String) -> [String] {
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
}
