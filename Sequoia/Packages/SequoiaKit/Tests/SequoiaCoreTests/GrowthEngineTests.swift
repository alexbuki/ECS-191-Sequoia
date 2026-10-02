import Foundation
import Testing
@testable import SequoiaCore

struct GrowthEngineTests {
    let engine = GrowthEngine()
    let day1 = DayStamp(year: 2026, month: 10, day: 1)

    /// Checks in on `count` consecutive days starting at `start`.
    func checkIns(_ count: Int, from start: DayStamp, state: GrowthState = .empty) -> (GrowthState, [CheckInOutcome]) {
        var state = state
        var outcomes: [CheckInOutcome] = []
        for offset in 0..<count {
            let (next, result) = engine.checkIn(state, on: start.adding(days: offset))
            state = next
            if let outcome = result.outcome { outcomes.append(outcome) }
        }
        return (state, outcomes)
    }

    @Test func firstUseIsAnUnplantedSeed() {
        let state = GrowthState.empty
        #expect(engine.stage(of: state) == .seed)
        #expect(!engine.hasCheckedIn(state, on: day1))
        #expect(!engine.isAtRisk(state, today: day1))
        #expect(engine.refreshed(state, today: day1) == state)
    }

    @Test func firstCheckIn() throws {
        let (state, result) = engine.checkIn(.empty, on: day1)
        let outcome = try #require(result.outcome)
        #expect(state.currentStreak == 1)
        #expect(state.longestStreak == 1)
        #expect(state.treeDays == 1)
        #expect(state.totalRings == 10)
        #expect(state.lastCheckInDay == day1)
        #expect(outcome.reachedStage == .seed)
        #expect(!outcome.plantedTree)
        #expect(!outcome.streakWasReset)
    }

    @Test func consecutiveDaysBuildTheStreak() {
        let (state, _) = checkIns(5, from: day1)
        #expect(state.currentStreak == 5)
        #expect(state.longestStreak == 5)
        #expect(state.treeDays == 5)
        #expect(state.totalCheckIns == 5)
    }

    @Test(arguments: [(1, TreeStage.seed), (2, .seed), (3, .sprout), (6, .sprout), (7, .sapling),
                      (13, .sapling), (14, .youngSequoia), (29, .youngSequoia)])
    func stageThresholds(days: Int, expected: TreeStage) {
        let (state, _) = checkIns(days, from: day1)
        #expect(engine.stage(of: state) == expected)
    }

    @Test func everyStageIsReachedOnItsThresholdDay() {
        let (_, outcomes) = checkIns(30, from: day1)
        let changes = outcomes.enumerated().filter { $0.element.stageChanged }.map { ($0.offset + 1, $0.element.reachedStage) }
        #expect(changes.map(\.0) == [3, 7, 14, 30])
        #expect(changes.map(\.1) == [.sprout, .sapling, .youngSequoia, .grownSequoia])
    }

    @Test func fullGrowthPlantsTheTreeAndStartsANewSeed() throws {
        let (state, outcomes) = checkIns(30, from: day1)
        let last = try #require(outcomes.last)
        #expect(last.plantedTree)
        #expect(last.reachedStage == .grownSequoia)
        #expect(state.plantedTrees == 1)
        #expect(state.treeDays == 0)
        #expect(engine.stage(of: state) == .seed)
        #expect(state.currentStreak == 30, "the streak keeps going after planting")

        let (after, _) = checkIns(1, from: day1.adding(days: 30), state: state)
        #expect(after.treeDays == 1)
        #expect(after.currentStreak == 31)
        #expect(after.plantedTrees == 1)
    }

    @Test func sixtyDaysPlantsTwoTrees() {
        let (state, outcomes) = checkIns(60, from: day1)
        #expect(state.plantedTrees == 2)
        #expect(outcomes.filter(\.plantedTree).count == 2)
    }

    @Test func missedDayResetsStreakAndTreeButNotForest() throws {
        let (grown, _) = checkIns(40, from: day1) // one tree planted, 10 days into the next
        #expect(grown.plantedTrees == 1)
        #expect(grown.treeDays == 10)

        let lastDay = day1.adding(days: 39)
        let skipped = lastDay.adding(days: 2) // one full day missed
        #expect(engine.isLapsed(grown, today: skipped))

        let refreshed = engine.refreshed(grown, today: skipped)
        #expect(refreshed.currentStreak == 0)
        #expect(refreshed.treeDays == 0)
        #expect(refreshed.plantedTrees == 1)
        #expect(refreshed.totalRings == grown.totalRings)
        #expect(refreshed.longestStreak == 40)

        let (after, result) = engine.checkIn(grown, on: skipped)
        let outcome = try #require(result.outcome)
        #expect(outcome.streakWasReset)
        #expect(after.currentStreak == 1)
        #expect(after.treeDays == 1)
        #expect(after.plantedTrees == 1)
        #expect(after.longestStreak == 40)
    }

