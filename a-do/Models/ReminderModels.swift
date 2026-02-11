import Foundation
import SwiftData

// MARK: - Enums
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

enum EnergyLevel: Int, Codable, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .low: return "Low Energy"
        case .medium: return "Medium Energy"
        case .high: return "High Energy"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .high: return "battery.100"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#34C759" // Green
        case .medium: return "#FF9500" // Orange
        case .high: return "#FF3B30" // Red
        }
    }
}

enum LocationTriggerType: String, Codable, CaseIterable, Identifiable {
    case onArrival
    case onDeparture
    var id: String { rawValue }
}

// MARK: - Smart List Rules
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

// MARK: - Data Models
@Model
final class ListSection {
    var name: String = ""
    var order: Int = 0
    var colorHex: String = "#7C4DFF"
    
    @Relationship(deleteRule: .nullify) var lists: [ReminderList]? = []
    
    
    init(name: String, order: Int = 0, colorHex: String = "#7C4DFF") {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.order = max(0, order)
        self.colorHex = Self.validateColorHex(colorHex)
    }
    
    // MARK: - Validation
    private static func validateColorHex(_ hex: String) -> String {
        return SecurityUtils.validateHexColor(hex)
    }
}

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#7C4DFF"
    @Relationship var reminders: [Reminder]? = []
    @Relationship var habits: [Habit]? = []
    

    init(name: String, colorHex: String = "#7C4DFF") {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorHex = Self.validateColorHex(colorHex)
    }
    
    // MARK: - Validation
    private static func validateColorHex(_ hex: String) -> String {
        return SecurityUtils.validateHexColor(hex)
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
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validate and clamp coordinates to valid ranges
        self.latitude = max(-90, min(90, latitude))
        self.longitude = max(-180, min(180, longitude))
        self.radius = max(10, min(10000, radius)) // Reasonable radius limits
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

    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    @Relationship(deleteRule: .nullify) var recurringReminder: RecurringReminder?
    @Relationship(deleteRule: .nullify) var reminderTemplate: ReminderTemplate?
    

    init(leadTimeSeconds: TimeInterval, customSoundName: String? = nil) {
        self.leadTimeSeconds = max(0, leadTimeSeconds) // Ensure non-negative
        self.customSoundName = customSoundName?.trimmingCharacters(in: .whitespacesAndNewlines)
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
        self.identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.givenName = givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.familyName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var displayName: String {
        let names = [givenName, familyName].filter { !$0.isEmpty }
        return names.isEmpty ? "Unknown Contact" : names.joined(separator: " ")
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
        self.noteIdentifier = noteIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.noteTitle = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.noteContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastModified = lastModified
    }
}

@Model
final class ReminderList {
    var name: String = ""
    var isSmart: Bool = false
    var isProtected: Bool = false
    var encodedSmartRules: Data?
    var order: Int = 0

    @Relationship(deleteRule: .cascade) var reminders: [Reminder]?
    @Relationship(inverse: \ListSection.lists) var section: ListSection?
    @Relationship(deleteRule: .cascade) var sharedLists: [SharedList]?
    

    init(name: String, isSmart: Bool = false, isProtected: Bool = false, rules: [SmartListRule]? = nil, reminders: [Reminder] = []) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isSmart = isSmart
        self.isProtected = isProtected
        if let rules { 
            self.encodedSmartRules = try? JSONEncoder().encode(rules) 
        }
        self.reminders = reminders.isEmpty ? nil : reminders
    }

    var rules: [SmartListRule] {
        guard isSmart, let encodedSmartRules, let rules = try? JSONDecoder().decode([SmartListRule].self, from: encodedSmartRules) else { 
            return [] 
        }
        return rules
    }
    
    var reminderCount: Int {
        return reminders?.count ?? 0
    }
    
    var completedCount: Int {
        return reminders?.filter { $0.isCompleted }.count ?? 0
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
    // Apple Reminders sync
    var appleReminderID: String?
    // Messaging preferences
    var autoTextTaggedContacts: Bool = false
    var autoTextMe: Bool = false
    // Calendar tracking
    var calendarInviteCreated: Bool = false
    var calendarEventID: String? // ID of created calendar event for blocking

    // Snooze tracking
    var snoozeCount: Int? = 0
    var lastSnoozedAt: Date?
    
    // Contextual Priority
    var energyLevelRaw: Int = 2 // Default to medium. Using Int for SwiftData storage.

    @Relationship(deleteRule: .nullify) var tags: [Tag]?
    @Relationship(deleteRule: .cascade) var notifications: [ReminderNotification]? = []
    @Relationship(deleteRule: .cascade) var locationTrigger: LocationTrigger?
    @Relationship(deleteRule: .cascade) var taggedContacts: [TaggedContact]? = []
    @Relationship(deleteRule: .cascade) var appleNote: AppleNoteAttachment?
    @Relationship(deleteRule: .cascade) var voiceReminder: VoiceReminder?
    @Relationship(deleteRule: .nullify, inverse: \ReminderList.reminders) var list: ReminderList?
    @Relationship(deleteRule: .cascade) var timeEntries: [TimeEntry]? = []
    @Relationship(deleteRule: .cascade) var sharedReminders: [SharedReminder]?
    
    @Relationship(inverse: \FocusSession.focusedReminders) var focusSessions: [FocusSession]?
    @Relationship(inverse: \FocusSession.completedReminders) var completedFocusSessions: [FocusSession]?
    @Relationship(inverse: \HealthMetric.reminder) var healthMetrics: [HealthMetric]?
    @Relationship(inverse: \HealthGoal.reminders) var healthGoals: [HealthGoal]?
    @Relationship(inverse: \WorkoutIntegration.reminders) var workoutIntegrations: [WorkoutIntegration]?
    @Relationship(inverse: \SleepIntegration.reminders) var sleepIntegrations: [SleepIntegration]?
    @Relationship(inverse: \MindfulnessIntegration.reminders) var mindfulnessIntegrations: [MindfulnessIntegration]?
    @Relationship(deleteRule: .nullify) var smartNotifications: [SmartNotification]? = []
    @Relationship(deleteRule: .nullify) var reminderComments: [ReminderComment]? = []
    @Relationship(deleteRule: .nullify) var aiSuggestions: [AISuggestion]? = []
    @Relationship(deleteRule: .nullify, inverse: \RecurringReminder.generatedReminders) var recurringReminder: RecurringReminder?
    
    // Pro features
    @Relationship(deleteRule: .cascade) var subtasks: [Subtask]?
    @Relationship(deleteRule: .cascade) var dependencies: [TaskDependency]?
    @Relationship(deleteRule: .cascade) var sketches: [Sketch]?
    @Relationship(deleteRule: .nullify) var blockingTasks: [TaskDependency]?

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

        energyLevel: EnergyLevel = .medium,
        uuid: UUID = UUID(),
        calendarInviteCreated: Bool = false
    ) {
        self.uuid = uuid
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
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

        self.energyLevelRaw = energyLevel.rawValue
        self.calendarInviteCreated = calendarInviteCreated
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
    
    var energyLevel: EnergyLevel {
        get { EnergyLevel(rawValue: energyLevelRaw) ?? .medium }
        set { energyLevelRaw = newValue.rawValue }
    }
    
    // Check if completed reminder should be automatically deleted (older than 30 days)
    var shouldAutoDelete: Bool {
        guard isCompleted, let completedAt = completedAt else { return false }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return completedAt < thirtyDaysAgo
    }
    
    // MARK: - Computed Properties
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    var daysUntilDue: Int? {
        guard let dueDate = dueDate, !isCompleted else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dueDate)
        return components.day
    }
    
    var tagNames: [String] {
        return tags?.map { $0.name } ?? []
    }
    
    var hasLocationTrigger: Bool {
        return locationTrigger != nil
    }
    
    var hasVoiceReminder: Bool {
        return voiceReminder != nil
    }
}

