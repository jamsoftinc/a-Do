import Foundation
import SwiftData

#if canImport(CoreSpotlight)
import CoreSpotlight
import UniformTypeIdentifiers
#endif

struct SavedSearchSpotlightItem: Sendable {
    let id: UUID
    let name: String
    let query: String
    let searchTypeName: String
    let scopeName: String
    let sortOrderName: String
}

struct ReminderSpotlightItem: Sendable {
    let id: UUID
    let title: String
    let details: String
    let dueDate: Date?
    let priorityName: String
    let tags: [String]
}

struct HabitSpotlightItem: Sendable {
    let id: UUID
    let title: String
    let details: String
    let isActive: Bool
    let tags: [String]
}

struct ListSpotlightItem: Sendable {
    let name: String
    let reminderCount: Int
    let isSmart: Bool
}

enum SearchSpotlightIdentifiers {
    static let savedSearchDomain = "saved-searches"
    static let reminderDomain = "reminders"
    static let habitDomain = "habits"
    static let listDomain = "lists"

    static let savedSearchPrefix = "saved-search-"
    static let reminderPrefix = "reminder-"
    static let habitPrefix = "habit-"
    static let listPrefix = "list-"

    static func savedSearchIdentifier(for id: UUID) -> String {
        savedSearchPrefix + id.uuidString
    }

    static func reminderIdentifier(for id: UUID) -> String {
        reminderPrefix + id.uuidString
    }

    static func habitIdentifier(for id: UUID) -> String {
        habitPrefix + id.uuidString
    }

    static func listIdentifier(for name: String) -> String {
        listPrefix + encoded(name)
    }

    static func reminderID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(reminderPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(reminderPrefix.count)))
    }

    static func habitID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(habitPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(habitPrefix.count)))
    }

    static func listName(from identifier: String) -> String? {
        guard identifier.hasPrefix(listPrefix) else { return nil }
        return decoded(String(identifier.dropFirst(listPrefix.count)))
    }

    private static func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private static func decoded(_ value: String) -> String? {
        value.removingPercentEncoding
    }
}

final class SearchSpotlightManager {
    static let shared = SearchSpotlightManager()

    private let suiteName = "group.com.ado.app"
    private let coreIndexUpdatedAtKey = "spotlight_core_index_updated_at"
    private let refreshInterval: TimeInterval = 6 * 60 * 60

    private init() {}

    func indexSavedSearch(_ item: SavedSearchSpotlightItem) async {
        guard !RuntimeEnvironment.isRunningTests else { return }

        #if canImport(CoreSpotlight)
        let attributeSet = CSSearchableItemAttributeSet(contentType: .data)
        attributeSet.title = item.name
        attributeSet.displayName = item.name
        attributeSet.contentDescription = [
            "Smart Search view",
            item.query,
            item.scopeName,
            item.searchTypeName,
            item.sortOrderName
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
        attributeSet.keywords = [
            item.query,
            item.scopeName,
            item.searchTypeName,
            item.sortOrderName,
            "smart search",
            "saved view"
        ]

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: SearchSpotlightIdentifiers.savedSearchIdentifier(for: item.id),
            domainIdentifier: SearchSpotlightIdentifiers.savedSearchDomain,
            attributeSet: attributeSet
        )

        try? await CSSearchableIndex.default().indexSearchableItems([searchableItem])
        #endif
    }

    func removeSavedSearch(id: UUID) async {
        await removeItems(withIdentifiers: [SearchSpotlightIdentifiers.savedSearchIdentifier(for: id)])
    }

