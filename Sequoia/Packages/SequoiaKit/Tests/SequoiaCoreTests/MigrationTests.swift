import Foundation
import SwiftData
import Testing
@testable import SequoiaCore

/// The models as first shipped (version 1.0), to check that a store saved by
/// that version opens with today's models and keeps the user's data.
enum ShippedModels {
    @Model final class WordRecord {
        @Attribute(.unique) var wordID: String
        var firstSeenDay: Int
        var isFavorite: Bool
        var knewIt: Bool
        var isCompleted: Bool
        init(wordID: String, firstSeenDay: Int) {
            self.wordID = wordID; self.firstSeenDay = firstSeenDay
            isFavorite = true; knewIt = false; isCompleted = true
        }
    }

    @Model final class DayRecord {
        @Attribute(.unique) var dayNumber: Int
        var wordID: String
        var completedAt: Date?
        var ringsEarned: Int
        init(dayNumber: Int, wordID: String) {
            self.dayNumber = dayNumber; self.wordID = wordID; completedAt = .now; ringsEarned = 10
        }
    }

    @Model final class PlantedTreeRecord {
        @Attribute(.unique) var index: Int
        var plantedDay: Int
        init(index: Int, plantedDay: Int) { self.index = index; self.plantedDay = plantedDay }
    }

    @Model final class ProgressRecord {
        var currentStreak = 5
        var longestStreak = 40
        var treeDays = 5
        var lastCheckInDay: Int?
        var totalRings = 900
        var totalCheckIns = 45
        var plantedTrees = 1
        var practiceRounds = 3
        init(lastCheckInDay: Int) { self.lastCheckInDay = lastCheckInDay }
    }

    @Model final class SettingsRecord {
        var difficultyRaw = 3
        var reminderHour = 9
        var reminderMinute = 15
        var notificationsEnabled = true
        var streakNudgeEnabled = false
        var hasCompletedOnboarding = true
        var hasRequestedNotificationPermission = true
        init() {}
    }

    static let schema = Schema([WordRecord.self, DayRecord.self, PlantedTreeRecord.self, ProgressRecord.self, SettingsRecord.self])
}

@MainActor
struct MigrationTests {
    @Test func aStoreFromTheFirstVersionOpensWithItsDataIntact() throws {
        let url = URL.temporaryDirectory.appending(path: "shipped-\(UUID().uuidString).store")
        let today = AppClock.live.today().dayNumber
        do {
            let old = try ModelContainer(for: ShippedModels.schema, configurations: ModelConfiguration(schema: ShippedModels.schema, url: url))
            let context = ModelContext(old)
            context.insert(ShippedModels.WordRecord(wordID: "abate", firstSeenDay: today - 1))
            context.insert(ShippedModels.DayRecord(dayNumber: today - 1, wordID: "abate"))
            context.insert(ShippedModels.PlantedTreeRecord(index: 0, plantedDay: today - 6))
            context.insert(ShippedModels.ProgressRecord(lastCheckInDay: today - 1))
            context.insert(ShippedModels.SettingsRecord())
            try context.save()
        }
        let container = try ModelContainer(for: Persistence.schema, configurations: ModelConfiguration(schema: Persistence.schema, url: url))
        let store = SequoiaStore(container: container)
        #expect(store.growth.currentStreak == 5 && store.growth.totalRings == 900 && store.growth.plantedTrees == 1)
        #expect(store.growth.rainDays == 0)
        #expect(store.settings.difficulty == .erudite && store.settings.reminderHour == 9)
        #expect(store.isFavorite("abate"))
        #expect(store.plantedTrees().count == 1)
        #expect(store.treesAwaitingCeremony().isEmpty, "trees planted before the update don't replay their ceremony")
        #expect(store.wordsToRevisit().isEmpty)
        #expect(store.bestScore(for: .definitionMatch) == 0)
    }
}
