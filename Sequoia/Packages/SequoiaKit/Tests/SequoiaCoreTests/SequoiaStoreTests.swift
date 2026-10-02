import Foundation
import SwiftData
import Testing
@testable import SequoiaCore

/// A clock the test can move forward.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    let timeZone: TimeZone

    init(_ date: Date, timeZone: TimeZone = .gmt) {
        self.date = date
        self.timeZone = timeZone
    }

    func advance(days: Int) {
        lock.withLock { date = date.addingTimeInterval(TimeInterval(days) * 86_400) }
    }

    var clock: AppClock {
        lock.withLock { AppClock.fixed(date, timeZone: timeZone) }
    }
}

@MainActor
struct SequoiaStoreTests {
    let clock = TestClock(Date(timeIntervalSince1970: 1_790_850_000)) // 2026-10-01 10:20 UTC

    func makeStore(_ container: ModelContainer? = nil) throws -> SequoiaStore {
        let container = try container ?? Persistence.makeContainer(.inMemory)
        let clock = self.clock
        return SequoiaStore(container: container, clock: { clock.clock })
    }

    @Test func showsTodaysDeterministicWordAndMarksItSeen() throws {
        let store = try makeStore()
        let expected = DailyWordSelector().word(for: clock.clock.today(), difficulty: .elevated)
        #expect(store.todayWord == expected)
        #expect(store.seenWords().map(\.id) == [expected.id])
        #expect(!store.todayCompleted)
    }

    @Test func checkInCompletesTheDayOnce() throws {
        let store = try makeStore()
        let first = store.checkIn()
        #expect(first.outcome != nil)
        #expect(store.todayCompleted)
        #expect(store.growth.currentStreak == 1)
        #expect(store.checkIn() == .alreadyCheckedIn)
        #expect(store.growth.totalRings == 10)
        #expect(store.completedDays() == [clock.clock.today()])
    }

    @Test func checkInPersistsAcrossRelaunch() throws {
        let url = URL.temporaryDirectory.appending(path: "store-\(UUID().uuidString).store")
        let config = ModelConfiguration(schema: Persistence.schema, url: url)
        do {
            let store = try makeStore(ModelContainer(for: Persistence.schema, configurations: config))
            store.checkIn()
        }
        let relaunched = try makeStore(ModelContainer(for: Persistence.schema, configurations: config))
        #expect(relaunched.todayCompleted)
        #expect(relaunched.growth.currentStreak == 1)
    }

    @Test func aNewDayBringsANewWordAndAMissedDayResets() throws {
        let store = try makeStore()
        let firstWord = store.todayWord
        store.checkIn()
        clock.advance(days: 1)
        store.refresh()
        #expect(store.todayWord != firstWord)
        #expect(!store.todayCompleted)
        #expect(store.isStreakAtRisk)
        store.checkIn()
        #expect(store.growth.currentStreak == 2)

        clock.advance(days: 2)
        store.refresh()
        #expect(store.growth.currentStreak == 0)
        #expect(store.stage == .seed)
        #expect(store.seenWords().count == 3)
    }

    @Test func plantingCreatesAPermanentTreeRecord() throws {
        let store = try makeStore()
        for _ in 0..<30 {
            store.checkIn()
            clock.advance(days: 1)
        }
        #expect(store.plantedTrees().count == 1)
        clock.advance(days: 5)
        store.refresh()
        #expect(store.plantedTrees().count == 1)
        #expect(store.growth.plantedTrees == 1)
    }

    @Test func favorites() throws {
        let store = try makeStore()
        let id = store.todayWord.id
        #expect(!store.isFavorite(id))
        store.toggleFavorite(id)
        #expect(store.isFavorite(id))
        #expect(store.seenWords().first?.isFavorite == true)
    }

    @Test func changingDifficultySwapsAnUnfinishedWord() throws {
        let store = try makeStore()
        let before = store.todayWord
        store.updateSettings { $0.difficulty = .erudite }
        #expect(store.todayWord.difficulty == .erudite)
        #expect(store.todayWord != before)
        #expect(!store.seenWords().contains { $0.id == before.id })

        store.checkIn()
        let done = store.todayWord
        store.updateSettings { $0.difficulty = .everyday }
        #expect(store.todayWord == done, "a completed day keeps its word")
    }

    @Test func practiceAwardsBonusRings() throws {
        let store = try makeStore()
        let rings = store.recordPractice(correctAnswers: 5)
        #expect(rings == 15)
        #expect(store.growth.totalRings == 15)
        #expect(store.practiceRounds == 1)
    }

    @Test func resetErasesProgressButKeepsSettings() throws {
        let store = try makeStore()
        store.updateSettings { $0.difficulty = .erudite; $0.hasCompletedOnboarding = true }
        store.checkIn()
        store.resetProgress()
        #expect(store.growth.totalRings == 0)
        #expect(!store.todayCompleted)
        #expect(store.settings.difficulty == .erudite)
        #expect(store.settings.hasCompletedOnboarding)
    }

    @Test func onChangeFiresAfterCheckIn() throws {
        let store = try makeStore()
        var calls = 0
        store.onChange = { calls += 1 }
        store.checkIn()
        #expect(calls > 0)
    }
}
