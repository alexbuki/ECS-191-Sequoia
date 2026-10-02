import WidgetKit
import SequoiaCore

/// One moment in a widget's timeline.
struct WordEntry: TimelineEntry {
    let snapshot: WidgetSnapshot
    var date: Date { snapshot.date }

    /// Shown in the widget gallery and while loading.
    static var sample: WordEntry {
        let clock = AppClock.live
        let day = clock.today()
        let word = DailyWordSelector().word(for: day, difficulty: .elevated)
        return WordEntry(snapshot: WidgetSnapshot(
            date: .now, day: day, word: word, stage: .sapling, streak: 9, isCompleted: false
        ))
    }
}

/// Reads today's word and tree from the shared App Group store, and plans a
/// refresh at local midnight when the word changes.
struct WordTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WordEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { @MainActor in
            completion(Self.plan().entries.first.map(WordEntry.init) ?? .sample)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WordEntry>) -> Void) {
        Task { @MainActor in
            let plan = Self.plan()
            completion(Timeline(entries: plan.entries.map(WordEntry.init), policy: .after(plan.reloadDate)))
        }
    }

    @MainActor
    private static func plan() -> WidgetTimelinePlan {
        SequoiaStore(container: Persistence.makeContainerOrFallback()).widgetTimeline()
    }
}
