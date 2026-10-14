#if SEQUOIA_DEV
import Foundation
import SequoiaCore

/// Launch arguments that drive developer tools from scripts and UI tests:
/// `-devEnable`, `-devAdvanceDays N`, `-devJumpStage N`, `-devFillForest N`,
/// `-devResetProgress`, `-devResetClock`, `-devReminderInMinutes N`, `-devCeremony`,
/// `-devPlantedElsewhere`, `-devRainDays N`, `-devMissDay`, `-devMissWords N`, `-devPracticeRounds N`.
/// Compiled only in `SEQUOIA_DEV` builds.
enum DevLaunchActions {
    /// Applied before the store opens (affects which store and clock are used).
    static func applyBeforeLaunch() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-devEnable") { DevModeController.shared.setEnabled(true) }
        if arguments.contains("-devResetClock") { DevModeController.shared.resetClock() }
        if let days = value(after: "-devAdvanceDays") { DevModeController.shared.advance(days: days) }
    }

    /// Applied to the opened store.
    static func apply(to store: SequoiaStore) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-devResetProgress") { store.resetProgress() }
        if let count = value(after: "-devFillForest") { store.devFillForest(adding: count) }
        if let raw = value(after: "-devJumpStage"), let stage = TreeStage(rawValue: raw) { store.devJump(to: stage) }
        if let days = value(after: "-devSimulateCheckIns") { simulateCheckIns(days: days, store: store) }
        if let count = value(after: "-devRainDays") { for _ in 0..<count { store.devGrantRainDay() } }
        if arguments.contains("-devMissDay") { missOneDay(store: store) }
        if let count = value(after: "-devMissWords") { missWords(count, store: store) }
        if let count = value(after: "-devPracticeRounds") {
            for game in (0..<count).map({ PracticeGame.allCases[$0 % 2] }) { store.recordPractice(game, correctAnswers: 4) }
        }
        if let minutes = value(after: "-devReminderInMinutes") { setReminder(minutesFromNow: minutes, store: store) }
        // Trees planted by these tools don't get a ceremony on launch...
        store.markCeremoniesShown()
        // ...unless one was planted as the widget or watch would, to test that path.
        if arguments.contains("-devPlantedElsewhere") {
            store.devJump(to: .grownSequoia)
            store.checkIn()
        }
        store.refresh()
    }

    /// Checks in on each of the next `days` days, ending on the simulated today.
    static func simulateCheckIns(days: Int, store: SequoiaStore) {
        for index in 0..<days {
            store.checkIn()
            if index < days - 1 {
                DevModeController.shared.advance(days: 1)
                store.refresh()
            }
        }
    }

    /// Sets the reminder time to N minutes from the real time (to watch it fire),
    /// rounded up to a whole minute so it is never less than N minutes away.
    static func setReminder(minutesFromNow minutes: Int, store: SequoiaStore) {
        let later = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        let fire = Calendar.current.dateInterval(of: .minute, for: later)?.end ?? later
        let parts = Calendar.current.dateComponents([.hour, .minute], from: fire)
        store.updateSettings {
            $0.notificationsEnabled = true
            $0.reminderHour = parts.hour ?? 8
            $0.reminderMinute = parts.minute ?? 0
        }
    }

    /// Moves the clock so exactly one day goes unchecked: tomorrow if today is
    /// done, otherwise today itself. A rain day covers it if one is saved.
    static func missOneDay(store: SequoiaStore) {
        let today = store.today
        let target = max(today.adding(days: 1), (store.growth.lastCheckInDay ?? today).adding(days: 2))
        DevModeController.shared.advance(days: target.days(since: today))
        store.refresh()
    }

    /// Marks the `count` most recent seen words as missed in practice.
    static func missWords(_ count: Int, store: SequoiaStore) {
        for word in store.seenWords().prefix(count) { store.recordAnswer(wordID: word.id, correct: false) }
    }

    /// Whether `-devCeremony` asked to show the planting ceremony on launch.
    static var showsCeremony: Bool { ProcessInfo.processInfo.arguments.contains("-devCeremony") }

    /// The tab requested with `-tab today|library|practice|forest`.
    /// `practice` opens Library with Practice pushed (see `opensPractice`).
    static var initialTab: AppTab? {
        tabArgument.flatMap(AppTab.init(rawValue:))
    }

    static var opensPractice: Bool { tabArgument == "practice" }

    private static var tabArgument: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func value(after flag: String) -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }
}
#endif
