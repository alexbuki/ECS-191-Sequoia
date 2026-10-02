import Foundation

/// The single source of "now" for every time-dependent component.
///
/// Nothing in Sequoia calls `Date()` directly. In developer builds the live
/// clock can carry a time offset so features can be tested without waiting.
public struct AppClock: Sendable {
    public let calendar: Calendar
    private let provider: @Sendable () -> Date

    public init(calendar: Calendar = .autoupdatingCurrent, now: @escaping @Sendable () -> Date) {
        self.calendar = calendar
        self.provider = now
    }

    public func now() -> Date { provider() }

    public func today() -> DayStamp { DayStamp(date: now(), calendar: calendar) }

    /// The next local midnight after the current time.
    public func nextMidnight() -> Date {
        today().adding(days: 1).startDate(in: calendar)
    }

    /// The real clock, shifted by the developer offset when dev mode is on.
    public static var live: AppClock {
        AppClock { Date().addingTimeInterval(AppClock.developerOffset) }
    }

    /// A clock frozen at `date`, used by tests and previews.
    public static func fixed(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> AppClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return AppClock(calendar: calendar) { date }
    }

    /// Seconds the live clock is shifted from real time.
    public static var developerOffset: TimeInterval {
        #if SEQUOIA_DEV
        DevMode.effectiveOffset
        #else
        0
        #endif
    }
}
