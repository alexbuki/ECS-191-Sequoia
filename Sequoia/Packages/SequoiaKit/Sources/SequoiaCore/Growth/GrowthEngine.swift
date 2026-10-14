import Foundation

/// A snapshot of the user's growth. Pure value; persisted by the store.
public struct GrowthState: Codable, Equatable, Sendable {
    /// Consecutive days checked in, ending on `lastCheckInDay`.
    public var currentStreak: Int
    public var longestStreak: Int
    /// Days of growth in the in-progress tree (0 means a fresh seed).
    public var treeDays: Int
    public var lastCheckInDay: DayStamp?
    /// Running total. Rings never reset.
    public var totalRings: Int
    public var totalCheckIns: Int
    /// Trees planted in the forest. Planted trees are permanent.
    public var plantedTrees: Int
    /// Rain days held, each ready to cover one missed day.
    public var rainDays: Int
    /// Rain days spent over all time.
    public var rainDaysUsed: Int
    /// The day rain days last covered a gap, for a gentle note on Today.
    public var lastRainDay: DayStamp?

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        treeDays: Int = 0,
        lastCheckInDay: DayStamp? = nil,
        totalRings: Int = 0,
        totalCheckIns: Int = 0,
        plantedTrees: Int = 0,
        rainDays: Int = 0,
        rainDaysUsed: Int = 0,
        lastRainDay: DayStamp? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.treeDays = treeDays
        self.lastCheckInDay = lastCheckInDay
        self.totalRings = totalRings
        self.totalCheckIns = totalCheckIns
        self.plantedTrees = plantedTrees
        self.rainDays = rainDays
        self.rainDaysUsed = rainDaysUsed
        self.lastRainDay = lastRainDay
    }

    public static let empty = GrowthState()

    private enum CodingKeys: String, CodingKey {
        case currentStreak, longestStreak, treeDays, lastCheckInDay, totalRings, totalCheckIns, plantedTrees
        case rainDays, rainDaysUsed, lastRainDay
    }

    /// Decodes state saved before rain days existed (the watch keeps a copy).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        treeDays = try container.decode(Int.self, forKey: .treeDays)
        lastCheckInDay = try container.decodeIfPresent(DayStamp.self, forKey: .lastCheckInDay)
        totalRings = try container.decode(Int.self, forKey: .totalRings)
        totalCheckIns = try container.decode(Int.self, forKey: .totalCheckIns)
        plantedTrees = try container.decode(Int.self, forKey: .plantedTrees)
        rainDays = try container.decodeIfPresent(Int.self, forKey: .rainDays) ?? 0
        rainDaysUsed = try container.decodeIfPresent(Int.self, forKey: .rainDaysUsed) ?? 0
        lastRainDay = try container.decodeIfPresent(DayStamp.self, forKey: .lastRainDay)
    }
}

/// What happened during a check-in, for animation, haptics and copy.
public struct CheckInOutcome: Equatable, Sendable {
    public var previousStage: TreeStage
    /// The stage reached by this check-in (`.grownSequoia` when a tree was planted).
    public var reachedStage: TreeStage
    public var ringsEarned: Int
    public var plantedTree: Bool
    public var streak: Int
    /// True when a missed day reset the streak before this check-in.
    public var streakWasReset: Bool
    /// True when this check-in earned a rain day.
    public var earnedRainDay: Bool = false
    /// True when this was the first check-in ever and it planted the welcome
    /// tree. The in-progress tree keeps growing (it isn't reset to a seed).
    public var plantedWelcomeTree: Bool = false

    public var stageChanged: Bool { reachedStage != previousStage }
}

public enum CheckInResult: Equatable, Sendable {
    /// The day was already complete. Nothing changed.
    case alreadyCheckedIn
    case checkedIn(CheckInOutcome)

    public var outcome: CheckInOutcome? {
        if case .checkedIn(let outcome) = self { outcome } else { nil }
    }
}

/// Owns streaks, tree stages, planting and rings. Pure Swift with no UI or
/// storage dependencies: every function takes a state and returns a new one.
public struct GrowthEngine: Sendable {
    public let config: GrowthConfig

    public init(config: GrowthConfig = .standard) {
        self.config = config
    }

    /// The stage of a tree that has grown for `treeDays` days. Day 0 is a fresh seed.
    public func stage(forTreeDays treeDays: Int) -> TreeStage {
        var stage = TreeStage.seed
        for threshold in config.stageThresholds where treeDays >= threshold.day {
            stage = threshold.stage
        }
        return stage
    }

    public func stage(of state: GrowthState) -> TreeStage {
        stage(forTreeDays: state.treeDays)
    }

    /// Whether `day` is already complete.
    public func hasCheckedIn(_ state: GrowthState, on day: DayStamp) -> Bool {
        guard let last = state.lastCheckInDay else { return false }
        return last >= day
    }

    /// Whole days missed between the last check-in and `today`.
    public func missedDays(_ state: GrowthState, today: DayStamp) -> Int {
        guard let last = state.lastCheckInDay else { return 0 }
        return max(0, today.days(since: last) - 1)
    }

