import Foundation

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

enum SearchSpotlightIdentifiers {
    static let savedSearchDomain = "saved-searches"
    static let savedSearchPrefix = "saved-search-"

    static func savedSearchIdentifier(for id: UUID) -> String {
        savedSearchPrefix + id.uuidString
    }
}

final class SearchSpotlightManager {
    static let shared = SearchSpotlightManager()

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
        guard !RuntimeEnvironment.isRunningTests else { return }

        #if canImport(CoreSpotlight)
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [SearchSpotlightIdentifiers.savedSearchIdentifier(for: id)]
        )
        #endif
    }
}
