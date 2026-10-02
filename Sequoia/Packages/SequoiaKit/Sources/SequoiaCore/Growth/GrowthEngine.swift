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

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        treeDays: Int = 0,
        lastCheckInDay: DayStamp? = nil,
        totalRings: Int = 0,
        totalCheckIns: Int = 0,
        plantedTrees: Int = 0
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.treeDays = treeDays
        self.lastCheckInDay = lastCheckInDay
        self.totalRings = totalRings
        self.totalCheckIns = totalCheckIns
        self.plantedTrees = plantedTrees
    }

    public static let empty = GrowthState()
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

    /// Whether the streak has lapsed by `today`: a full day was missed.
    public func isLapsed(_ state: GrowthState, today: DayStamp) -> Bool {
        guard let last = state.lastCheckInDay else { return false }
        return today.days(since: last) > 1 + config.graceDays
    }

    /// The streak is alive but today's check-in hasn't happened yet.
    public func isAtRisk(_ state: GrowthState, today: DayStamp) -> Bool {
        state.currentStreak > 0 && !hasCheckedIn(state, on: today) && !isLapsed(state, today: today)
    }

    /// Applies any missed days: the streak and in-progress tree reset to a seed.
    /// Planted trees and rings are untouched.
    public func refreshed(_ state: GrowthState, today: DayStamp) -> GrowthState {
        guard isLapsed(state, today: today) else { return state }
        var next = state
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
        var next = refreshed(state, today: day)
        let previousStage = stage(of: next)

        next.currentStreak += 1
        next.longestStreak = max(next.longestStreak, next.currentStreak)
        next.treeDays += 1
        next.totalCheckIns += 1
        next.lastCheckInDay = day

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
        }

        next.totalRings += rings
        let outcome = CheckInOutcome(
            previousStage: previousStage,
            reachedStage: reached,
            ringsEarned: rings,
            plantedTree: planted,
            streak: next.currentStreak,
            streakWasReset: wasReset
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
