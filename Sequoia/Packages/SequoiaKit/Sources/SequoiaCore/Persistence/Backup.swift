import Foundation
import SwiftData

/// Everything needed to rebuild the user's progress on a fresh install. The app
/// keeps the latest one in iCloud key-value storage (see `CloudBackupService`).
public struct Backup: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public var day: Int
        public var wordID: String
        public var completedAt: Date?
        public var rings: Int
    }

    public struct SeenWordState: Codable, Equatable, Sendable {
        public var id: String
        public var firstSeenDay: Int
        public var isFavorite: Bool
        public var knewIt: Bool
        public var isCompleted: Bool
        public var practiceMisses: Int
    }

    public struct Tree: Codable, Equatable, Sendable {
        public var index: Int
        public var plantedDay: Int
    }

    public struct Progress: Codable, Equatable, Sendable {
        public var currentStreak, longestStreak, treeDays, totalRings, totalCheckIns, plantedTrees: Int
        public var lastCheckInDay: Int?
        public var practiceRounds, bestDefinitionMatch, bestFillTheBlank: Int
        public var rainDays, rainDaysUsed: Int
        public var lastRainDay: Int?
    }

    public struct Settings: Codable, Equatable, Sendable {
        public var difficulty, reminderHour, reminderMinute: Int
        public var notificationsEnabled, streakNudgeEnabled: Bool
    }

    public var progress: Progress
    public var settings: Settings
    public var days: [Day]
    public var words: [SeenWordState]
    public var trees: [Tree]

    public var totalCheckIns: Int { progress.totalCheckIns }

    /// JSON compressed with LZFSE: a year of use is a few kilobytes, far under
    /// the 1 MB key-value storage limit.
    public func encoded() throws -> Data {
        try (JSONEncoder().encode(self) as NSData).compressed(using: .lzfse) as Data
    }

    public init(decoding data: Data) throws {
        let json = try (data as NSData).decompressed(using: .lzfse) as Data
        self = try JSONDecoder().decode(Backup.self, from: json)
    }

    init(progress: Progress, settings: Settings, days: [Day], words: [SeenWordState], trees: [Tree]) {
        self.progress = progress
        self.settings = settings
        self.days = days
        self.words = words
        self.trees = trees
    }
}

extension SequoiaStore {
    /// The user's whole state as a backup.
    public func makeBackup() -> Backup {
        let context = ModelContext(container)
        let p = (try? context.fetch(FetchDescriptor<ProgressRecord>()).first) ?? ProgressRecord()
        let s = (try? context.fetch(FetchDescriptor<SettingsRecord>()).first) ?? SettingsRecord()
        let days = (try? context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.dayNumber)]))) ?? []
        let words = (try? context.fetch(FetchDescriptor<WordRecord>(sortBy: [SortDescriptor(\.firstSeenDay), SortDescriptor(\.wordID)]))) ?? []
        let trees = (try? context.fetch(FetchDescriptor<PlantedTreeRecord>(sortBy: [SortDescriptor(\.index)]))) ?? []
        return Backup(
            progress: .init(currentStreak: p.currentStreak, longestStreak: p.longestStreak, treeDays: p.treeDays,
                            totalRings: p.totalRings, totalCheckIns: p.totalCheckIns, plantedTrees: p.plantedTrees,
                            lastCheckInDay: p.lastCheckInDay, practiceRounds: p.practiceRounds,
                            bestDefinitionMatch: p.bestDefinitionMatch, bestFillTheBlank: p.bestFillTheBlank,
                            rainDays: p.rainDays, rainDaysUsed: p.rainDaysUsed, lastRainDay: p.lastRainDay),
            settings: .init(difficulty: s.difficultyRaw, reminderHour: s.reminderHour, reminderMinute: s.reminderMinute,
                            notificationsEnabled: s.notificationsEnabled, streakNudgeEnabled: s.streakNudgeEnabled),
            days: days.map { .init(day: $0.dayNumber, wordID: $0.wordID, completedAt: $0.completedAt, rings: $0.ringsEarned) },
            words: words.map { .init(id: $0.wordID, firstSeenDay: $0.firstSeenDay, isFavorite: $0.isFavorite,
                                     knewIt: $0.knewIt, isCompleted: $0.isCompleted, practiceMisses: $0.practiceMisses) },
            trees: trees.map { .init(index: $0.index, plantedDay: $0.plantedDay) }
        )
    }

    /// Replaces all progress, seen words and settings with the backup's. Restored
    /// trees don't replay their planting ceremony.
    public func restore(_ backup: Backup) {
        let context = ModelContext(container)
        for model in [WordRecord.self, DayRecord.self, PlantedTreeRecord.self, ProgressRecord.self, SettingsRecord.self] as [any PersistentModel.Type] {
            try? context.delete(model: model)
        }
        let progress = ProgressRecord()
        let p = backup.progress
        progress.currentStreak = p.currentStreak
        progress.longestStreak = p.longestStreak
        progress.treeDays = p.treeDays
        progress.lastCheckInDay = p.lastCheckInDay
        progress.totalRings = p.totalRings
        progress.totalCheckIns = p.totalCheckIns
        progress.plantedTrees = p.plantedTrees
        progress.practiceRounds = p.practiceRounds
        progress.bestDefinitionMatch = p.bestDefinitionMatch
        progress.bestFillTheBlank = p.bestFillTheBlank
        progress.rainDays = p.rainDays
        progress.rainDaysUsed = p.rainDaysUsed
        progress.lastRainDay = p.lastRainDay
        context.insert(progress)

        let settings = SettingsRecord()
        settings.difficultyRaw = backup.settings.difficulty
        settings.reminderHour = backup.settings.reminderHour
        settings.reminderMinute = backup.settings.reminderMinute
        settings.notificationsEnabled = backup.settings.notificationsEnabled
        settings.streakNudgeEnabled = backup.settings.streakNudgeEnabled
        settings.hasCompletedOnboarding = true
        context.insert(settings)

        for day in backup.days {
            let record = DayRecord(dayNumber: day.day, wordID: day.wordID)
            record.completedAt = day.completedAt
            record.ringsEarned = day.rings
            context.insert(record)
        }
        for word in backup.words {
            let record = WordRecord(wordID: word.id, firstSeenDay: word.firstSeenDay)
            record.isFavorite = word.isFavorite
            record.knewIt = word.knewIt
            record.isCompleted = word.isCompleted
            record.practiceMisses = word.practiceMisses
            context.insert(record)
        }
        for tree in backup.trees {
            context.insert(PlantedTreeRecord(index: tree.index, plantedDay: tree.plantedDay, ceremonyShown: true))
        }
        try? context.save()
        reloadFromDisk()
    }
}
