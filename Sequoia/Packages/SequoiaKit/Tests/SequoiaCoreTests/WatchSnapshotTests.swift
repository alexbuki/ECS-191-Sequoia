import Foundation
import Testing
@testable import SequoiaCore

@MainActor
struct WatchSnapshotTests {
    let clock = TestClock(Date(timeIntervalSince1970: 1_790_850_000)) // 2026-10-01 10:20 UTC

    func makeStore() throws -> SequoiaStore {
        let clock = self.clock
        return SequoiaStore(container: try Persistence.makeContainer(.inMemory), clock: { clock.clock })
    }

    @Test func showsTheSameWordAndTreeAsThePhone() throws {
        let store = try makeStore()
        store.checkIn()
        let snapshot = store.watchSnapshot
        #expect(snapshot.word() == store.todayWord)
        #expect(snapshot.stage() == store.stage)
        #expect(snapshot.growth.currentStreak == store.growth.currentStreak)
        #expect(snapshot.isCompleted)
    }

    @Test func rollsOverToTheSameNextDayAsThePhone() throws {
        let store = try makeStore()
        store.checkIn()
        let synced = store.watchSnapshot
        for days in [1, 2, 5] {
            clock.advance(days: days)
            store.refresh()
            let watch = synced.current(today: store.today)
            #expect(watch == store.watchSnapshot, "after \(days) day(s) the watch agrees without a sync")
        }
    }

    @Test func gotItOnTheWatchMatchesThePhoneCheckIn() throws {
        let store = try makeStore()
        let watch = try #require(store.watchSnapshot.checkingIn())
        store.checkIn()
        #expect(watch == store.watchSnapshot)
        #expect(watch.checkingIn() == nil, "a second Got it changes nothing")
    }

    @Test func aMissedDayResetsTheTreeOnTheWatchToo() throws {
        let store = try makeStore()
        for day in 0..<3 {
            if day > 0 { clock.advance(days: 1); store.refresh() }
            store.checkIn()
        }
        let synced = store.watchSnapshot
        #expect(synced.stage() == .sprout)
        clock.advance(days: 2)
        let watch = synced.current(today: clock.clock.today())
        #expect(watch.stage() == .seed)
        #expect(watch.growth.currentStreak == 0)
        #expect(watch.growth.totalRings == synced.growth.totalRings, "rings are never lost")
    }

    @Test func survivesTheTrip() throws {
        let store = try makeStore()
        store.checkIn()
        let snapshot = store.watchSnapshot
        #expect(WatchSnapshot.decoded(from: snapshot.encoded()) == snapshot)
        #expect(WatchSnapshot.decoded(from: Data("nonsense".utf8)) == nil)
    }

    @Test func beforeTheFirstSyncTheWatchStillShowsTodaysWord() {
        let today = clock.clock.today()
        let initial = WatchSnapshot.initial(today: today)
        #expect(initial.word() == DailyWordSelector().word(for: today, difficulty: .elevated))
        #expect(initial.stage() == .seed)
        #expect(!initial.isCompleted)
    }
}