    @Test func yesterdayIsAtRiskNotLapsed() {
        let (state, _) = checkIns(4, from: day1)
        let tomorrow = day1.adding(days: 4)
        #expect(engine.isAtRisk(state, today: tomorrow))
        #expect(!engine.isLapsed(state, today: tomorrow))
        #expect(engine.refreshed(state, today: tomorrow) == state)
        #expect(!engine.isAtRisk(state, today: day1.adding(days: 3)), "already checked in today")
    }

    @Test func multipleCheckInsOnTheSameDayDoNotDoubleCount() {
        let (once, _) = engine.checkIn(.empty, on: day1)
        let (twice, result) = engine.checkIn(once, on: day1)
        #expect(result == .alreadyCheckedIn)
        #expect(twice == once)
    }

    @Test func aBackwardsClockDoesNotCount() {
        let (state, _) = checkIns(3, from: day1)
        let (after, result) = engine.checkIn(state, on: day1)
        #expect(result == .alreadyCheckedIn)
        #expect(after == state)
    }

    @Test func ringTotals() {
        // 30 days: 30 × 10 + milestones 5 + 10 + 20 + 50.
        let (state, outcomes) = checkIns(30, from: day1)
        #expect(state.totalRings == 300 + 85)
        #expect(outcomes.map(\.ringsEarned).reduce(0, +) == state.totalRings)

        let (practiced, bonus) = engine.awardPractice(state, correctAnswers: 4)
        #expect(bonus == 5 + 4 * 2)
        #expect(practiced.totalRings == state.totalRings + bonus)
    }

    @Test func ringsNeverResetOnAMissedDay() {
        let (state, _) = checkIns(5, from: day1)
        let (after, _) = engine.checkIn(state, on: day1.adding(days: 10))
        #expect(after.totalRings == state.totalRings + 10)
    }

    @Test func checkInsJustBeforeAndAfterMidnightAreConsecutiveDays() throws {
        let tz = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let lateNight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 23, minute: 59, second: 30)))
        let justAfter = lateNight.addingTimeInterval(60)
        let a = AppClock.fixed(lateNight, timeZone: tz).today()
        let b = AppClock.fixed(justAfter, timeZone: tz).today()
        #expect(b.days(since: a) == 1)

        let (first, _) = engine.checkIn(.empty, on: a)
        let (second, result) = engine.checkIn(first, on: b)
        #expect(result.outcome != nil)
        #expect(second.currentStreak == 2)
    }

    @Test func travellingWestDoesNotDoubleCount() throws {
        // Check in at 00:30 in Tokyo (still the previous day in Los Angeles), then
        // fly to Los Angeles: the same instant maps to an earlier local day.
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let instant = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 0, minute: 30)))
        let tokyoDay = AppClock.fixed(instant, timeZone: tokyo).today()
        let laDay = AppClock.fixed(instant.addingTimeInterval(3600), timeZone: la).today()
        #expect(laDay < tokyoDay)

        let (state, _) = engine.checkIn(.empty, on: tokyoDay)
        let (after, result) = engine.checkIn(state, on: laDay)
        #expect(result == .alreadyCheckedIn)
        #expect(after.currentStreak == 1)
    }

    @Test func daylightSavingDayDoesNotBreakTheStreak() throws {
        // US clocks spring forward on 2026-03-08: that day is only 23 hours long.
        let tz = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 21)))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 7)))
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 30)))
        var state = GrowthState.empty
        for date in [saturday, sunday, monday] {
            state = engine.checkIn(state, on: AppClock.fixed(date, timeZone: tz).today()).0
        }
        #expect(state.currentStreak == 3)
    }

    @Test func graceDaysAreConfigurable() {
        var config = GrowthConfig.standard
        config.graceDays = 1
        let lenient = GrowthEngine(config: config)
        let (state, _) = lenient.checkIn(.empty, on: day1)
        let (after, _) = lenient.checkIn(state, on: day1.adding(days: 2))
        #expect(after.currentStreak == 2, "one rain day protects the streak")
    }

    @Test func thresholdsComeFromConfiguration() {
        let quick = GrowthEngine(config: GrowthConfig(
            stageThresholds: [.init(.seed, day: 1), .init(.sprout, day: 2), .init(.sapling, day: 3),
                              .init(.youngSequoia, day: 4), .init(.grownSequoia, day: 5)],
            ringsPerCheckIn: 1, ringsPerPracticeRound: 0, ringsPerCorrectAnswer: 0, milestoneRings: [], graceDays: 0))
        var state = GrowthState.empty
        for offset in 0..<5 { state = quick.checkIn(state, on: day1.adding(days: offset)).0 }
        #expect(state.plantedTrees == 1)
        #expect(state.totalRings == 5)
    }

    @Test func daysUntilNextStage() {
        let (state, _) = checkIns(4, from: day1)
        #expect(engine.daysUntilNextStage(state) == 3)
        #expect(engine.daysUntilNextStage(.empty) == 3)
    }

    @Test func jumpingToAStage() {
        let jumped = engine.jumped(.empty, to: .youngSequoia, today: day1)
        #expect(engine.stage(of: jumped) == .youngSequoia)
        #expect(!engine.hasCheckedIn(jumped, on: day1))
    }
}
