#if SEQUOIA_DEV
import Foundation
import SequoiaCore

/// Launch arguments that drive developer tools from scripts and UI tests:
/// `-devEnable`, `-devAdvanceDays N`, `-devJumpStage N`, `-devFillForest N`,
/// `-devResetProgress`, `-devResetClock`, `-devReminderInMinutes N`. Compiled only in `SEQUOIA_DEV` builds.
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
        if let minutes = value(after: "-devReminderInMinutes") { setReminder(minutesFromNow: minutes, store: store) }
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

    /// The tab requested with `-tab today|library|practice|forest`.
    static var initialTab: AppTab? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1) else { return nil }
        return AppTab(rawValue: arguments[index + 1])
    }

    private static func value(after flag: String) -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }
}
#endif
