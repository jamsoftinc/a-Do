import Foundation
import SwiftData
import SwiftUI
import os

enum SmartListEngine {
    static func ensureDefaultSmartLists(context: ModelContext) {
        let descriptor = FetchDescriptor<ReminderList>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let names = Set(existing.filter { $0.isSmart }.map { $0.name })
        let defaults = ReminderList.defaultSmartLists().filter { !names.contains($0.name) }
        for list in defaults { context.insert(list) }
        if !defaults.isEmpty {
            do { try context.save() } catch { Logger(subsystem: "a-do", category: "SmartLists").error("Seed failed: \(String(describing: error))") }
        }
    }

    static func reminders(for list: ReminderList, from all: [Reminder]) -> [Reminder] {
        guard list.isSmart else { return list.reminders ?? [] }

        // If no rules defined, return empty (don't show all items)
        guard !list.rules.isEmpty else { return [] }

        var candidates = all
        for rule in list.rules {
            switch rule.type {
            case .dueToday:
                let start = Calendar.current.startOfDay(for: Date())
                guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
                    continue
                }
                candidates = candidates.filter { rem in
                    guard let due = rem.dueDate else { return false }
                    return due >= start && due < end
                }
            case .overdue:
                let now = Date()
                candidates = candidates.filter { rem in
                    if let due = rem.dueDate { return due < now && !rem.isCompleted }
                    return false
                }
            case .priority:
                let p = rule.priority ?? .high
                candidates = candidates.filter { $0.priority == p }
            case .tag:
                if let tagName = rule.tagName, !tagName.isEmpty {
                    candidates = candidates.filter { reminder in
                        guard let tags = reminder.tags, !tags.isEmpty else { return false }
                        return tags.contains(where: { $0.name.lowercased() == tagName.lowercased() })
                    }
                } else {
                    // If no valid tag name, return empty results (don't show all items)
                    candidates = []
                }
            }
        }
        return candidates.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
}


