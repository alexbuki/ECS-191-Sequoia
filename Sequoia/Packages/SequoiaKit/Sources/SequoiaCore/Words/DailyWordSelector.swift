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
                .filter { $0.difficulty == difficulty }
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