    func syncReminder(_ reminder: Reminder) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        await indexReminders([
            ReminderSpotlightItem(
                id: reminder.uuid,
                title: reminder.title,
                details: reminder.details ?? "",
                dueDate: reminder.dueDate,
                priorityName: reminder.priority.title,
                tags: reminder.tags?.map(\.name) ?? []
            )
        ])
    }

    func removeReminder(id: UUID) async {
        await removeItems(withIdentifiers: [SearchSpotlightIdentifiers.reminderIdentifier(for: id)])
    }

    func syncHabit(_ habit: Habit) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        await indexHabits([
            HabitSpotlightItem(
                id: habit.id,
                title: habit.title,
                details: habit.habitDescription,
                isActive: habit.isActive,
                tags: habit.tags?.map(\.name) ?? []
            )
        ])
    }

    func removeHabit(id: UUID) async {
        await removeItems(withIdentifiers: [SearchSpotlightIdentifiers.habitIdentifier(for: id)])
    }

    func syncList(_ list: ReminderList) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        await indexLists([
            ListSpotlightItem(
                name: list.name,
                reminderCount: list.reminderCount,
                isSmart: list.isSmart
            )
        ])
    }

    func removeList(name: String) async {
        await removeItems(withIdentifiers: [SearchSpotlightIdentifiers.listIdentifier(for: name)])
    }

    func rebuildCoreEntitiesIfNeeded(context: ModelContext, reason: String, force: Bool = false) async {
        guard !RuntimeEnvironment.isRunningTests else { return }

        let defaults = UserDefaults(suiteName: suiteName)
        let lastRefresh = defaults?.object(forKey: coreIndexUpdatedAtKey) as? Date
        let isStale = lastRefresh.map { Date().timeIntervalSince($0) >= refreshInterval } ?? true
        guard force || isStale else { return }
        let container = context.container

        let (reminders, habits, lists) = await Task.detached(priority: .utility) {
            let backgroundContext = ModelContext(container)

            var reminderDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate { !$0.isCompleted },
                sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.createdAt, order: .reverse)]
            )
            reminderDescriptor.fetchLimit = 50

            var habitDescriptor = FetchDescriptor<Habit>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            habitDescriptor.fetchLimit = 50

            var listDescriptor = FetchDescriptor<ReminderList>(
                sortBy: [SortDescriptor(\.name)]
            )
            listDescriptor.fetchLimit = 50

            let reminders = ((try? backgroundContext.fetch(reminderDescriptor)) ?? []).map {
                ReminderSpotlightItem(
                    id: $0.uuid,
                    title: $0.title,
                    details: $0.details ?? "",
                    dueDate: $0.dueDate,
                    priorityName: $0.priority.title,
                    tags: $0.tags?.map(\.name) ?? []
                )
            }

            let habits = ((try? backgroundContext.fetch(habitDescriptor)) ?? []).map {
                HabitSpotlightItem(
                    id: $0.id,
                    title: $0.title,
                    details: $0.habitDescription,
                    isActive: $0.isActive,
                    tags: $0.tags?.map(\.name) ?? []
                )
            }

            let lists = ((try? backgroundContext.fetch(listDescriptor)) ?? []).map {
                ListSpotlightItem(
                    name: $0.name,
                    reminderCount: $0.reminderCount,
                    isSmart: $0.isSmart
                )
            }

            return (reminders, habits, lists)
        }.value

        #if canImport(CoreSpotlight)
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [
                SearchSpotlightIdentifiers.reminderDomain,
                SearchSpotlightIdentifiers.habitDomain,
                SearchSpotlightIdentifiers.listDomain
            ]
        )
        #endif

        await indexReminders(reminders)
        await indexHabits(habits)
        await indexLists(lists)
        defaults?.set(Date(), forKey: coreIndexUpdatedAtKey)
        _ = reason
    }

    private func indexReminders(_ items: [ReminderSpotlightItem]) async {
        #if canImport(CoreSpotlight)
        guard !items.isEmpty else { return }

        let searchableItems = items.map { item in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = item.title
            attributeSet.displayName = item.title
            attributeSet.contentDescription = [
                item.details,
                item.priorityName,
                item.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? ""
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            attributeSet.keywords = item.tags + [item.priorityName, "reminder", "task"]

            return CSSearchableItem(
                uniqueIdentifier: SearchSpotlightIdentifiers.reminderIdentifier(for: item.id),
                domainIdentifier: SearchSpotlightIdentifiers.reminderDomain,
                attributeSet: attributeSet
            )
        }

        try? await CSSearchableIndex.default().indexSearchableItems(searchableItems)
        #endif
    }

    private func indexHabits(_ items: [HabitSpotlightItem]) async {
        #if canImport(CoreSpotlight)
        guard !items.isEmpty else { return }

        let searchableItems = items.map { item in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = item.title
            attributeSet.displayName = item.title
            attributeSet.contentDescription = [
                item.details,
                item.isActive ? "Active habit" : "Inactive habit"
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            attributeSet.keywords = item.tags + ["habit", "routine", item.isActive ? "active" : "inactive"]

            return CSSearchableItem(
                uniqueIdentifier: SearchSpotlightIdentifiers.habitIdentifier(for: item.id),
                domainIdentifier: SearchSpotlightIdentifiers.habitDomain,
                attributeSet: attributeSet
            )
        }

        try? await CSSearchableIndex.default().indexSearchableItems(searchableItems)
        #endif
    }

    private func indexLists(_ items: [ListSpotlightItem]) async {
        #if canImport(CoreSpotlight)
        guard !items.isEmpty else { return }

        let searchableItems = items.map { item in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = item.name
            attributeSet.displayName = item.name
            attributeSet.contentDescription = "\(item.reminderCount) reminders • \(item.isSmart ? "Smart list" : "List")"
            attributeSet.keywords = ["list", item.isSmart ? "smart list" : "manual list", item.name]

            return CSSearchableItem(
                uniqueIdentifier: SearchSpotlightIdentifiers.listIdentifier(for: item.name),
                domainIdentifier: SearchSpotlightIdentifiers.listDomain,
                attributeSet: attributeSet
            )
        }

        try? await CSSearchableIndex.default().indexSearchableItems(searchableItems)
        #endif
    }

    private func removeItems(withIdentifiers identifiers: [String]) async {
        guard !RuntimeEnvironment.isRunningTests else { return }

        #if canImport(CoreSpotlight)
        try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers)
        #else
        _ = identifiers
        #endif
    }
}
