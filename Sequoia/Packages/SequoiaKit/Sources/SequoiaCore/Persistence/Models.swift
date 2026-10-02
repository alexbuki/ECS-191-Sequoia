import Foundation
import SwiftData

/// A word the user has seen, with their personal state for it.
@Model
public final class WordRecord {
    @Attribute(.unique) public var wordID: String
    /// Day number (see `DayStamp.dayNumber`) the word was first shown.
    public var firstSeenDay: Int
    public var isFavorite: Bool
    /// True when the user said "I already knew this."
    public var knewIt: Bool
    public var isCompleted: Bool

    public init(wordID: String, firstSeenDay: Int) {
        self.wordID = wordID
        self.firstSeenDay = firstSeenDay
        self.isFavorite = false
        self.knewIt = false
        self.isCompleted = false
    }
}

/// One calendar day: the word shown and whether the day was completed.
/// Together these rows are the streak history behind the calendar.
@Model
public final class DayRecord {
    @Attribute(.unique) public var dayNumber: Int
    public var wordID: String
    public var completedAt: Date?
    public var ringsEarned: Int

    public init(dayNumber: Int, wordID: String) {
        self.dayNumber = dayNumber
        self.wordID = wordID
        self.completedAt = nil
        self.ringsEarned = 0
    }

    public var day: DayStamp { DayStamp(dayNumber: dayNumber) }
    public var isCompleted: Bool { completedAt != nil }
}

/// A fully grown tree, planted permanently in the forest.
@Model
public final class PlantedTreeRecord {
    @Attribute(.unique) public var index: Int
    public var plantedDay: Int

    public init(index: Int, plantedDay: Int) {
        self.index = index
        self.plantedDay = plantedDay
    }
}

/// The single row holding the growth engine's state.
@Model
public final class ProgressRecord {
    public var currentStreak: Int
    public var longestStreak: Int
    public var treeDays: Int
    public var lastCheckInDay: Int?
    public var totalRings: Int
    public var totalCheckIns: Int
    public var plantedTrees: Int
    public var practiceRounds: Int

    public init() {
        currentStreak = 0
        longestStreak = 0
        treeDays = 0
        lastCheckInDay = nil
        totalRings = 0
        totalCheckIns = 0
        plantedTrees = 0
        practiceRounds = 0
    }

    public var growthState: GrowthState {
        get {
            GrowthState(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                treeDays: treeDays,
                lastCheckInDay: lastCheckInDay.map(DayStamp.init(dayNumber:)),
                totalRings: totalRings,
                totalCheckIns: totalCheckIns,
                plantedTrees: plantedTrees
            )
        }
        set {
            currentStreak = newValue.currentStreak
            longestStreak = newValue.longestStreak
            treeDays = newValue.treeDays
            lastCheckInDay = newValue.lastCheckInDay?.dayNumber
            totalRings = newValue.totalRings
            totalCheckIns = newValue.totalCheckIns
            plantedTrees = newValue.plantedTrees
        }
    }
}

/// The single row of user settings.
@Model
public final class SettingsRecord {
    public var difficultyRaw: Int
    public var reminderHour: Int
    public var reminderMinute: Int
    public var notificationsEnabled: Bool
    public var streakNudgeEnabled: Bool
    public var hasCompletedOnboarding: Bool
    public var hasRequestedNotificationPermission: Bool

    public init() {
        difficultyRaw = Difficulty.elevated.rawValue
        reminderHour = 8
        reminderMinute = 0
        notificationsEnabled = true
        streakNudgeEnabled = true
        hasCompletedOnboarding = false
        hasRequestedNotificationPermission = false
    }

    public var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .elevated }
        set { difficultyRaw = newValue.rawValue }
    }

    public var reminderTime: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }
}
