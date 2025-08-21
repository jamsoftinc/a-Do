import Foundation
import UserNotifications
import os
import Observation
import Contacts
import UIKit

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

    func scheduleNotifications(for reminderId: UUID, dueDate: Date?, leadTimes: [TimeInterval], title: String) async {
        guard let dueDate else { return }
        let center = UNUserNotificationCenter.current()
        // Register categories once
        let sendAction = UNNotificationAction(identifier: "SEND_TEXT_ACTION", title: "Send Text", options: [.foreground])
        let category = UNNotificationCategory(identifier: "REMEMBER_CATEGORY", actions: [sendAction], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
        for lead in leadTimes {
            let triggerDate = dueDate.addingTimeInterval(-lead)
            if triggerDate < Date() { continue }
            let content = UNMutableNotificationContent()
            content.title = "Reminder: \(title)"
            content.sound = .default
            content.categoryIdentifier = "REMEMBER_CATEGORY"
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate), repeats: false)
            let request = UNNotificationRequest(identifier: "reminder_\(reminderId.uuidString)_\(Int(lead))", content: content, trigger: trigger)
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                center.add(request) { error in
                    if let error { Logger(subsystem: "a-do", category: "Notifications").error("Add request failed: \(String(describing: error))") }
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func cancelNotifications(for reminderId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix("reminder_\(reminderId.uuidString)") }
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
}
