import Foundation
import SwiftData

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
final class ListSection {
    var name: String = ""
    var order: Int = 0
    var colorHex: String = "#7C4DFF"
    
    @Relationship(deleteRule: .nullify, inverse: \ReminderList.section) var lists: [ReminderList]? = []
    
    init(name: String, order: Int = 0, colorHex: String = "#7C4DFF") {
        self.name = name
        self.order = order
        self.colorHex = colorHex
    }
}

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#7C4DFF"
    @Relationship var reminders: [Reminder]? = []

    init(name: String, colorHex: String = "#7C4DFF") {
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class LocationTrigger {
    var label: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var radius: Double = 150
    var typeRaw: String = LocationTriggerType.onArrival.rawValue

    @Relationship var reminder: Reminder?

    init(label: String, latitude: Double, longitude: Double, radius: Double = 150.0, type: LocationTriggerType) {
        self.label = label
        // Validate and clamp coordinates to valid ranges
        self.latitude = max(-90, min(90, latitude))
        self.longitude = max(-180, min(180, longitude))
        self.radius = radius
        self.typeRaw = type.rawValue
    }
    
    var type: LocationTriggerType {
        get { LocationTriggerType(rawValue: typeRaw) ?? .onArrival }
        set { typeRaw = newValue.rawValue }
    }
    
    var hasValidCoordinates: Bool {
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }
}

@Model
final class ReminderNotification {
    var leadTimeSeconds: TimeInterval = 0
    var customSoundName: String?

    @Relationship var reminder: Reminder?

    init(leadTimeSeconds: TimeInterval, customSoundName: String? = nil) {
        self.leadTimeSeconds = leadTimeSeconds
        self.customSoundName = customSoundName
    }
}

@Model
final class TaggedContact {
    var identifier: String = ""
    var givenName: String = ""
    var familyName: String = ""
    var phoneNumber: String?

    @Relationship var reminder: Reminder?

    init(identifier: String, givenName: String, familyName: String, phoneNumber: String?) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
    }
}

@Model
final class AppleNoteAttachment {
    var noteIdentifier: String = ""
    var noteTitle: String = ""
    var noteContent: String = ""
    var lastModified: Date = Date()
    
    @Relationship var reminder: Reminder?
    
    init(noteIdentifier: String, noteTitle: String, noteContent: String, lastModified: Date = Date()) {
        self.noteIdentifier = noteIdentifier
        self.noteTitle = noteTitle
        self.noteContent = noteContent
        self.lastModified = lastModified
    }
}

@Model
final class ReminderList {
    var name: String = ""
    var isSmart: Bool = false
    var encodedSmartRules: Data?
    var order: Int = 0

    @Relationship(deleteRule: .cascade) var reminders: [Reminder]? = []
    @Relationship var section: ListSection?

    init(name: String, isSmart: Bool = false, rules: [SmartListRule]? = nil, reminders: [Reminder] = []) {
        self.name = name
        self.isSmart = isSmart
        if let rules { self.encodedSmartRules = try? JSONEncoder().encode(rules) }
        self.reminders = reminders.isEmpty ? nil : reminders
    }

    var rules: [SmartListRule] {
        guard isSmart, let encodedSmartRules, let rules = try? JSONDecoder().decode([SmartListRule].self, from: encodedSmartRules) else { return [] }
        return rules
    }
}

@Model
final class Reminder {
    var uuid: UUID = UUID() // For deep linking and external references
    var title: String = ""
    var details: String?
    var dueDate: Date?
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date?
    var priorityRaw: Int = 0
    // Messaging preferences
    var autoTextTaggedContacts: Bool = false
    var autoTextMe: Bool = false
    // Calendar tracking
    var calendarInviteCreated: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Tag.reminders) var tags: [Tag]? = []
    @Relationship(deleteRule: .cascade, inverse: \ReminderNotification.reminder) var notifications: [ReminderNotification]? = []
    @Relationship(deleteRule: .cascade, inverse: \LocationTrigger.reminder) var locationTrigger: LocationTrigger?
    @Relationship(deleteRule: .cascade, inverse: \TaggedContact.reminder) var taggedContacts: [TaggedContact]? = []
    @Relationship(deleteRule: .cascade, inverse: \AppleNoteAttachment.reminder) var appleNote: AppleNoteAttachment?
    @Relationship(deleteRule: .cascade, inverse: \VoiceReminder.reminder) var voiceReminder: VoiceReminder?
    @Relationship(inverse: \ReminderList.reminders) var list: ReminderList?

    // Required parameterless initializer for SwiftData
    init() {
        self.uuid = UUID()
        self.title = ""
        self.createdAt = Date()
        self.priorityRaw = Priority.none.rawValue
    }
    
    init(
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        priority: Priority = .none,
        tags: [Tag] = [],
        notifications: [ReminderNotification] = [],
        locationTrigger: LocationTrigger? = nil,
        list: ReminderList? = nil,
        autoTextTaggedContacts: Bool = false,
        autoTextMe: Bool = false,
        appleNote: AppleNoteAttachment? = nil,
        voiceReminder: VoiceReminder? = nil,
        uuid: UUID = UUID(),
        calendarInviteCreated: Bool = false
    ) {
        self.uuid = uuid
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.priorityRaw = priority.rawValue
        self.tags = tags.isEmpty ? nil : tags
        self.notifications = notifications.isEmpty ? nil : notifications
        self.locationTrigger = locationTrigger
        self.list = list
        self.autoTextTaggedContacts = autoTextTaggedContacts
        self.autoTextMe = autoTextMe
        self.appleNote = appleNote
        self.voiceReminder = voiceReminder
        self.calendarInviteCreated = calendarInviteCreated
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
    
    // Check if completed reminder should be automatically deleted (older than 30 days)
    var shouldAutoDelete: Bool {
        guard isCompleted, let completedAt = completedAt else { return false }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return completedAt < thirtyDaysAgo
    }
}

@Model
final class VoiceReminder {
    var audioFileName: String = ""
    var transcribedText: String = ""
    var recordingDuration: TimeInterval = 0
    var createdAt: Date = Date()
    
    @Relationship var reminder: Reminder?
    
    init(audioFileName: String, transcribedText: String, recordingDuration: TimeInterval) {
        self.audioFileName = audioFileName
        self.transcribedText = transcribedText
        self.recordingDuration = recordingDuration
        self.createdAt = Date()
    }
    
    // Computed property to get the full audio file URL
    var audioFileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(audioFileName)
    }
}

extension ReminderList {
    static func defaultSmartLists() -> [ReminderList] {
        // Return empty array - no demo data in production
        return []
    }
}

extension Tag {
    static let defaultColors: [String] = [
        "#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF", "#845EC2", "#FFC75F"
    ]
}