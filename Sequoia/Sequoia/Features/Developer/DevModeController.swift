#if SEQUOIA_DEV
import Foundation
import Observation
import SequoiaCore

/// Observable wrapper around `DevMode` so the UI refreshes when the simulated
/// clock changes. Compiled only in `SEQUOIA_DEV` builds.
@Observable
final class DevModeController {
    static let shared = DevModeController()

    private(set) var isEnabled = DevMode.isEnabled
    private(set) var timeOffset = DevMode.timeOffset

    func setEnabled(_ enabled: Bool) {
        DevMode.isEnabled = enabled
        isEnabled = enabled
    }

    func advance(days: Int) {
        setOffset(timeOffset + TimeInterval(days) * 86_400)
    }

    func set(date: Date) {
        setOffset(date.timeIntervalSince(Date.now))
    }

    func resetClock() {
        setOffset(0)
    }

    private func setOffset(_ offset: TimeInterval) {
        DevMode.timeOffset = offset
        timeOffset = offset
    }

    /// The simulated "now", read through the shared clock.
    var simulatedNow: Date { AppClock.live.now() }
}
#endif