@Model
final class VoiceReminder {
    var audioFileName: String = ""
    var transcribedText: String = ""
    var recordingDuration: TimeInterval = 0
    var createdAt: Date = Date()
    
    // Inverse relationships for CloudKit compatibility
    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    
    init(audioFileName: String, transcribedText: String, recordingDuration: TimeInterval) {
        self.audioFileName = SecurityUtils.sanitizeFileName(audioFileName)
        self.transcribedText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recordingDuration = max(0, recordingDuration)
        self.createdAt = Date()
    }
    
    // Computed property to get the full audio file URL
    var audioFileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(audioFileName)
    }
    
    var hasAudioFile: Bool {
        guard let url = audioFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

// MARK: - Extensions
extension ReminderList {
    static func defaultSmartLists() -> [ReminderList] {
        let today = ReminderList(
            name: "Today",
            isSmart: true,
            isProtected: true,
            rules: [SmartListRule(type: .dueToday, priority: nil, tagName: nil)]
        )
        
        let overdue = ReminderList(
            name: "Overdue",
            isSmart: true,
            isProtected: true,
            rules: [SmartListRule(type: .overdue, priority: nil, tagName: nil)]
        )
        
        let highPriority = ReminderList(
            name: "High Priority",
            isSmart: true,
            isProtected: true,
            rules: [SmartListRule(type: .priority, priority: .high, tagName: nil)]
        )
        
        return [today, overdue, highPriority]
    }
}

extension Tag {
    static let defaultColors: [String] = [
        "#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF", "#845EC2", "#FFC75F"
    ]
    
    static func randomColor() -> String {
        return defaultColors.randomElement() ?? "#7C4DFF"
    }
}
