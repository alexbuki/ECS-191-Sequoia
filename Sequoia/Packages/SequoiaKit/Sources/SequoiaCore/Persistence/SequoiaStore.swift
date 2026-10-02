import Foundation
import Observation
import SwiftData

/// A word the user has seen, joined with their personal state for it.
public struct SeenWord: Identifiable, Hashable, Sendable {
    public let word: Word
    public let firstSeen: DayStamp
    public let isFavorite: Bool
    public let knewIt: Bool
    public let isCompleted: Bool

    public var id: String { word.id }
}

/// Settings as plain values, for views and other targets.
public struct SettingsSnapshot: Equatable, Sendable {
    public var difficulty: Difficulty
    public var reminderHour: Int
    public var reminderMinute: Int
    public var notificationsEnabled: Bool
    public var streakNudgeEnabled: Bool
    public var hasCompletedOnboarding: Bool
    public var hasRequestedNotificationPermission: Bool

    public static let defaults = SettingsSnapshot(SettingsRecord())

    init(_ record: SettingsRecord) {
        difficulty = record.difficulty
        reminderHour = record.reminderHour
        reminderMinute = record.reminderMinute
        notificationsEnabled = record.notificationsEnabled
        streakNudgeEnabled = record.streakNudgeEnabled
        hasCompletedOnboarding = record.hasCompletedOnboarding
        hasRequestedNotificationPermission = record.hasRequestedNotificationPermission
    }
}

/// The app's single source of truth for user state, backed by SwiftData.
///
/// Every surface (app, widget intents, watch sync, notification actions) goes
/// through the store, which in turn defers all growth rules to `GrowthEngine`.
@MainActor
@Observable
public final class SequoiaStore {
    public let container: ModelContainer
    public let engine: GrowthEngine
    public let selector: DailyWordSelector
    public let provider: any WordProvider
    private let clock: @Sendable () -> AppClock
    private var context: ModelContext

    /// The current growth state, with any missed days already applied.
    public private(set) var growth: GrowthState = .empty
    public private(set) var today: DayStamp
    public private(set) var todayWord: Word
    public private(set) var todayCompleted = false
    public private(set) var settings: SettingsSnapshot = .defaults
    /// Bumped on every change, so derived lists can refresh.
    public private(set) var revision = 0
    /// Called after any change is saved. The app uses it to reload widgets,
    /// reschedule notifications and sync the watch.
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?

    public init(
        container: ModelContainer,
        provider: any WordProvider = BundledWordProvider.shared,
        engine: GrowthEngine = GrowthEngine(),
        clock: @escaping @Sendable () -> AppClock = { .live }
    ) {
        self.container = container
        self.provider = provider
        self.engine = engine
        self.selector = DailyWordSelector(provider: provider)
        self.clock = clock
        self.context = ModelContext(container)
        let day = clock().today()
        self.today = day
        self.todayWord = selector.word(for: day, difficulty: .elevated)
        refresh()
    }

    public var currentClock: AppClock { clock() }
    public var stage: TreeStage { engine.stage(of: growth) }
    public var isStreakAtRisk: Bool { engine.isAtRisk(growth, today: today) }

    // MARK: - Refreshing

    /// Re-reads the clock, applies missed days, and records today's word as seen.
    public func refresh() {
        today = clock().today()
        let settingsRecord = fetchSettings()
        settings = SettingsSnapshot(settingsRecord)

        let progress = fetchProgress()
        let refreshed = engine.refreshed(progress.growthState, today: today)
        if refreshed != progress.growthState {
            progress.growthState = refreshed
        }
        growth = refreshed

        let dayRecord = ensureDayRecord(for: today, difficulty: settingsRecord.difficulty)
        todayWord = provider.word(id: dayRecord.wordID) ?? selector.word(for: today, difficulty: settingsRecord.difficulty)
        todayCompleted = dayRecord.isCompleted
        markSeen(wordID: todayWord.id, on: today)
        save()
    }

    /// Discards cached objects and re-reads the store, picking up writes made
    /// by the widget or a notification action in another process.
    public func reloadFromDisk() {
        context = ModelContext(container)
        refresh()
    }

    /// The word for a day, as recorded, or as it would be selected.
    public func word(for day: DayStamp) -> Word {
        if let record = fetchDayRecord(day), let word = provider.word(id: record.wordID) {
            return word
        }
        return selector.word(for: day, difficulty: settings.difficulty)
    }

    // MARK: - Core loop

    /// Completes today. Safe to call repeatedly: later calls do nothing.
    @discardableResult
    public func checkIn(knewIt: Bool = false) -> CheckInResult {
        refresh()
        let progress = fetchProgress()
        let (next, result) = engine.checkIn(progress.growthState, on: today)
        guard let outcome = result.outcome else { return result }

        progress.growthState = next
        let dayRecord = ensureDayRecord(for: today, difficulty: settings.difficulty)
        dayRecord.completedAt = clock().now()
        dayRecord.ringsEarned = outcome.ringsEarned
        if let wordRecord = fetchWordRecord(dayRecord.wordID) {
            wordRecord.isCompleted = true
            wordRecord.knewIt = wordRecord.knewIt || knewIt
        }
        if outcome.plantedTree {
            context.insert(PlantedTreeRecord(index: next.plantedTrees - 1, plantedDay: today.dayNumber))
        }
        save()
        refresh()
        return result
    }

