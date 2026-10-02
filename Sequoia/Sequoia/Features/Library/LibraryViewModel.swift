import Foundation
import Observation
import SequoiaCore

/// Past words, newest first, with search and a favorites filter.
@MainActor
@Observable
final class LibraryViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all, favorites
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: String(localized: "All")
            case .favorites: String(localized: "Favorites")
            }
        }
    }

    let store: SequoiaStore
    var searchText = ""
    var filter: Filter = .all

    init(store: SequoiaStore) {
        self.store = store
    }

    /// Every seen word, newest first.
    var allWords: [SeenWord] {
        _ = store.revision
        return store.seenWords()
    }

    var visibleWords: [SeenWord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allWords.filter { entry in
            (filter == .all || entry.isFavorite)
                && (query.isEmpty
                    || entry.word.word.localizedCaseInsensitiveContains(query)
                    || entry.word.definition.localizedCaseInsensitiveContains(query))
        }
    }

    func toggleFavorite(_ entry: SeenWord) {
        store.toggleFavorite(entry.id)
    }

    func dateLabel(for entry: SeenWord) -> String {
        if entry.firstSeen == store.today { return String(localized: "Today") }
        if entry.firstSeen == store.today.adding(days: -1) { return String(localized: "Yesterday") }
        return entry.firstSeen.startDate(in: store.currentClock.calendar).formatted(.dateTime.month(.abbreviated).day())
    }
}