    /// Whether the streak has lapsed by `today`: more days were missed than
    /// the rain days held can cover.
    public func isLapsed(_ state: GrowthState, today: DayStamp) -> Bool {
        missedDays(state, today: today) > state.rainDays
    }

    /// The streak is alive but today's check-in hasn't happened yet.
    public func isAtRisk(_ state: GrowthState, today: DayStamp) -> Bool {
        state.currentStreak > 0 && !hasCheckedIn(state, on: today) && !isLapsed(state, today: today)
    }

    /// Whether checking in on `day` would grow the in-progress tree to full
    /// size and plant it.
    public func checkInPlantsTree(_ state: GrowthState, on day: DayStamp) -> Bool {
        guard !hasCheckedIn(state, on: day) else { return false }
        if plantsWelcomeTree(state) { return true }
        return refreshed(state, today: day).treeDays + 1 >= config.daysToFullGrowth
    }

    /// Whether the next check-in is the first ever and plants the welcome tree.
    public func plantsWelcomeTree(_ state: GrowthState) -> Bool {
        config.plantsWelcomeTree && state.totalCheckIns == 0 && state.plantedTrees == 0
    }

    /// Applies any missed days. Rain days cover them when there are enough,
    /// keeping the streak and tree (without growing them); otherwise the streak
    /// and in-progress tree reset to a seed and the rain days stay saved.
    /// Planted trees and rings are untouched.
    public func refreshed(_ state: GrowthState, today: DayStamp) -> GrowthState {
        let missed = missedDays(state, today: today)
        guard missed > 0 else { return state }
        var next = state
        if missed <= state.rainDays {
            next.rainDays -= missed
            next.rainDaysUsed += missed
            next.lastRainDay = today
            // The gap is covered, as if checked in through yesterday.
            next.lastCheckInDay = today.adding(days: -1)
            return next
        }
        guard state.currentStreak > 0 || state.treeDays > 0 else { return state }
        next.currentStreak = 0
        next.treeDays = 0
        return next
    }

    /// Checks in for `day`. Checking in twice on the same day, or for a day
    /// before the last check-in (a backwards clock or time-zone change), is a no-op.
    public func checkIn(_ state: GrowthState, on day: DayStamp) -> (GrowthState, CheckInResult) {
        if hasCheckedIn(state, on: day) {
            return (state, .alreadyCheckedIn)
        }

        let wasReset = isLapsed(state, today: day) && state.currentStreak > 0
        let welcome = plantsWelcomeTree(state)
        var next = refreshed(state, today: day)
        let previousStage = stage(of: next)

        next.currentStreak += 1
        next.longestStreak = max(next.longestStreak, next.currentStreak)
        next.treeDays += 1
        next.totalCheckIns += 1
        next.lastCheckInDay = day

        var earnedRainDay = false
        if config.rainDayEvery > 0, next.currentStreak % config.rainDayEvery == 0, next.rainDays < config.maxRainDays {
            next.rainDays += 1
            earnedRainDay = true
        }

        var rings = config.ringsPerCheckIn
        let reached = stage(of: next)
        if reached > previousStage {
            rings += config.milestoneReward(for: reached)
        }

        var planted = false
        if next.treeDays >= config.daysToFullGrowth {
            planted = true
            next.plantedTrees += 1
            next.treeDays = 0
        } else if welcome {
            planted = true
            next.plantedTrees += 1
        }

        next.totalRings += rings
        let outcome = CheckInOutcome(
            previousStage: previousStage,
            reachedStage: reached,
            ringsEarned: rings,
            plantedTree: planted,
            streak: next.currentStreak,
            streakWasReset: wasReset,
            earnedRainDay: earnedRainDay,
            plantedWelcomeTree: welcome && planted && next.treeDays > 0
        )
        return (next, .checkedIn(outcome))
    }

    /// Bonus rings for finishing a practice round.
    public func awardPractice(_ state: GrowthState, correctAnswers: Int) -> (GrowthState, Int) {
        let rings = config.ringsPerPracticeRound + max(0, correctAnswers) * config.ringsPerCorrectAnswer
        var next = state
        next.totalRings += rings
        return (next, rings)
    }

    /// Days of check-ins until the in-progress tree reaches its next stage.
    public func daysUntilNextStage(_ state: GrowthState) -> Int? {
        let current = stage(of: state)
        guard let next = config.stageThresholds.first(where: { $0.stage > current && $0.day > state.treeDays }) else {
            return nil
        }
        return next.day - state.treeDays
    }

    /// The state after jumping the in-progress tree to `stage` (developer tool).
    public func jumped(_ state: GrowthState, to stage: TreeStage, today: DayStamp) -> GrowthState {
        var next = state
        next.treeDays = config.threshold(for: stage)
        next.currentStreak = max(next.currentStreak, next.treeDays)
        next.longestStreak = max(next.longestStreak, next.currentStreak)
        next.lastCheckInDay = today.adding(days: -1)
        return next
    }
}
