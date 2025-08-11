import AppIntents
import SwiftData
import Combine

struct AddQuickReminder: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Reminder"
    static var description = IntentDescription("Creates a reminder with a title and optional due time")

    @Parameter(title: "Title") var reminderTitle: String
    @Parameter(title: "Due In Minutes", default: 0) var dueInMinutes: Int

    func perform() async throws -> some ProvidesDialog {
        let container = AppContainer.container
        let context = ModelContext(container)
        let due: Date? = dueInMinutes > 0 ? Date().addingTimeInterval(Double(dueInMinutes) * 60) : nil
        let reminder = Reminder(title: reminderTitle, dueDate: due)
        context.insert(reminder)
        try? context.save()
        NotificationManager.shared.scheduleNotifications(for: reminder.id, dueDate: due, leadTimes: [], title: reminderTitle)
        return .result(dialog: "Added reminder: \(reminderTitle)")
    }
}

struct OpenTodayList: AppIntent {
    static var title: LocalizedStringResource = "Open Today List"
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.JAMSoft.Remember")
        defaults?.set(true, forKey: "deeplink_open_today")
        return .result()
    }
}


