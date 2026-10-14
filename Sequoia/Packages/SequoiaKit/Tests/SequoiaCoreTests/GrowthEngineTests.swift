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

    @Test func knowsWhichCheckInPlantsTheTree() {
        let days = engine.config.daysToFullGrowth
        let (almost, _) = checkIns(days - 1, from: day1)
        let plantingDay = day1.adding(days: days - 1)
        #expect(engine.checkInPlantsTree(almost, on: plantingDay))
        #expect(engine.checkInPlantsTree(almost, on: plantingDay.adding(days: 1)), "a rain day covers one missed day")
        #expect(!engine.checkInPlantsTree(almost, on: plantingDay.adding(days: 3)), "three missed days reset the tree")
        let (planted, result) = engine.checkIn(almost, on: plantingDay)
        #expect(result.outcome?.plantedTree == true)
        #expect(!engine.checkInPlantsTree(planted, on: plantingDay), "already done today")
        #expect(engine.checkInPlantsTree(.empty, on: day1), "the first check-in plants the welcome tree")
        let (welcomed, _) = engine.checkIn(.empty, on: day1)
        #expect(!engine.checkInPlantsTree(welcomed, on: day1.adding(days: 1)))
    }

    @Test func firstCheckIn() throws {
        let (state, result) = engine.checkIn(.empty, on: day1)
        let outcome = try #require(result.outcome)
        #expect(state.currentStreak == 1)
        #expect(state.longestStreak == 1)
        #expect(state.treeDays == 1)
        #expect(state.totalRings == 15, "10 for the check-in, 5 for sprouting")
        #expect(state.lastCheckInDay == day1)
        #expect(outcome.reachedStage == .sprout, "the first word visibly grows the seed")
        #expect(outcome.plantedTree && outcome.plantedWelcomeTree)
        #expect(state.plantedTrees == 1)
        #expect(!outcome.streakWasReset)
    }

    @Test func theWelcomeTreeIsPlantedOnlyOnce() {
        let (state, outcomes) = checkIns(29, from: day1)
        #expect(outcomes.filter(\.plantedTree).count == 1)
        #expect(outcomes.filter(\.plantedWelcomeTree).count == 1)
        #expect(state.plantedTrees == 1)
        #expect(state.treeDays == 29, "the next tree started growing with the first word")
        // A lapsed streak doesn't bring another welcome tree.
        let (after, result) = engine.checkIn(state, on: day1.adding(days: 40))
        #expect(result.outcome?.plantedTree == false)
        #expect(after.plantedTrees == 1)
    }

    @Test func theWelcomeTreeCanBeTurnedOff() throws {
        var config = GrowthConfig.standard
        config.plantsWelcomeTree = false
        let (state, result) = GrowthEngine(config: config).checkIn(.empty, on: day1)
        #expect(try #require(result.outcome).plantedTree == false)
        #expect(state.plantedTrees == 0)
    }

    @Test func consecutiveDaysBuildTheStreak() {
        let (state, _) = checkIns(5, from: day1)
        #expect(state.currentStreak == 5)
        #expect(state.longestStreak == 5)
        #expect(state.treeDays == 5)
        #expect(state.totalCheckIns == 5)
    }

    @Test(arguments: [(0, TreeStage.seed), (1, .sprout), (2, .sprout), (3, .sprout), (6, .sprout), (7, .sapling),
                      (13, .sapling), (14, .youngSequoia), (29, .youngSequoia)])
    func stageThresholds(days: Int, expected: TreeStage) {
        let (state, _) = checkIns(days, from: day1)
        #expect(engine.stage(of: state) == expected)
    }

    @Test func everyStageIsReachedOnItsThresholdDay() {
        let (_, outcomes) = checkIns(30, from: day1)
        let changes = outcomes.enumerated().filter { $0.element.stageChanged }.map { ($0.offset + 1, $0.element.reachedStage) }
        #expect(changes.map(\.0) == [1, 7, 14, 30])
        #expect(changes.map(\.1) == [.sprout, .sapling, .youngSequoia, .grownSequoia])
    }

    @Test func fullGrowthPlantsTheTreeAndStartsANewSeed() throws {
        let (state, outcomes) = checkIns(30, from: day1)
        let last = try #require(outcomes.last)
        #expect(last.plantedTree)
        #expect(last.reachedStage == .grownSequoia)
        #expect(state.plantedTrees == 2, "the welcome tree and the first grown one")
        #expect(state.treeDays == 0)
        #expect(engine.stage(of: state) == .seed)
        #expect(state.currentStreak == 30, "the streak keeps going after planting")

        let (after, _) = checkIns(1, from: day1.adding(days: 30), state: state)
        #expect(after.treeDays == 1)
        #expect(after.currentStreak == 31)
        #expect(after.plantedTrees == 2)
    }

    @Test func sixtyDaysPlantsTwoTrees() {
        let (state, outcomes) = checkIns(60, from: day1)
        #expect(state.plantedTrees == 3, "the welcome tree and two grown ones")
        #expect(outcomes.filter(\.plantedTree).count == 3)
    }

    @Test func missedDayResetsStreakAndTreeButNotForest() throws {
        let (grown, _) = checkIns(40, from: day1) // one tree planted, 10 days into the next
        #expect(grown.plantedTrees == 2)
        #expect(grown.treeDays == 10)

        let lastDay = day1.adding(days: 39)
        // Three full days missed: more than the two rain days held can cover.
        let skipped = lastDay.adding(days: 4)
        #expect(engine.isLapsed(grown, today: skipped))

        let refreshed = engine.refreshed(grown, today: skipped)
        #expect(refreshed.currentStreak == 0)
        #expect(refreshed.treeDays == 0)
        #expect(refreshed.plantedTrees == 2)
        #expect(refreshed.totalRings == grown.totalRings)
        #expect(refreshed.longestStreak == 40)

        let (after, result) = engine.checkIn(grown, on: skipped)
        let outcome = try #require(result.outcome)
        #expect(outcome.streakWasReset)
        #expect(after.currentStreak == 1)
        #expect(after.treeDays == 1)
        #expect(after.plantedTrees == 2)
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
        #expect(after.totalRings == state.totalRings + 10 + 5, "the new seed sprouts again")
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

    @Test func aRainDayIsEarnedEveryWeekUpToTheCap() {
        let (week, outcomes) = checkIns(7, from: day1)
        #expect(week.rainDays == 1)
        #expect(outcomes.map(\.earnedRainDay) == Array(repeating: false, count: 6) + [true])
        let (month, _) = checkIns(28, from: day1)
        #expect(month.rainDays == engine.config.maxRainDays, "held rain days are capped")
    }

    @Test func aRainDayCoversAMissedDay() throws {
        let (week, _) = checkIns(8, from: day1)
        let skipped = day1.adding(days: 9) // day 9 of the run is missed
        let refreshed = engine.refreshed(week, today: skipped)
        #expect(refreshed.currentStreak == 8 && refreshed.treeDays == 8, "streak and tree survive")
        #expect(refreshed.rainDays == 0 && refreshed.rainDaysUsed == 1)
        #expect(refreshed.lastRainDay == skipped)
        #expect(engine.refreshed(refreshed, today: skipped) == refreshed, "spent once, not every refresh")
        let (after, result) = engine.checkIn(week, on: skipped)
        #expect(after.currentStreak == 9, "a covered day doesn't count, but the streak goes on")
        #expect(result.outcome?.streakWasReset == false)
    }

    @Test func tooManyMissedDaysResetEvenWithRainDaysHeld() {
        let (week, _) = checkIns(7, from: day1) // one rain day held
        let refreshed = engine.refreshed(week, today: day1.adding(days: 9)) // two days missed
        #expect(refreshed.currentStreak == 0 && refreshed.treeDays == 0)
        #expect(refreshed.rainDays == 1, "unspent rain days are kept for later")
        #expect(refreshed.plantedTrees == week.plantedTrees && refreshed.totalRings == week.totalRings)
    }

    @Test func twoRainDaysCoverTwoMissedDays() {
        let (twoWeeks, _) = checkIns(14, from: day1)
        #expect(twoWeeks.rainDays == 2)
        let refreshed = engine.refreshed(twoWeeks, today: day1.adding(days: 16))
        #expect(refreshed.currentStreak == 14 && refreshed.rainDays == 0)
    }

    @Test func rainDaysAcrossMidnightInAnotherTimeZone() throws {
        let tz = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let (week, _) = checkIns(7, from: day1)
        let last = day1.adding(days: 6)
        let lastDate = last.startDate(in: calendar)
        // 00:01 two days later in Tokyo: exactly one day missed, covered.
        let justAfter = lastDate.addingTimeInterval(2 * 86_400 + 60)
        let today = AppClock.fixed(justAfter, timeZone: tz).today()
        #expect(today == last.adding(days: 2))
        #expect(engine.refreshed(week, today: today).currentStreak == 7)
    }

    @Test func oldSavedStateDecodesWithoutRainDays() throws {
        let json = #"{"currentStreak":3,"longestStreak":5,"treeDays":3,"totalRings":40,"totalCheckIns":9,"plantedTrees":0}"#
        let state = try JSONDecoder().decode(GrowthState.self, from: Data(json.utf8))
        #expect(state.currentStreak == 3 && state.rainDays == 0 && state.lastRainDay == nil)
    }

    @Test func thresholdsComeFromConfiguration() {
        let quick = GrowthEngine(config: GrowthConfig(
            stageThresholds: [.init(.seed, day: 1), .init(.sprout, day: 2), .init(.sapling, day: 3),
                              .init(.youngSequoia, day: 4), .init(.grownSequoia, day: 5)],
            ringsPerCheckIn: 1, ringsPerPracticeRound: 0, ringsPerCorrectAnswer: 0, milestoneRings: [], rainDayEvery: 0, maxRainDays: 0))
        var state = GrowthState.empty
        for offset in 0..<5 { state = quick.checkIn(state, on: day1.adding(days: offset)).0 }
        #expect(state.plantedTrees == 1)
        #expect(state.totalRings == 5)
    }

    @Test func daysUntilNextStage() {
        let (state, _) = checkIns(4, from: day1)
        #expect(engine.daysUntilNextStage(state) == 3)
        #expect(engine.daysUntilNextStage(.empty) == 1)
    }

    @Test func jumpingToAStage() {
        let jumped = engine.jumped(.empty, to: .youngSequoia, today: day1)
        #expect(engine.stage(of: jumped) == .youngSequoia)
        #expect(!engine.hasCheckedIn(jumped, on: day1))
    }
}
