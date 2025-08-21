import AppIntents
import SwiftData
import Combine

struct AddQuickReminder: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Reminder"
    static var description = IntentDescription("Creates a reminder with a title and optional due time")

    @Parameter(title: "Title") var reminderTitle: String
    @Parameter(title: "Due In Minutes", default: 0) var dueInMinutes: Int

    func perform() async throws -> some ProvidesDialog {
        // Create container directly using SwiftData
        let container = await MainActor.run {
            let schema = Schema([
                Reminder.self,
                Tag.self,
                ReminderList.self,
                ReminderNotification.self,
                LocationTrigger.self,
                ListSection.self,
                TaggedContact.self,
                AppleNoteAttachment.self
            ])
            
            do {
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: memoryConfig)
            }
        }
        let context = ModelContext(container)
        let due: Date? = dueInMinutes > 0 ? Date().addingTimeInterval(Double(dueInMinutes) * 60) : nil
        let reminder = Reminder(title: reminderTitle, dueDate: due)
        context.insert(reminder)
        try? context.save()
        // Schedule notifications on MainActor to ensure thread safety
        let reminderId = reminder.id
        let reminderTitleCopy = reminderTitle
        let dueCopy = due
        _ = await MainActor.run {
            Task { [reminderId, dueCopy, reminderTitleCopy] in
                await NotificationManager.shared.scheduleNotifications(for: reminderId, dueDate: dueCopy, leadTimes: [], title: reminderTitleCopy)
            }
        }
        return .result(dialog: "Added reminder: \(reminderTitle)")
    }
}

struct OpenTodayList: AppIntent {
    static var title: LocalizedStringResource = "Open Today List"
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.JAMSoft.a-do")
        defaults?.set(true, forKey: "deeplink_open_today")
        return .result()
    }
}

struct SendTextForReminder: AppIntent {
    static var title: LocalizedStringResource = "Send Text For Reminder"
    static var description = IntentDescription("Open the app to send a text for the specified reminder")

    @Parameter(title: "Reminder ID") var reminderId: String

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: reminderId) else { return .result(dialog: "Invalid UUID.") }
        // Set a flag for the app to check when it opens
        let defaults = UserDefaults(suiteName: "group.JAMSoft.a-do")
        defaults?.set(uuid.uuidString, forKey: "deeplink_send_text_reminder_id")
        // Bring the app to foreground if supported (iOS 26+)
        if #available(iOS 26.0, *) {
            try await continueInForeground(alwaysConfirm: false)
        } else {
            return .result(dialog: "Bringing the app to foreground requires iOS 26.0 or newer.")
        }
        return .result(dialog: "Action completed.")
    }
}
