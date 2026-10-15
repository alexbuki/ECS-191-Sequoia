import Foundation

/// Picks the word for a day, deterministically by date and difficulty, so the
/// app, widgets and watch always agree on today's word without a network.
public struct DailyWordSelector: Sendable {
    private let pools: [Difficulty: [Word]]

    public init(provider: any WordProvider = BundledWordProvider.shared) {
        var pools: [Difficulty: [Word]] = [:]
        for difficulty in Difficulty.allCases {
            // A fixed pseudo-random order, so neighbouring days feel unrelated
            // while staying identical on every device and every launch.
            pools[difficulty] = provider.words
                .filter { difficulty.includes($0) }
                .sorted { StableHash.of($0.id) < StableHash.of($1.id) }
        }
        self.pools = pools
    }

    /// The ordered pool of words for a difficulty.
    public func pool(for difficulty: Difficulty) -> [Word] {
        pools[difficulty] ?? []
    }

    /// The word for `day` at `difficulty`. Falls back to other levels if a pool is empty.
    public func word(for day: DayStamp, difficulty: Difficulty) -> Word {
        let candidates = [difficulty] + Difficulty.allCases.filter { $0 != difficulty }
        for level in candidates {
            let pool = pool(for: level)
            if !pool.isEmpty {
                let index = ((day.dayNumber % pool.count) + pool.count) % pool.count
                return pool[index]
            }
        }
        return .sample
    }

    /// The word for `day`, skipping words already seen (by id) until every word
    /// at that level has been seen, then starting over in the same order. The
    /// same day, level and seen words always give the same word, so every
    /// device that shares the seen words agrees.
    public func word(for day: DayStamp, difficulty: Difficulty, excluding seen: Set<String>) -> Word {
        let candidates = [difficulty] + Difficulty.allCases.filter { $0 != difficulty }
        for level in candidates {
            let pool = pool(for: level)
            guard !pool.isEmpty else { continue }
            let start = ((day.dayNumber % pool.count) + pool.count) % pool.count
            for step in 0..<pool.count where !seen.contains(pool[(start + step) % pool.count].id) {
                return pool[(start + step) % pool.count]
            }
            return pool[start]
        }
        return .sample
    }

    /// The words for `count` days starting at `day`, each day's word counting
    /// as seen for the days after it.
    public func words(from day: DayStamp, count: Int, difficulty: Difficulty, excluding seen: Set<String>) -> [Word] {
        var seen = seen
        return (0..<max(0, count)).map { offset in
            let word = word(for: day.adding(days: offset), difficulty: difficulty, excluding: seen)
            seen.insert(word.id)
            return word
        }
    }
}

/// FNV-1a: unlike `hashValue`, it is identical across launches and processes.
enum StableHash {
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
