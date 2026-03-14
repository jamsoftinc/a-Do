import AppIntents
import SwiftData
import Combine

struct AddQuickReminder: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Reminder"
    static var description = IntentDescription("Creates a reminder with a title and optional due time")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title") var reminderTitle: String
    @Parameter(title: "Due In Minutes", default: 0) var dueInMinutes: Int

    func perform() async throws -> some ProvidesDialog {
        let context = try AppContainer.makeAppGroupContext()
        let due: Date? = dueInMinutes > 0 ? Date().addingTimeInterval(Double(dueInMinutes) * 60) : nil
        let requests = await AIManager.shared.buildCaptureRequests(
            from: reminderTitle,
            fallbackDueDate: due
        ).map { request in
            var request = request
            if request.dueDate == nil {
                request.dueDate = due
            }
            return request
        }

        let createdReminders = (try? await ReminderCreationService.shared.createReminders(requests: requests, in: context)) ?? []
        let createdCount = createdReminders.count

        if createdCount == 0 {
            return .result(dialog: "Failed to save reminder. Please try again.")
        }
        if createdCount == 1 {
            return .result(dialog: "Added reminder: \(createdReminders.first?.title ?? reminderTitle)")
        }
        return .result(dialog: "Added \(createdCount) reminders.")
    }
}

struct OpenTodayList: AppIntent {
    static var title: LocalizedStringResource = "Open Today List"
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult {
        // Use the centralized AppGroupDefaults utility
        await MainActor.run {
            AppGroupDefaults.shared.set(true, forKey: "deeplink_open_today")
        }
        return .result()
    }
}

struct SendTextForReminder: AppIntent {
    static var title: LocalizedStringResource = "Send Text For Reminder"
    static var description = IntentDescription("Open the app to send a text for the specified reminder")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Reminder ID") var reminderId: String

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: reminderId) else { return .result(dialog: "Invalid UUID.") }
        // Set a flag for the app to check when it opens
        await MainActor.run {
            AppGroupDefaults.shared.set(uuid.uuidString, forKey: "deeplink_send_text_reminder_id")
        }

        // For iOS versions that don't support continueInForeground, just return success
        // The app will handle the deep link when it becomes active
        return .result(dialog: "Reminder text action queued. Open the app to continue.")
    }
}

struct IncrementHabit: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as completed for today")

    @Parameter(title: "Habit Title") var habitTitle: String

    func perform() async throws -> some ProvidesDialog {
        let context = try AppContainer.makeAppGroupContext()
        
        // Find the habit by title
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                habit.title.localizedStandardContains(habitTitle)
            }
        )
        
        do {
            let habits = try context.fetch(descriptor)
            if let habit = habits.first {
                habit.incrementToday()
                try context.save()
                return .result(dialog: "Completed habit: \(habit.title)")
            } else {
                return .result(dialog: "Habit '\(habitTitle)' not found")
            }
        } catch {
            return .result(dialog: "Failed to update habit: \(error.localizedDescription)")
        }
    }
}

struct OpenHabitsView: AppIntent {
    static var title: LocalizedStringResource = "Open Habits"
    static var description = IntentDescription("Open the habits tracking view")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Set a flag for the app to open habits view
        await MainActor.run {
            AppGroupDefaults.shared.set(true, forKey: "deeplink_open_habits")
        }
        return .result()
    }
}
