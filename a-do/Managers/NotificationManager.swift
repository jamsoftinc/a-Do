import Foundation
import UserNotifications
import os
import Observation
import Contacts
import UIKit
import SwiftData

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            Task { @MainActor in
                self.refreshStatus()
            }
        }
    }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func reminderIdentifierPrefix(for uuidString: String) -> String {
        "reminder_\(uuidString)"
    }

    private func reminderIdentifier(for uuidString: String, leadTime: TimeInterval) -> String {
        "\(reminderIdentifierPrefix(for: uuidString))_\(Int(leadTime))"
    }

    func scheduleNotifications(for reminder: Reminder, dueDate: Date?, leadTimes: [TimeInterval]) async {
        await scheduleNotifications(
            forIdentifier: reminder.uuid.uuidString,
            dueDate: dueDate,
            leadTimes: leadTimes,
            title: reminder.title,
            reminder: reminder
        )
    }

    func rescheduleNotifications(for reminder: Reminder, dueDate: Date?, leadTimes: [TimeInterval]) async {
        cancelNotifications(for: reminder)
        await scheduleNotifications(for: reminder, dueDate: dueDate, leadTimes: leadTimes)
    }

    func scheduleNotifications(forReminderUUID reminderUUID: UUID, dueDate: Date?, leadTimes: [TimeInterval], title: String) async {
        await scheduleNotifications(
            forIdentifier: reminderUUID.uuidString,
            dueDate: dueDate,
            leadTimes: leadTimes,
            title: title,
            reminder: nil
        )
    }

    func scheduleNotifications(for reminderId: PersistentIdentifier, dueDate: Date?, leadTimes: [TimeInterval], title: String) async {
        await scheduleNotifications(
            forIdentifier: String(describing: reminderId),
            dueDate: dueDate,
            leadTimes: leadTimes,
            title: title,
            reminder: nil
        )
    }

    private func scheduleNotifications(
        forIdentifier identifier: String,
        dueDate: Date?,
        leadTimes: [TimeInterval],
        title: String,
        reminder: Reminder?
    ) async {
        guard let dueDate else { return }
        let center = UNUserNotificationCenter.current()
        
        // Register categories once
        let sendAction = UNNotificationAction(identifier: "SEND_TEXT_ACTION", title: "Send Text", options: [.foreground])
        let category = UNNotificationCategory(identifier: "REMEMBER_CATEGORY", actions: [sendAction], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])

        let normalizedLeadTimes = leadTimes.isEmpty ? [0] : Array(Set(leadTimes.filter { $0 >= 0 })).sorted()
        let coachingPlan = await notificationCoachPlan(
            reminder: reminder,
            dueDate: dueDate,
            fallbackTitle: title,
            fallbackLeadTimes: normalizedLeadTimes
        )
        let finalTitle = coachingPlan?.title ?? "Reminder: \(title)"
        let finalBody = coachingPlan?.body ?? "It's time for \(title)."
        let coachedLeadTimes = (coachingPlan?.leadTimesMinutes ?? []).map { TimeInterval($0 * 60) }
        let finalLeadTimes = coachedLeadTimes.isEmpty ? normalizedLeadTimes : coachedLeadTimes

        for lead in finalLeadTimes {
            let triggerDate = dueDate.addingTimeInterval(-lead)
            if triggerDate < Date() { continue }
            let content = UNMutableNotificationContent()
            content.title = finalTitle
            content.body = finalBody
            content.sound = .default
            content.categoryIdentifier = "REMEMBER_CATEGORY"
            content.userInfo = ["reminderIdentifier": identifier]
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate), repeats: false)
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(for: identifier, leadTime: lead),
                content: content,
                trigger: trigger
            )
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                center.add(request) { error in
                    if let error {
                        Logger(subsystem: "a-do", category: "Notifications").error("Failed to schedule notification: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func notificationCoachPlan(
        reminder: Reminder?,
        dueDate: Date,
        fallbackTitle: String,
        fallbackLeadTimes: [TimeInterval]
    ) async -> AINotificationCoachPlan? {
        guard let reminder else { return nil }
        guard EntitlementManager.shared.isProUser else { return nil }

        let plan = await AIManager.shared.coachReminderNotification(
            reminder: reminder,
            dueDate: dueDate,
            defaultLeadTimes: fallbackLeadTimes
        )

        if plan == nil {
            Logger(subsystem: "a-do", category: "Notifications").debug("Notification coach unavailable, using default delivery")
        }

        // Ensure title is never empty.
        if var plan = plan {
            let trimmedTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty {
                plan.title = "Reminder: \(fallbackTitle)"
            }
            return plan
        }

        return nil
    }

    func cancelNotifications(for reminderId: PersistentIdentifier) {
        let identifier = String(describing: reminderId)
        cancelNotifications(forIdentifier: identifier)
    }

    func cancelNotifications(for reminder: Reminder) {
        cancelNotifications(forIdentifier: reminder.uuid.uuidString)
    }

    private func cancelNotifications(forIdentifier identifier: String) {
        let prefix = reminderIdentifierPrefix(for: identifier)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func fireNow(title: String, body: String? = nil, id: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        content.sound = .default
        // Quick action to send text if applicable
        let sendAction = UNNotificationAction(identifier: "SEND_TEXT_ACTION", title: "Send Text", options: [.foreground])
        let category = UNNotificationCategory(identifier: "REMEMBER_CATEGORY", actions: [sendAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "REMEMBER_CATEGORY"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { Logger(subsystem: "a-do", category: "Notifications").error("Fire now failed: \(String(describing: error))") }
        }
    }

    // Compose and open an SMS to a set of phone numbers with the given message body
    func composeSMS(to recipients: [String], body: String) {
        guard !recipients.isEmpty else { return }
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let joined = recipients.joined(separator: ",")
        if let url = URL(string: "sms:\(joined)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Reminder-based Notifications

    /// Schedule a notification for a reminder at a specific date
    func scheduleNotification(for reminder: Reminder, at date: Date) async {
        await scheduleNotifications(for: reminder, dueDate: date, leadTimes: [0])
    }

    /// Cancel all notifications for a reminder
    func cancelNotification(for reminder: Reminder) {
        cancelNotifications(for: reminder)
        Logger(subsystem: "a-do", category: "Notifications").info("Cancelled notifications for '\(reminder.title)'")
    }
}
