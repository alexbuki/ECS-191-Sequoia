#if SEQUOIA_DEV
import Foundation

/// Developer-mode switches. This entire file is compiled only when the
/// `SEQUOIA_DEV` flag is set (Debug builds), so Release builds contain none of it.
///
/// Values live in the App Group defaults so the widget and notification
/// scheduling see the same simulated time as the app.
public enum DevMode {
    private enum Key {
        static let enabled = "dev.enabled"
        static let offset = "dev.timeOffset"
    }

    /// The runtime switch. When off, the app behaves exactly like a Release build.
    public static var isEnabled: Bool {
        get { AppGroup.defaults.bool(forKey: Key.enabled) }
        set { AppGroup.defaults.set(newValue, forKey: Key.enabled) }
    }

    /// The stored time offset, applied only while dev mode is enabled.
    public static var timeOffset: TimeInterval {
        get { AppGroup.defaults.double(forKey: Key.offset) }
        set { AppGroup.defaults.set(newValue, forKey: Key.offset) }
    }

    public static var effectiveOffset: TimeInterval {
        isEnabled ? timeOffset : 0
    }
}
#endif
