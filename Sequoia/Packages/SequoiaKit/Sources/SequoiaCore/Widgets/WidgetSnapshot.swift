import Foundation

/// What a widget (or the watch) shows at one moment: the word and the current tree.
public struct WidgetSnapshot: Equatable, Sendable {
    /// The real (wall-clock) time this snapshot becomes current.
    public var date: Date
    public var day: DayStamp
    public var word: Word
    public var stage: TreeStage
    public var streak: Int
    public var isCompleted: Bool

    public init(date: Date, day: DayStamp, word: Word, stage: TreeStage, streak: Int, isCompleted: Bool) {
        self.date = date
        self.day = day
        self.word = word
        self.stage = stage
        self.streak = streak
        self.isCompleted = isCompleted
    }
}

/// The snapshots for now and the next local midnight, plus when to ask again.
public struct WidgetTimelinePlan: Equatable, Sendable {
    public var entries: [WidgetSnapshot]
    public var reloadDate: Date
}

extension SequoiaStore {
    /// The current snapshot, and one for the next local midnight showing
    /// tomorrow's word and the tree as it will be then (a lapsed streak resets).
    ///
    /// - Parameter realOffset: how far the store's clock runs ahead of real
    ///   time (the developer offset). Widget entries are dated in real time.
    public func widgetTimeline(realOffset: TimeInterval = AppClock.developerOffset) -> WidgetTimelinePlan {
        refresh()
        let clock = currentClock
        let now = clock.now()
        let tomorrow = today.adding(days: 1)
        let midnight = tomorrow.startDate(in: clock.calendar)
        let tomorrowGrowth = engine.refreshed(growth, today: tomorrow)

        let current = WidgetSnapshot(
            date: now.addingTimeInterval(-realOffset), day: today, word: todayWord,
            stage: stage, streak: growth.currentStreak, isCompleted: todayCompleted
        )
        let next = WidgetSnapshot(
            date: midnight.addingTimeInterval(-realOffset), day: tomorrow, word: word(for: tomorrow),
            stage: engine.stage(of: tomorrowGrowth), streak: tomorrowGrowth.currentStreak, isCompleted: false
        )
        // Ask again just after midnight, so the following day is planned too.
        return WidgetTimelinePlan(entries: [current, next], reloadDate: next.date.addingTimeInterval(60))
    }
}
