import Foundation
import Testing
@testable import SequoiaCore

struct DayStampTests {
    @Test func dayNumberRoundTrips() {
        for n in stride(from: -1000, through: 30_000, by: 37) {
            #expect(DayStamp(dayNumber: n).dayNumber == n)
        }
        #expect(DayStamp(year: 1970, month: 1, day: 1).dayNumber == 0)
        #expect(DayStamp(year: 2024, month: 3, day: 1).days(since: DayStamp(year: 2024, month: 2, day: 28)) == 2)
    }

    @Test func fixedClockReportsLocalDay() throws {
        let tz = try #require(TimeZone(identifier: "America/Los_Angeles"))
        // 2026-10-01 06:30 UTC is still Sept 30 in Los Angeles.
        let date = Date(timeIntervalSince1970: 1_790_836_200)
        #expect(AppClock.fixed(date, timeZone: tz).today() == DayStamp(year: 2026, month: 9, day: 30))
        #expect(AppClock.fixed(date, timeZone: .gmt).today() == DayStamp(year: 2026, month: 10, day: 1))
    }
}
