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
    /// The phone's words for the days after `day`, in order. The phone skips
    /// words already seen, which the watch can't know, so it sends them ahead.
    public var upcomingWordIDs: [String]?

    /// Days of words sent ahead, so the watch agrees through a week without a sync.
    public static let upcomingDays = 7

    public init(day: DayStamp, wordID: String, difficulty: Difficulty, growth: GrowthState, isCompleted: Bool,
                upcomingWordIDs: [String]? = nil) {
        self.day = day
        self.wordID = wordID
        self.difficulty = difficulty
        self.growth = growth
        self.isCompleted = isCompleted
        self.upcomingWordIDs = upcomingWordIDs
    }

    /// Before the phone has synced: today's word at the default difficulty and a new seed.
    public static func initial(today: DayStamp, selector: DailyWordSelector = DailyWordSelector()) -> WatchSnapshot {
        let difficulty = SettingsSnapshot.defaults.difficulty
        return WatchSnapshot(day: today, wordID: selector.word(for: today, difficulty: difficulty).id,
                             difficulty: difficulty, growth: .empty, isCompleted: false)
    }

    /// The snapshot as of `today`: a new day brings the word the phone sent
    /// ahead for it (or the deterministic one past those) and applies any
    /// missed days, exactly as the phone will.
    public func current(
        today: DayStamp, engine: GrowthEngine = GrowthEngine(), selector: DailyWordSelector = DailyWordSelector()
    ) -> WatchSnapshot {
        guard today > day else { return self }
        let ahead = today.days(since: day)
        let upcoming = upcomingWordIDs ?? []
        let wordID = upcoming.indices.contains(ahead - 1)
            ? upcoming[ahead - 1]
            : selector.word(for: today, difficulty: difficulty).id
        return WatchSnapshot(
            day: today,
            wordID: wordID,
            difficulty: difficulty,
            growth: engine.refreshed(growth, today: today),
            isCompleted: engine.hasCheckedIn(growth, on: today),
            upcomingWordIDs: Array(upcoming.dropFirst(ahead))
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

    /// Completing this day plants the tree. The watch leaves that to the
    /// iPhone, so the planting is seen in the app.
    public func plantsTree(engine: GrowthEngine = GrowthEngine()) -> Bool {
        !isCompleted && engine.checkInPlantsTree(growth, on: day)
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
                      growth: growth, isCompleted: todayCompleted,
                      upcomingWordIDs: upcomingWords(count: WatchSnapshot.upcomingDays).map(\.id))
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
