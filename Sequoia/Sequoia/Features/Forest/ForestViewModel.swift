import Foundation
import Observation
import SequoiaCore

@MainActor
@Observable
final class ForestViewModel {
    let store: SequoiaStore
    /// The first day of the month shown in the streak calendar.
    var calendarMonth: DayStamp

    init(store: SequoiaStore) {
        self.store = store
        self.calendarMonth = DayStamp(year: store.today.year, month: store.today.month, day: 1)
    }

    var growth: GrowthState { store.growth }
    var stage: TreeStage { store.stage }
    var plantedCount: Int { store.growth.plantedTrees }
    var daysToFullGrowth: Int { store.engine.config.daysToFullGrowth }

    var plantedTrees: [PlantedTreeRecord] {
        _ = store.revision
        return store.plantedTrees()
    }

    var completedDays: Set<DayStamp> {
        _ = store.revision
        return store.completedDays()
    }

    var wordsLearned: Int { growth.totalCheckIns }

    /// The VoiceOver summary, e.g. "Your forest: 4 grown sequoias and a sapling on day 9."
    var accessibilityDescription: String {
        Self.describe(planted: plantedCount, stage: stage, treeDays: growth.treeDays)
    }

    nonisolated static func describe(planted: Int, stage: TreeStage, treeDays: Int) -> String {
        let trees = planted == 0
            ? String(localized: "no grown sequoias yet")
            : planted == 1 ? String(localized: "1 grown sequoia") : String(localized: "\(planted) grown sequoias")
        let current = treeDays == 0
            ? String(localized: "a seed waiting to be planted")
            : String(localized: "a \(stage.title.lowercased()) on day \(treeDays)")
        return String(localized: "Your forest: \(trees) and \(current).")
    }

    // MARK: - Calendar

    func showPreviousMonth() { calendarMonth = shiftMonth(by: -1) }
    func showNextMonth() { calendarMonth = shiftMonth(by: 1) }
    var canShowNextMonth: Bool { calendarMonth < DayStamp(year: store.today.year, month: store.today.month, day: 1) }

    var monthTitle: String {
        calendarMonth.startDate(in: store.currentClock.calendar).formatted(.dateTime.month(.wide).year())
    }

    /// Days of the shown month, padded with `nil` so weeks line up.
    var calendarCells: [DayStamp?] {
        let calendar = store.currentClock.calendar
        let first = calendarMonth.startDate(in: calendar)
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        return Array(repeating: nil, count: leading) + (0..<count).map { calendarMonth.adding(days: $0) }
    }

    var weekdaySymbols: [String] {
        let calendar = store.currentClock.calendar
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private func shiftMonth(by months: Int) -> DayStamp {
        var year = calendarMonth.year
        var month = calendarMonth.month + months
        if month < 1 { month = 12; year -= 1 }
        if month > 12 { month = 1; year += 1 }
        return DayStamp(year: year, month: month, day: 1)
    }
}
