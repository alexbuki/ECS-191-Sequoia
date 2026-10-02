import Foundation

/// The state the iPhone shares with the watch over WatchConnectivity.
///
/// It carries growth state rather than a finished picture, so the watch can
/// roll over to a new day on its own and apply "Got it" instantly with the same
/// `GrowthEngine` rules the phone uses. The phone stays the source of truth.
public struct WatchSnapshot: Codable, Equatable, Sendable {
    public var day: DayStamp
    public var wordID: String
    public var difficulty: Difficulty
    public var growth: GrowthState
    public var isCompleted: Bool

    public init(day: DayStamp, wordID: String, difficulty: Difficulty, growth: GrowthState, isCompleted: Bool) {
        self.day = day
        self.wordID = wordID
        self.difficulty = difficulty
        self.growth = growth
        self.isCompleted = isCompleted
    }

    /// Before the phone has synced: today's word at the default difficulty and a new seed.
    public static func initial(today: DayStamp, selector: DailyWordSelector = DailyWordSelector()) -> WatchSnapshot {
        let difficulty = SettingsSnapshot.defaults.difficulty
        return WatchSnapshot(day: today, wordID: selector.word(for: today, difficulty: difficulty).id,
                             difficulty: difficulty, growth: .empty, isCompleted: false)
    }

    /// The snapshot as of `today`: a new day brings its deterministic word and
    /// applies any missed days, exactly as the phone will.
    public func current(
        today: DayStamp, engine: GrowthEngine = GrowthEngine(), selector: DailyWordSelector = DailyWordSelector()
    ) -> WatchSnapshot {
        guard today > day else { return self }
        return WatchSnapshot(
            day: today,
            wordID: selector.word(for: today, difficulty: difficulty).id,
            difficulty: difficulty,
            growth: engine.refreshed(growth, today: today),
            isCompleted: engine.hasCheckedIn(growth, on: today)
        )
    }

    /// The snapshot after checking in on `day`, or nil if that changes nothing
    /// (already done, or a stale day).
    public func checkingIn(engine: GrowthEngine = GrowthEngine()) -> WatchSnapshot? {
        let (next, result) = engine.checkIn(growth, on: day)
        guard result.outcome != nil else { return nil }
        var snapshot = self
        snapshot.growth = next
        snapshot.isCompleted = true
        return snapshot
    }

    public func word(provider: any WordProvider = BundledWordProvider.shared, selector: DailyWordSelector = DailyWordSelector()) -> Word {
        provider.word(id: wordID) ?? selector.word(for: day, difficulty: difficulty)
    }

    public func stage(engine: GrowthEngine = GrowthEngine()) -> TreeStage {
        engine.stage(of: growth)
    }

    // MARK: Transport

    /// The application-context key the snapshot travels under.
    public static let contextKey = "snapshot"
    /// The message key for a "Got it" from the watch; its value is the day number.
    public static let gotItKey = "gotIt"

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decoded(from data: Data?) -> WatchSnapshot? {
        data.flatMap { try? JSONDecoder().decode(WatchSnapshot.self, from: $0) }
    }
}

extension SequoiaStore {
    /// What the watch should show right now.
    public var watchSnapshot: WatchSnapshot {
        WatchSnapshot(day: today, wordID: todayWord.id, difficulty: settings.difficulty,
                      growth: growth, isCompleted: todayCompleted)
    }
}

/// Where the watch app keeps the latest snapshot, shared with its complications
/// through the watch's App Group.
public enum WatchSnapshotStore {
    private static let key = "watch.snapshot"

    public static func load(defaults: UserDefaults = AppGroup.defaults) -> WatchSnapshot? {
        WatchSnapshot.decoded(from: defaults.data(forKey: key))
    }

    public static func save(_ snapshot: WatchSnapshot, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(snapshot.encoded(), forKey: key)
    }

    /// What to show right now: the saved snapshot rolled over to today, or a
    /// fresh start before the first sync.
    public static func current(clock: AppClock = .live, defaults: UserDefaults = AppGroup.defaults) -> WatchSnapshot {
        let today = clock.today()
        return load(defaults: defaults)?.current(today: today) ?? .initial(today: today)
    }
}
