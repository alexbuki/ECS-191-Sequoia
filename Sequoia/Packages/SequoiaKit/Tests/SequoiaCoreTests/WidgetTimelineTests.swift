import Foundation
import Testing
@testable import SequoiaCore

@MainActor
struct WidgetTimelineTests {
    let clock = TestClock(Date(timeIntervalSince1970: 1_790_850_000)) // 2026-10-01 10:20 UTC

    func makeStore() throws -> SequoiaStore {
        let clock = self.clock
        return SequoiaStore(container: try Persistence.makeContainer(.inMemory), clock: { clock.clock })
    }

    @Test func showsTodayNowAndTomorrowFromMidnight() throws {
        let store = try makeStore()
        let plan = store.widgetTimeline(realOffset: 0)
        let calendar = clock.clock.calendar

        #expect(plan.entries.count == 2)
        let now = try #require(plan.entries.first)
        #expect(now.date == clock.clock.now())
        #expect(now.word == store.todayWord)
        #expect(now.stage == store.stage)
        #expect(!now.isCompleted)

        let midnight = try #require(plan.entries.last)
        let tomorrow = store.today.adding(days: 1)
        #expect(midnight.date == tomorrow.startDate(in: calendar))
        #expect(midnight.day == tomorrow)
        #expect(midnight.word == store.word(for: tomorrow))
        #expect(midnight.word != now.word)
        #expect(!midnight.isCompleted)
        #expect(plan.reloadDate > midnight.date, "reloads after midnight, never before")
    }

    @Test func reflectsACheckInAndKeepsTheStreakOvernight() throws {
        let store = try makeStore()
        store.checkIn()
        let plan = store.widgetTimeline(realOffset: 0)
        #expect(plan.entries[0].isCompleted)
        #expect(plan.entries[0].streak == 1)
        #expect(plan.entries[1].streak == 1, "a completed day keeps the streak through midnight")
        #expect(!plan.entries[1].isCompleted)
    }

    @Test func aStreakAtRiskResetsAtMidnight() throws {
        let store = try makeStore()
        for day in 0..<3 {
            if day > 0 { clock.advance(days: 1); store.refresh() }
            store.checkIn()
        }
        clock.advance(days: 1)
        let plan = store.widgetTimeline(realOffset: 0)
        #expect(plan.entries[0].stage == .sprout)
        #expect(plan.entries[0].streak == 3)
        #expect(plan.entries[1].stage == .seed, "missing today returns the tree to a seed tomorrow")
        #expect(plan.entries[1].streak == 0)
    }

    @Test func entriesAreDatedInRealTimeWhenTheClockIsShifted() throws {
        let store = try makeStore()
        let offset: TimeInterval = 3 * 86_400
        let plan = store.widgetTimeline(realOffset: offset)
        #expect(plan.entries[0].date == clock.clock.now().addingTimeInterval(-offset))
    }
}
