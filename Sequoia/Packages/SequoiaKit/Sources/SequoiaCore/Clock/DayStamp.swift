import Foundation

/// A calendar day in the user's local time zone, independent of the time of day.
///
/// Day arithmetic is done on a proleptic-Gregorian day number, so it is never
/// affected by daylight-saving transitions or by the time zone the device is in
/// when the arithmetic happens.
public struct DayStamp: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The local day that contains `date`, using the calendar's time zone.
    public init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Days since 1970-01-01 (Howard Hinnant's `days_from_civil`).
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// Inverse of `dayNumber` (Howard Hinnant's `civil_from_days`).
    public init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    public func adding(days: Int) -> DayStamp {
        DayStamp(dayNumber: dayNumber + days)
    }

    /// Whole days from `other` to `self` (positive when `self` is later).
    public func days(since other: DayStamp) -> Int {
        dayNumber - other.dayNumber
    }

    /// Local midnight at the start of this day.
    public func startDate(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    public static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
