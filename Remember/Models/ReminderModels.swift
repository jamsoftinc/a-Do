import Foundation
import SwiftData

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#7C4DFF"
    @Relationship(inverse: \Reminder.tags) var reminders: [Reminder] = []

    init(name: String, colorHex: String = "#7C4DFF") {
        self.name = name
        self.colorHex = colorHex
    }
}

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum LocationTriggerType: String, Codable, CaseIterable, Identifiable {
    case onArrival
    case onDeparture
    var id: String { rawValue }
}

@Model
final class LocationTrigger {
    var label: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var radius: Double = 150
    var typeRaw: String = LocationTriggerType.onArrival.rawValue

    @Relationship(inverse: \Reminder.locationTrigger) var reminder: Reminder?

    init(label: String, latitude: Double, longitude: Double, radius: Double = 150.0, type: LocationTriggerType) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.typeRaw = type.rawValue
    }
    
    var type: LocationTriggerType {
        get { LocationTriggerType(rawValue: typeRaw) ?? .onArrival }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class ReminderNotification {
    var leadTimeSeconds: TimeInterval = 0
    var customSoundName: String?

    @Relationship(inverse: \Reminder.notifications) var reminder: Reminder?

    init(leadTimeSeconds: TimeInterval, customSoundName: String? = nil) {
        self.leadTimeSeconds = leadTimeSeconds
        self.customSoundName = customSoundName
    }
}

@Model
final class Reminder {
    var id: UUID = UUID()
    var title: String = ""
    var details: String?
    var dueDate: Date?
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var priorityRaw: Int = 0
    // Messaging preferences
    var autoTextTaggedContacts: Bool = false
    var autoTextMe: Bool = false

    @Relationship var tags: [Tag] = []
    @Relationship(deleteRule: .cascade) var notifications: [ReminderNotification] = []
    @Relationship(deleteRule: .cascade) var locationTrigger: LocationTrigger?
    @Relationship(deleteRule: .cascade) var taggedContacts: [TaggedContact] = []
    @Relationship(inverse: \ReminderList.reminders) var list: ReminderList?

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        isCompleted: Bool = false,
        priority: Priority = .none,
        tags: [Tag] = [],
        notifications: [ReminderNotification] = [],
        locationTrigger: LocationTrigger? = nil,
        list: ReminderList? = nil,
        autoTextTaggedContacts: Bool = false,
        autoTextMe: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.priorityRaw = priority.rawValue
        self.tags = tags
        self.notifications = notifications
        self.locationTrigger = locationTrigger
        self.list = list
        self.autoTextTaggedContacts = autoTextTaggedContacts
        self.autoTextMe = autoTextMe
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
}

struct SmartListRule: Codable, Equatable, Identifiable {
    enum RuleType: String, Codable, CaseIterable, Identifiable { 
        case priority, dueToday, overdue, tag
        
        var id: String { rawValue }
    }
    var id: UUID = UUID()
    var type: RuleType
    var priority: Priority?
    var tagName: String?
}

@Model
final class ReminderList {
    var id: UUID = UUID()
    var name: String = ""
    var isSmart: Bool = false
    var encodedSmartRules: Data?
    var order: Int = 0

    @Relationship(deleteRule: .cascade) var reminders: [Reminder] = []
    @Relationship var section: ListSection?

    init(name: String, isSmart: Bool = false, rules: [SmartListRule]? = nil, reminders: [Reminder] = []) {
        self.id = UUID()
        self.name = name
        self.isSmart = isSmart
        if let rules { self.encodedSmartRules = try? JSONEncoder().encode(rules) }
        self.reminders = reminders
    }

    var rules: [SmartListRule] {
        guard isSmart, let encodedSmartRules, let rules = try? JSONDecoder().decode([SmartListRule].self, from: encodedSmartRules) else { return [] }
        return rules
    }
}

extension ReminderList {
    static func defaultSmartLists() -> [ReminderList] {
        return [
            ReminderList(name: "Today", isSmart: true, rules: [SmartListRule(type: .dueToday)]),
            ReminderList(name: "High Priority", isSmart: true, rules: [SmartListRule(type: .priority, priority: .high)]),
            ReminderList(name: "Overdue", isSmart: true, rules: [SmartListRule(type: .overdue)])
        ]
    }
}


@Model
final class ListSection {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    var colorHex: String = "#7C4DFF"
    
    @Relationship(deleteRule: .nullify, inverse: \ReminderList.section) var lists: [ReminderList] = []
    
    init(name: String, order: Int = 0, colorHex: String = "#7C4DFF") {
        self.id = UUID()
        self.name = name
        self.order = order
        self.colorHex = colorHex
    }
}

extension Tag {
    static let defaultColors: [String] = [
        "#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF", "#845EC2", "#FFC75F"
    ]
}

@Model
final class TaggedContact {
    var identifier: String = ""
    var givenName: String = ""
    var familyName: String = ""
    var phoneNumber: String?

    @Relationship(inverse: \Reminder.taggedContacts) var reminder: Reminder?

    init(identifier: String, givenName: String, familyName: String, phoneNumber: String?) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
    }
}


