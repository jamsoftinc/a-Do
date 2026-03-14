import Foundation
import SwiftData
import os

@MainActor
final class ReminderCreationService {
    static let shared = ReminderCreationService()

    private let logger = Logger(subsystem: "a-do", category: "ReminderCreation")

    enum ServiceError: LocalizedError {
        case emptyTitle

        var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Reminder title cannot be empty."
            }
        }
    }

    struct Request {
        var title: String
        var details: String?
        var dueDate: Date?
        var priority: Priority = .none
        var energyLevel: EnergyLevel = .medium
        var selectedTags: [Tag] = []
        var leadTimes: [TimeInterval] = []
        var list: ReminderList?
        var locationLabel: String?
        var locationLatitude: Double?
        var locationLongitude: Double?
        var locationRadius: Double = 150
        var locationType: LocationTriggerType = .onArrival
        var attachedNote: AppleNoteAttachment?
        var voiceReminder: VoiceReminder?
        var autoTextTaggedContacts: Bool = false
        var autoTextMe: Bool = false
        var useNaturalLanguageParsing: Bool = false
    }

    private init() {}

    @discardableResult
    func createReminder(request: Request, in context: ModelContext) async throws -> Reminder {
        guard let reminder = try await createReminders(requests: [request], in: context).first else {
            throw ServiceError.emptyTitle
        }
        return reminder
    }

    @discardableResult
    func createReminders(requests: [Request], in context: ModelContext) async throws -> [Reminder] {
        let normalizedRequests = await normalize(requests: requests)
        let validRequests = normalizedRequests.filter { !$0.title.isEmpty }
        guard !validRequests.isEmpty else { throw ServiceError.emptyTitle }

        var reminders: [Reminder] = []
        reminders.reserveCapacity(validRequests.count)

        for request in validRequests {
            let reminder = buildReminder(from: request, in: context)
            context.insert(reminder)
            reminders.append(reminder)
        }

        try context.save()

        for (reminder, request) in zip(reminders, validRequests) {
            if let dueDate = reminder.dueDate {
                await NotificationManager.shared.scheduleNotifications(
                    for: reminder,
                    dueDate: dueDate,
                    leadTimes: request.leadTimes
                )
            }

            NotificationCenter.default.post(name: NSNotification.Name("ReminderCreated"), object: reminder)
            logger.info("Created reminder: \(reminder.title, privacy: .public)")
            await AdvancedSearchManager.shared.upsertReminderIndex(for: reminder, context: context)
        }

        WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])
        return reminders
    }

    @discardableResult
    func updateReminder(_ reminder: Reminder, with request: Request, in context: ModelContext) async throws -> Reminder {
        let normalizedRequest = await normalize(request: request)
        guard !normalizedRequest.title.isEmpty else { throw ServiceError.emptyTitle }
        apply(normalizedRequest, to: reminder, in: context)
        try context.save()

        await NotificationManager.shared.rescheduleNotifications(
            for: reminder,
            dueDate: reminder.dueDate,
            leadTimes: normalizedRequest.leadTimes
        )

        NotificationCenter.default.post(name: NSNotification.Name("ReminderCreated"), object: reminder)
        await AdvancedSearchManager.shared.upsertReminderIndex(for: reminder, context: context)
        WidgetSnapshotManager.shared.refreshSnapshots(context: context, kinds: [.reminders])

        logger.info("Updated reminder: \(reminder.title, privacy: .public)")
        return reminder
    }

    func attachLeadTimeNotifications(_ leadTimes: [TimeInterval], to reminder: Reminder) {
        let uniqueLeadTimes = Array(Set(leadTimes.filter { $0 >= 0 })).sorted()
        reminder.notifications = uniqueLeadTimes.isEmpty ? nil : uniqueLeadTimes.map {
            ReminderNotification(leadTimeSeconds: $0)
        }
    }

    func attachLocation(
        label: String?,
        latitude: Double?,
        longitude: Double?,
        radius: Double,
        type: LocationTriggerType,
        to reminder: Reminder
    ) {
        guard
            let label,
            !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let latitude,
            let longitude,
            latitude >= -90, latitude <= 90,
            longitude >= -180, longitude <= 180
        else {
            reminder.locationTrigger = nil
            return
        }

        reminder.locationTrigger = LocationTrigger(
            label: label,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            type: type
        )
    }

    func resolveTags(from text: String, selectedTags: [Tag], in context: ModelContext) -> [Tag] {
        let extractedNames = extractHashtagNames(from: text)
        let descriptor = FetchDescriptor<Tag>()
        let existingTags = (try? context.fetch(descriptor)) ?? []

        var finalTags = Dictionary(uniqueKeysWithValues: selectedTags.map { ($0.name.lowercased(), $0) })
        for tagName in extractedNames {
            if let existing = existingTags.first(where: { $0.name.lowercased() == tagName.lowercased() }) {
                finalTags[tagName.lowercased()] = existing
            } else {
                let newTag = Tag(name: tagName)
                context.insert(newTag)
                finalTags[tagName.lowercased()] = newTag
            }
        }

        return Array(finalTags.values)
    }

    func extractHashtagNames(from text: String) -> [String] {
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func normalize(request: Request) async -> Request {
        var normalized = request
        let safeTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.title = safeTitle

        guard request.useNaturalLanguageParsing, !safeTitle.isEmpty else {
            return normalized
        }

        if EntitlementManager.shared.canUseAdvancedNLP {
            let parsed = await NaturalLanguageProcessor.shared.parseReminderText(safeTitle)
            normalized.title = parsed.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.dueDate = parsed.dueDate ?? request.dueDate
            normalized.priority = parsed.priority == .none ? request.priority : parsed.priority
        } else {
            let parsed = MagicInputParser.parse(safeTitle)
            normalized.title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.dueDate = parsed.dueDate ?? request.dueDate
            normalized.priority = parsed.priority == .none ? request.priority : parsed.priority
        }

        return normalized
    }

    private func normalize(requests: [Request]) async -> [Request] {
        var normalizedRequests: [Request] = []
        normalizedRequests.reserveCapacity(requests.count)

        for request in requests {
            normalizedRequests.append(await normalize(request: request))
        }

        return normalizedRequests
    }

    private func buildReminder(from request: Request, in context: ModelContext) -> Reminder {
        let reminder = Reminder(
            title: request.title,
            details: request.details,
            dueDate: request.dueDate,
            priority: request.priority,
            tags: [],
            notifications: [],
            locationTrigger: nil,
            list: request.list,
            autoTextTaggedContacts: request.autoTextTaggedContacts,
            autoTextMe: request.autoTextMe,
            appleNote: request.attachedNote,
            voiceReminder: request.voiceReminder,
            energyLevel: request.energyLevel
        )

        apply(request, to: reminder, in: context)
        return reminder
    }

    private func apply(_ request: Request, to reminder: Reminder, in context: ModelContext) {
        reminder.title = request.title
        reminder.details = request.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        reminder.dueDate = request.dueDate
        reminder.priority = request.priority
        reminder.energyLevel = request.energyLevel
        reminder.list = request.list
        reminder.autoTextTaggedContacts = request.autoTextTaggedContacts
        reminder.autoTextMe = request.autoTextMe
        reminder.appleNote = request.attachedNote
        reminder.voiceReminder = request.voiceReminder

        let tags = resolveTags(
            from: "\(request.title) \(request.details ?? "")",
            selectedTags: request.selectedTags,
            in: context
        )
        reminder.tags = tags.isEmpty ? nil : tags

        attachLeadTimeNotifications(request.leadTimes, to: reminder)
        attachLocation(
            label: request.locationLabel,
            latitude: request.locationLatitude,
            longitude: request.locationLongitude,
            radius: request.locationRadius,
            type: request.locationType,
            to: reminder
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
