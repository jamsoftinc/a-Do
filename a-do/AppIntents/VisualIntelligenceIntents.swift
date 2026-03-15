//
//  VisualIntelligenceIntents.swift
//  a-do
//
//  App Intents for Visual Intelligence integration
//  Enables visual search within the a-do app from Visual Intelligence
//

import AppIntents
import SwiftData
import SwiftUI

private enum VisualIntelligenceReminderStore {
    nonisolated static func makeContext() throws -> ModelContext {
        try AppContainer.makeAppGroupContext()
    }

    nonisolated static func loadReminderEntities(
        context: ModelContext,
        identifiers: Set<UUID>? = nil,
        matching query: String? = nil,
        limit: Int
    ) async -> [ReminderEntity] {
        let requestedLimit = max(limit * 4, max(identifiers?.count ?? 0, 50))
        let snapshots = await MemorySafeDataLoader.loadSearchableReminders(context: context, limit: requestedLimit)
        let normalizedQuery = query?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let filtered = snapshots.filter { snapshot in
            guard let id = UUID(uuidString: snapshot.id) else { return false }
            if let identifiers, !identifiers.contains(id) {
                return false
            }

            guard let normalizedQuery, !normalizedQuery.isEmpty else {
                return true
            }

            let haystack = [
                snapshot.title,
                snapshot.details,
                snapshot.tags.joined(separator: " ")
            ]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

            return haystack.contains(normalizedQuery)
        }

        let sorted = filtered.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.createdAt > rhs.createdAt
            }
        }

        return sorted.prefix(limit).compactMap { snapshot in
            guard let id = UUID(uuidString: snapshot.id) else { return nil }
            return ReminderEntity(
                id: id,
                title: snapshot.title,
                details: snapshot.details.isEmpty ? nil : snapshot.details,
                dueDate: snapshot.dueDate,
                isCompleted: snapshot.isCompleted,
                priorityLevel: snapshot.priority.title,
                listName: nil
            )
        }
    }
}

// MARK: - Reminder Entity for Visual Intelligence

/// Entity representing a Reminder for use with App Intents and Visual Intelligence
struct ReminderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reminder"

    static var defaultQuery = ReminderEntityQuery()

    var id: UUID
    var title: String
    var details: String?
    var dueDate: Date?
    var isCompleted: Bool
    var priorityLevel: String
    var listName: String?

    var displayRepresentation: DisplayRepresentation {
        var subtitle = ""
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            subtitle = formatter.string(from: dueDate)
        }
        if isCompleted {
            subtitle = "Completed" + (subtitle.isEmpty ? "" : " • \(subtitle)")
        }

        return DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }
}

// MARK: - Reminder Entity Query for Visual Intelligence Search

/// Query for searching reminders - enables Visual Intelligence integration
struct ReminderEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReminderEntity] {
        let context = try VisualIntelligenceReminderStore.makeContext()
        return await VisualIntelligenceReminderStore.loadReminderEntities(
            context: context,
            identifiers: Set(identifiers),
            matching: nil,
            limit: identifiers.count
        )
    }

    /// String-based search for Visual Intelligence
    func suggestedEntities() async throws -> [ReminderEntity] {
        let context = try VisualIntelligenceReminderStore.makeContext()
        return await VisualIntelligenceReminderStore.loadReminderEntities(
            context: context,
            matching: nil,
            limit: 10
        ).filter { !$0.isCompleted }
    }
}

// MARK: - Visual Search Intent

/// Intent for searching reminders via Visual Intelligence
/// This allows users to point their camera at text and find related reminders
struct SearchRemindersVisually: AppIntent {
    static var title: LocalizedStringResource = "Search Reminders"
    static var description = IntentDescription(
        "Search for reminders matching the text or image you're looking at",
        categoryName: "Visual Search"
    )

    /// Enable Visual Intelligence integration
    static var isDiscoverable: Bool = true

    @Parameter(title: "Search Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ReminderEntity]> {
        let context = try VisualIntelligenceReminderStore.makeContext()
        let entities = await VisualIntelligenceReminderStore.loadReminderEntities(
            context: context,
            matching: query,
            limit: 10
        )

        return .result(value: Array(entities))
    }
}

// MARK: - Create Reminder from Visual Content

