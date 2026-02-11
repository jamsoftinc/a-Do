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
        await MainActor.run {
            let container = AppContainer.shared.getContainer()
            let context = ModelContext(container)
            var results: [ReminderEntity] = []

            for id in identifiers {
                let descriptor = FetchDescriptor<Reminder>(
                    predicate: #Predicate { $0.uuid == id }
                )

                if let reminder = try? context.fetch(descriptor).first {
                    results.append(ReminderEntity(
                        id: reminder.uuid,
                        title: reminder.title,
                        details: reminder.details,
                        dueDate: reminder.dueDate,
                        isCompleted: reminder.isCompleted,
                        priorityLevel: reminder.priority.title,
                        listName: nil
                    ))
                }
            }
            return results
        }
    }

    /// String-based search for Visual Intelligence
    func suggestedEntities() async throws -> [ReminderEntity] {
        await MainActor.run {
            // Return top reminders for quick access
            let container = AppContainer.shared.getContainer()
            let context = ModelContext(container)

            var descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate { !$0.isCompleted },
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            descriptor.fetchLimit = 10

            let reminders = (try? context.fetch(descriptor)) ?? []

            return reminders.map { reminder in
                ReminderEntity(
                    id: reminder.uuid,
                    title: reminder.title,
                    details: reminder.details,
                    dueDate: reminder.dueDate,
                    isCompleted: reminder.isCompleted,
                    priorityLevel: reminder.priority.title,
                    listName: nil
                )
            }
        }
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
        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)

        // Search reminders matching the query
        let searchLower = query.lowercased()

        let descriptor = FetchDescriptor<Reminder>()
        let allReminders = (try? context.fetch(descriptor)) ?? []

        let matchingReminders = allReminders.filter { reminder in
            reminder.title.lowercased().contains(searchLower) ||
            (reminder.details?.lowercased().contains(searchLower) ?? false)
        }

        let entities = matchingReminders.prefix(10).map { reminder in
            ReminderEntity(
                id: reminder.uuid,
                title: reminder.title,
                details: reminder.details,
                dueDate: reminder.dueDate,
                isCompleted: reminder.isCompleted,
                priorityLevel: reminder.priority.title,
                listName: nil
            )
        }

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
        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)

        if useAI, EntitlementManager.shared.isProUser {
            let requests = await AIManager.shared.buildCaptureRequests(from: content)
            guard !requests.isEmpty else {
                return .result(dialog: "Couldn't parse visual text into reminders.")
            }

            var createdCount = 0
            for request in requests {
                do {
                    _ = try await ReminderCreationService.shared.createReminder(request: request, in: context)
                    createdCount += 1
                } catch {
                    continue
                }
            }

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
        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)

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

        let reminder = Reminder(title: title, dueDate: tomorrow)
        reminder.details = details.isEmpty ? nil : details
        reminder.priority = .medium

        context.insert(reminder)

        do {
            try context.save()
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
        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)

        if EntitlementManager.shared.isProUser {
            let requests = await AIManager.shared.buildCaptureRequests(from: documentText)
            guard !requests.isEmpty else {
                return .result(dialog: "No actionable reminders found in document.")
            }

            var createdCount = 0
            for request in requests {
                do {
                    _ = try await ReminderCreationService.shared.createReminder(request: request, in: context)
                    createdCount += 1
                } catch {
                    continue
                }
            }

            if createdCount > 0 {
                return .result(dialog: "Created \(createdCount) reminders from document")
            }
            return .result(dialog: "Failed to create reminders from document")
        }

        // Parse document for action items
        let lines = documentText.components(separatedBy: .newlines)
        var createdCount = 0

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
                    let reminder = Reminder(title: taskText)
                    context.insert(reminder)
                    createdCount += 1
                }
            }
        }

        do {
            try context.save()
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
        await MainActor.run {
            let container = AppContainer.shared.getContainer()
            let context = ModelContext(container)

            let searchLower = string.lowercased()

            let descriptor = FetchDescriptor<Reminder>()
            let allReminders = (try? context.fetch(descriptor)) ?? []

            let matchingReminders = allReminders.filter { reminder in
                reminder.title.lowercased().contains(searchLower) ||
                (reminder.details?.lowercased().contains(searchLower) ?? false)
            }

            return matchingReminders.prefix(20).map { reminder in
                ReminderEntity(
                    id: reminder.uuid,
                    title: reminder.title,
                    details: reminder.details,
                    dueDate: reminder.dueDate,
                    isCompleted: reminder.isCompleted,
                    priorityLevel: reminder.priority.title,
                    listName: nil
                )
            }
        }
    }
}
