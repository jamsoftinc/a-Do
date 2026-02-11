import Foundation
import SwiftData
import os

enum StartupSmokeChecks {
    private static let logger = Logger(subsystem: "a-do", category: "SmokeChecks")

    @MainActor
    static func run(container: ModelContainer) {
        #if DEBUG
        let context = ModelContext(container)

        let reminderCount = (try? context.fetch(FetchDescriptor<Reminder>()).count) ?? 0
        let habitCount = (try? context.fetch(FetchDescriptor<Habit>()).count) ?? 0
        let settingsCount = (try? context.fetch(FetchDescriptor<AppSettings>()).count) ?? 0
        let tags = ReminderCreationService.shared.extractHashtagNames(from: "Email #work and #health")

        assert(tags.contains("work"))
        assert(tags.contains("health"))

        logger.info("Smoke check passed - reminders: \(reminderCount), habits: \(habitCount), settings: \(settingsCount)")
        #endif
    }
}
