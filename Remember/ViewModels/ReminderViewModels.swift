import Foundation
import SwiftData
import os
import Observation

@MainActor
@Observable
final class ReminderHomeViewModel {
    var quickTitle: String = ""

    func addQuickReminder(context: ModelContext) {
        let safeTitle = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeTitle.isEmpty else { return }
        let reminder = Reminder(title: safeTitle)
        context.insert(reminder)
        do { try context.save() } catch { Logger(subsystem: "Remember", category: "Reminders").error("Quick add failed: \(String(describing: error))") }
        quickTitle = ""
    }
}

@MainActor
@Observable
final class ReminderFormViewModel {
    var title: String = ""
    var details: String = ""
    var dueDate: Date? = nil
    var priority: Priority = .none
    var selectedTags: [Tag] = []
    var leadTimes: [TimeInterval] = []
    var locationLabel: String = ""
    var locationLatitude: Double = 0
    var locationLongitude: Double = 0
    var locationRadius: Double = 150
    var locationType: LocationTriggerType = .onArrival

    @discardableResult
    func save(context: ModelContext, existing: Reminder? = nil) -> Reminder {
        let target = existing ?? Reminder(title: title)
        target.title = title
        target.details = details.isEmpty ? nil : details
        target.dueDate = dueDate
        target.priority = priority
        target.tags = Array(selectedTags)
        target.notifications = leadTimes.isEmpty ? [] : leadTimes.map { ReminderNotification(leadTimeSeconds: $0) }
        if !locationLabel.isEmpty {
            target.locationTrigger = LocationTrigger(label: locationLabel, latitude: locationLatitude, longitude: locationLongitude, radius: locationRadius, type: locationType)
        }
        if existing == nil { context.insert(target) }
        do { try context.save() } catch { Logger(subsystem: "Remember", category: "Reminders").error("Save failed: \(String(describing: error))") }
        return target
    }
}

