#if SEQUOIA_DEV
import Foundation
import os

/// Measures cold launch to a visible word: from process start (as recorded by
/// the kernel) to the first appearance of the Today word. Developer builds only.
enum LaunchTiming {
    private static var reported = false
    private static let log = Logger(subsystem: "app.sequoia.Sequoia", category: "launch")

    /// Logs the time since process start at a named point (for finding slow steps).
    static func mark(_ name: String) {
        guard !reported, let start = processStart() else { return }
        log.notice("mark \(name, privacy: .public) \(Date().timeIntervalSince(start), format: .fixed(precision: 3), privacy: .public)s")
    }

    static func wordDidAppear() {
        guard !reported, let start = processStart() else { return }
        reported = true
        let elapsed = Date().timeIntervalSince(start)
        log.notice("launch-to-word \(elapsed, format: .fixed(precision: 3), privacy: .public)s")
    }

    private static func processStart() -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let time = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000)
    }
}
#endif
