import Foundation
import SwiftData
import SwiftUI
import Observation

enum DeepLinkDestination: Identifiable, Equatable {
    case smartToday
    case smartHighPriority
    case tag(String)
    case priority(Priority)

    var id: String {
        switch self {
        case .smartToday: return "smart_today"
        case .smartHighPriority: return "smart_high"
        case .tag(let name): return "tag_\(name)"
        case .priority(let p): return "priority_\(p.rawValue)"
        }
    }
}

@Observable
final class AppRouter {
    var destination: DeepLinkDestination?

    func handle(url: URL) {
        guard url.scheme == "remember" else { return }
        let path = url.path.lowercased()
        if path.hasPrefix("/smart/today") {
            destination = .smartToday
        } else if path.hasPrefix("/smart/high") {
            destination = .smartHighPriority
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
        let defaults = UserDefaults(suiteName: "group.JAMSoft.Remember")
        if defaults?.bool(forKey: "deeplink_open_today") == true {
            defaults?.set(false, forKey: "deeplink_open_today")
            destination = .smartToday
        }
    }
}


