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
    case habits
    case aiSuggestions
    case aiInsights
    case aiSettings

    var id: String {
        switch self {
        case .smartToday: return "smart_today"
        case .smartHighPriority: return "smart_high"
        case .tag(let name): return "tag_\(name)"
        case .priority(let p): return "priority_\(p.rawValue)"
        case .sendText(let id): return "send_text_\(id.uuidString)"
        case .habits: return "habits"
        case .aiSuggestions: return "ai_suggestions"
        case .aiInsights: return "ai_insights"
        case .aiSettings: return "ai_settings"
        }
    }
}

extension Notification.Name {
    static let appNavigateHome = Notification.Name("appNavigateHome")
}

@MainActor
@Observable
final class AppRouter {
    var destination: DeepLinkDestination?

    func handle(url: URL) {
        guard url.scheme == "a-do" else { 
            // Handle Notes app callbacks
            if url.scheme == "mobilenotes" {
                Task { @MainActor in
                    _ = RealNotesManager.shared.handleNotesURL(url)
                }
            }
            return 
        }
        
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
        } else if path.hasPrefix("/notes/") {
            // Handle Notes-related deep links
            Task { @MainActor in
                _ = RealNotesManager.shared.handleNotesURL(url)
            }
        } else if path.hasPrefix("/habits") {
            destination = .habits
        } else if path.hasPrefix("/ai/suggestions") {
            destination = .aiSuggestions
        } else if path.hasPrefix("/ai/insights") {
            destination = .aiInsights
        } else if path.hasPrefix("/ai/settings") {
            destination = .aiSettings
        }
    }

    func checkGroupDeeplinkFlag() {
        // Use the centralized AppGroupDefaults utility with extra safety
        let appDefaults = AppGroupDefaults.shared
        
        // Force use standard UserDefaults in problematic environments
        if appDefaults.forceStandardDefaults {
            // App group access disabled
        }
        
        // Check for deep link flags
        if appDefaults.bool(forKey: "deeplink_open_today") == true {
            appDefaults.set(false, forKey: "deeplink_open_today")
            destination = .smartToday
            // Opening smart today view
        }
        
        // Check for send text reminder deep link
        if let reminderIdString = appDefaults.string(forKey: "deeplink_send_text_reminder_id"),
           let reminderId = UUID(uuidString: reminderIdString) {
            appDefaults.removeObject(forKey: "deeplink_send_text_reminder_id")
            destination = .sendText(reminderId: reminderId)
            // Opening send text for reminder
        }
        
        // Check for habits deep link
        if appDefaults.bool(forKey: "deeplink_open_habits") == true {
            appDefaults.set(false, forKey: "deeplink_open_habits")
            destination = .habits
            // Opening habits view
        }
    }
}

