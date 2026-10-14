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
        #expect(store.growth.totalRings == 15, "10 for the check-in, 5 for sprouting")
        #expect(store.completedDays() == [clock.clock.today()])
    }

    @Test func aPlantedTreeRemembersTheWordsThatGrewIt() throws {
        let store = try makeStore()
        // A missed day first, so only the final unbroken run grows the tree.
        store.checkIn()
        let firstWord = store.todayWord.id
        clock.advance(days: 2)
        var expected: [String] = []
        for day in 0..<store.engine.config.daysToFullGrowth {
            if day > 0 { clock.advance(days: 1) }
            store.refresh()
            expected.append(store.todayWord.id)
            store.checkIn()
        }
        let trees = store.plantedTrees()
        #expect(trees.count == 2)
        let welcome = try #require(trees.first)
        #expect(store.isWelcomeTree(welcome))
        #expect(store.words(grownInto: welcome).map(\.id) == [firstWord], "the first word planted the welcome tree")
        let tree = try #require(trees.last)
        #expect(!store.isWelcomeTree(tree))
        #expect(store.words(grownInto: tree).map(\.id) == expected)
    }

    @Test func everyPlantedTreeAwaitsItsCeremonyOnce() throws {
        let store = try makeStore()
        for day in 0..<store.engine.config.daysToFullGrowth {
            if day > 0 { clock.advance(days: 1) }
            store.refresh()
            // The first day plants the welcome tree; the last plants the grown one.
            #expect(store.todayPlantsTree == (day == 0 || day == store.engine.config.daysToFullGrowth - 1))
            store.checkIn()
        }
        #expect(!store.todayPlantsTree)
        #expect(store.treesAwaitingCeremony().map(\.index) == [0, 1])
        store.markCeremoniesShown()
        #expect(store.treesAwaitingCeremony().isEmpty)
        #expect(store.plantedTrees().count == 2)
    }

    @Test func noWordRepeatsUntilTheWholeLevelHasBeenSeen() throws {
        let store = try makeStore()
        let poolSize = store.selector.pool(for: .elevated).count
        var shown: [String] = []
        for day in 0..<poolSize {
            if day > 0 { clock.advance(days: 1) }
            store.refresh()
            // Switching levels back and forth doesn't bring back seen words either.
            if day == poolSize / 3 { store.updateSettings { $0.difficulty = .erudite } }
            if day == poolSize / 3 + 5 { store.updateSettings { $0.difficulty = .elevated } }
            shown.append(store.todayWord.id)
        }
        #expect(Set(shown).count == shown.count)
    }

    @Test func tomorrowsWordIsKnownInAdvance() throws {
        let store = try makeStore()
        let predicted = store.upcomingWords(count: 3).map(\.id)
        #expect(store.word(for: store.today.adding(days: 2)).id == predicted[1])
        var actual: [String] = []
        for _ in 0..<3 {
            clock.advance(days: 1)
            store.refresh()
            actual.append(store.todayWord.id)
        }
        #expect(actual == predicted)
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
        #expect(store.plantedTrees().count == 2, "the welcome tree and the grown one")
        clock.advance(days: 5)
        store.refresh()
        #expect(store.plantedTrees().count == 2)
        #expect(store.growth.plantedTrees == 2)
    }

    @Test func favorites() throws {
        let store = try makeStore()
        let id = store.todayWord.id
        #expect(!store.isFavorite(id))
        #expect(store.favoriteCount == 0)
        store.toggleFavorite(id)
        #expect(store.isFavorite(id))
        #expect(store.seenWords().first?.isFavorite == true)
        #expect(store.favoriteCount == 1)
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