/// Intent for creating a reminder from visually captured content
struct CreateReminderFromVisual: AppIntent {
    static var title: LocalizedStringResource = "Create Reminder from Visual"
    static var description = IntentDescription(
        "Create a new reminder from text captured by Visual Intelligence",
        categoryName: "Visual Intelligence"
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Text Content")
    var content: String

    @Parameter(title: "Parse with AI", default: true)
    var useAI: Bool

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        let context = try VisualIntelligenceReminderStore.makeContext()

        if useAI, EntitlementManager.shared.isProUser {
            let requests = await AIManager.shared.buildCaptureRequests(from: content)
            guard !requests.isEmpty else {
                return .result(dialog: "Couldn't parse visual text into reminders.")
            }

            let createdCount = ((try? await ReminderCreationService.shared.createReminders(requests: requests, in: context)) ?? []).count

            if createdCount > 0 {
                return .result(dialog: "Created \(createdCount) reminder\(createdCount == 1 ? "" : "s") from visual content.")
            }
            return .result(dialog: "Failed to create reminders from visual content.")
        }

        var reminderTitle = content
        var dueDate: Date?
        if useAI {
            let parsed = await NaturalLanguageProcessor.shared.parseReminderText(content)
            reminderTitle = parsed.finalText
            dueDate = parsed.dueDate
        }

        do {
            let request = ReminderCreationService.Request(
                title: reminderTitle,
                details: nil,
                dueDate: dueDate,
                useNaturalLanguageParsing: false
            )
            _ = try await ReminderCreationService.shared.createReminder(request: request, in: context)
            return .result(dialog: "Created reminder: \(reminderTitle)")
        } catch {
            return .result(dialog: "Failed to create reminder: \(error.localizedDescription)")
        }
    }
}

// MARK: - Scan Business Card Intent

/// Intent for scanning business cards and creating contact-based reminders
struct ScanBusinessCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Business Card"
    static var description = IntentDescription(
        "Scan a business card and create a follow-up reminder",
        categoryName: "Visual Intelligence"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Contact Name")
    var contactName: String?

    @Parameter(title: "Email")
    var email: String?

    @Parameter(title: "Phone")
    var phone: String?

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        let context = try VisualIntelligenceReminderStore.makeContext()

        let name = contactName ?? "New Contact"
        let title = "Follow up with \(name)"

        var details = ""
        if let email = email {
            details += "Email: \(email)\n"
        }
        if let phone = phone {
            details += "Phone: \(phone)"
        }

        // Create follow-up reminder for tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())

        do {
            _ = try await ReminderCreationService.shared.createReminder(
                request: .init(
                    title: title,
                    details: details.isEmpty ? nil : details,
                    dueDate: tomorrow,
                    priority: .medium,
                    useNaturalLanguageParsing: false
                ),
                in: context
            )
            return .result(dialog: "Created follow-up reminder for \(name)")
        } catch {
            return .result(dialog: "Failed to create reminder")
        }
    }
}

// MARK: - Scan Document Intent

/// Intent for scanning documents and extracting tasks
struct ScanDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Document for Tasks"
    static var description = IntentDescription(
        "Scan a document and extract action items as reminders",
        categoryName: "Visual Intelligence"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Document Text")
    var documentText: String

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        let context = try VisualIntelligenceReminderStore.makeContext()

        if EntitlementManager.shared.isProUser {
            let requests = await AIManager.shared.buildCaptureRequests(from: documentText)
            guard !requests.isEmpty else {
                return .result(dialog: "No actionable reminders found in document.")
            }

            let createdCount = ((try? await ReminderCreationService.shared.createReminders(requests: requests, in: context)) ?? []).count

            if createdCount > 0 {
                return .result(dialog: "Created \(createdCount) reminders from document")
            }
            return .result(dialog: "Failed to create reminders from document")
        }

        // Parse document for action items
        let lines = documentText.components(separatedBy: .newlines)
        var requests: [ReminderCreationService.Request] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines or very short lines
            guard trimmed.count >= 5 else { continue }

            // Look for action item patterns
            let actionPatterns = ["todo:", "action:", "task:", "[ ]", "•", "-", "*"]
            let isActionItem = actionPatterns.contains { pattern in
                trimmed.lowercased().hasPrefix(pattern)
            }

            if isActionItem {
                // Clean up the text
                var taskText = trimmed
                for pattern in actionPatterns {
                    if taskText.lowercased().hasPrefix(pattern) {
                        taskText = String(taskText.dropFirst(pattern.count))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }

                if !taskText.isEmpty {
                    requests.append(
                        ReminderCreationService.Request(
                            title: taskText,
                            details: nil,
                            dueDate: nil,
                            useNaturalLanguageParsing: false
                        )
                    )
                }
            }
        }

        guard !requests.isEmpty else {
            return .result(dialog: "No action items found in document")
        }

        do {
            let createdCount = try await ReminderCreationService.shared.createReminders(requests: requests, in: context).count
            if createdCount > 0 {
                return .result(dialog: "Created \(createdCount) reminders from document")
            } else {
                return .result(dialog: "No action items found in document")
            }
        } catch {
            return .result(dialog: "Failed to create reminders: \(error.localizedDescription)")
        }
    }
}

// MARK: - Visual Intelligence Shortcuts
// Note: Visual Intelligence shortcuts are registered in ADOAppShortcutsProvider (EnhancedSiriManager.swift)
// to maintain a single AppShortcutsProvider per app. The intents remain usable through the
// EntityQuery system for Visual Intelligence integration.

// MARK: - Entity Index for Visual Intelligence

/// Provides entity indexing for Visual Intelligence search
extension ReminderEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ReminderEntity] {
        let context = try VisualIntelligenceReminderStore.makeContext()
        return await VisualIntelligenceReminderStore.loadReminderEntities(
            context: context,
            matching: string,
            limit: 20
        )
    }
}
