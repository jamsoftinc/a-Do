import Foundation
import SwiftData
import SwiftUI
import Observation

enum DeepLinkDestination: Identifiable, Equatable {
    case smartToday
    case smartHighPriority
    case tag(String)
    case priority(Priority)
    case sendText(reminderId: UUID)

    var id: String {
        switch self {
        case .smartToday: return "smart_today"
        case .smartHighPriority: return "smart_high"
        case .tag(let name): return "tag_\(name)"
        case .priority(let p): return "priority_\(p.rawValue)"
        case .sendText(let id): return "send_text_\(id.uuidString)"
        }
    }
}

@Observable
final class AppRouter {
    var destination: DeepLinkDestination?

    func handle(url: URL) {
        guard url.scheme == "a-do" else { return }
        let path = url.path.lowercased()
        if path.hasPrefix("/smart/today") {
            destination = .smartToday
        } else if path.hasPrefix("/smart/high") {
            destination = .smartHighPriority
        } else if path.hasPrefix("/sendtext/") {
            let idStr = String(path.dropFirst("/sendtext/".count))
            if let id = UUID(uuidString: idStr) { destination = .sendText(reminderId: id) }
        } else if path.hasPrefix("/tag/") {
            let tagName = String(path.dropFirst("/tag/".count))
            destination = .tag(tagName)
        } else if path.hasPrefix("/priority/") {
            let value = String(path.dropFirst("/priority/".count))
            if value == "high" { destination = .priority(.high) }
            else if value == "medium" { destination = .priority(.medium) }
            else if value == "low" { destination = .priority(.low) }
        }
    }

    func checkGroupDeeplinkFlag() {
        let defaults = UserDefaults(suiteName: "group.JAMSoft.a-do")
        if defaults?.bool(forKey: "deeplink_open_today") == true {
            defaults?.set(false, forKey: "deeplink_open_today")
            destination = .smartToday
        }
        // Check for send text reminder deep link
        if let reminderIdString = defaults?.string(forKey: "deeplink_send_text_reminder_id"),
           let reminderId = UUID(uuidString: reminderIdString) {
            defaults?.removeObject(forKey: "deeplink_send_text_reminder_id")
            destination = .sendText(reminderId: reminderId)
        }
    }
}