    /// Bonus rings for a finished practice round. Returns the rings awarded.
    @discardableResult
    public func recordPractice(correctAnswers: Int) -> Int {
        let progress = fetchProgress()
        let (next, rings) = engine.awardPractice(progress.growthState, correctAnswers: correctAnswers)
        progress.growthState = next
        progress.practiceRounds += 1
        save()
        refresh()
        return rings
    }

    // MARK: - Words

    public func isFavorite(_ wordID: String) -> Bool {
        fetchWordRecord(wordID)?.isFavorite ?? false
    }

    public func toggleFavorite(_ wordID: String) {
        let record = fetchWordRecord(wordID) ?? {
            let record = WordRecord(wordID: wordID, firstSeenDay: today.dayNumber)
            context.insert(record)
            return record
        }()
        record.isFavorite.toggle()
        save()
    }

    /// Every word the user has seen, newest first.
    public func seenWords() -> [SeenWord] {
        let descriptor = FetchDescriptor<WordRecord>(sortBy: [SortDescriptor(\.firstSeenDay, order: .reverse)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let word = provider.word(id: record.wordID) else { return nil }
            return SeenWord(
                word: word,
                firstSeen: DayStamp(dayNumber: record.firstSeenDay),
                isFavorite: record.isFavorite,
                knewIt: record.knewIt,
                isCompleted: record.isCompleted
            )
        }
    }

    // MARK: - History & forest

    /// Days that were completed, for the streak calendar.
    public func completedDays() -> Set<DayStamp> {
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.completedAt != nil })
        let records = (try? context.fetch(descriptor)) ?? []
        return Set(records.map(\.day))
    }

    public func plantedTrees() -> [PlantedTreeRecord] {
        let descriptor = FetchDescriptor<PlantedTreeRecord>(sortBy: [SortDescriptor(\.index)])
        return (try? context.fetch(descriptor)) ?? []
    }

    public var practiceRounds: Int { fetchProgress().practiceRounds }

    // MARK: - Settings

    public func updateSettings(_ change: (SettingsRecord) -> Void) {
        let record = fetchSettings()
        let previousDifficulty = record.difficulty
        change(record)
        if record.difficulty != previousDifficulty {
            swapTodayWordIfUnfinished(difficulty: record.difficulty)
        }
        save()
        refresh()
    }

    /// Erases all progress and seen words. Settings are kept.
    public func resetProgress() {
        try? context.delete(model: WordRecord.self)
        try? context.delete(model: DayRecord.self)
        try? context.delete(model: PlantedTreeRecord.self)
        try? context.delete(model: ProgressRecord.self)
        save()
        refresh()
    }

    // MARK: - Developer tools

    #if SEQUOIA_DEV
    /// Plants `count` additional fully grown trees.
    public func devFillForest(adding count: Int) {
        let progress = fetchProgress()
        var state = progress.growthState
        for offset in 0..<max(0, count) {
            let index = state.plantedTrees
            context.insert(PlantedTreeRecord(index: index, plantedDay: today.adding(days: -(count - offset)).dayNumber))
            state.plantedTrees += 1
        }
        progress.growthState = state
        save()
        refresh()
    }

    /// Jumps the in-progress tree to a stage, as if checked in through yesterday.
    public func devJump(to stage: TreeStage) {
        let progress = fetchProgress()
        progress.growthState = engine.jumped(progress.growthState, to: stage, today: today)
        if let record = fetchDayRecord(today) {
            record.completedAt = nil
        }
        save()
        refresh()
    }
    #endif

    // MARK: - Private

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
        revision &+= 1
        onChange?()
    }

    private func fetchSettings() -> SettingsRecord {
        if let existing = try? context.fetch(FetchDescriptor<SettingsRecord>()).first {
            return existing
        }
        let record = SettingsRecord()
        context.insert(record)
        return record
    }

    private func fetchProgress() -> ProgressRecord {
        if let existing = try? context.fetch(FetchDescriptor<ProgressRecord>()).first {
            return existing
        }
        let record = ProgressRecord()
        context.insert(record)
        return record
    }

    private func fetchDayRecord(_ day: DayStamp) -> DayRecord? {
        let number = day.dayNumber
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dayNumber == number })
        return try? context.fetch(descriptor).first
    }

    private func fetchWordRecord(_ wordID: String) -> WordRecord? {
        let descriptor = FetchDescriptor<WordRecord>(predicate: #Predicate { $0.wordID == wordID })
        return try? context.fetch(descriptor).first
    }

    private func ensureDayRecord(for day: DayStamp, difficulty: Difficulty) -> DayRecord {
        if let existing = fetchDayRecord(day) { return existing }
        let record = DayRecord(dayNumber: day.dayNumber, wordID: selector.word(for: day, difficulty: difficulty).id)
        context.insert(record)
        return record
    }

    private func markSeen(wordID: String, on day: DayStamp) {
        guard fetchWordRecord(wordID) == nil else { return }
        context.insert(WordRecord(wordID: wordID, firstSeenDay: day.dayNumber))
    }

    /// A new difficulty takes effect immediately, unless today is already done.
    private func swapTodayWordIfUnfinished(difficulty: Difficulty) {
        guard let record = fetchDayRecord(today), !record.isCompleted else { return }
        let replacement = selector.word(for: today, difficulty: difficulty)
        guard replacement.id != record.wordID else { return }
        if let old = fetchWordRecord(record.wordID), !old.isFavorite, !old.isCompleted, old.firstSeenDay == today.dayNumber {
            context.delete(old)
        }
        record.wordID = replacement.id
    }
}
