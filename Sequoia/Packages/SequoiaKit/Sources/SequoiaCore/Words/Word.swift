import Foundation

/// How challenging a word is. Users pick a preferred level on their first word or in Settings.
public enum Difficulty: Int, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case everyday = 1
    case elevated = 2
    case erudite = 3
    /// Not a difficulty of its own: the ~1,000 words most worth knowing for
    /// the GRE, drawn from all three levels (words tagged `gre`).
    case gre = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .everyday: String(localized: "Everyday", bundle: .module)
        case .elevated: String(localized: "Elevated", bundle: .module)
        case .erudite: String(localized: "Erudite", bundle: .module)
        case .gre: String(localized: "GRE", bundle: .module)
        }
    }

    public var subtitle: String {
        switch self {
        case .everyday: String(localized: "Useful words you'll hear this week", bundle: .module)
        case .elevated: String(localized: "Sharper words for writing and work", bundle: .module)
        case .erudite: String(localized: "Rare, literary, delightfully precise", bundle: .module)
        case .gre: String(localized: "Words common in GRE prep", bundle: .module)
        }
    }

    /// The tag that puts a word in the GRE set.
    public static let greTag = "gre"

    /// Whether a word belongs in this level's daily pool.
    public func includes(_ word: Word) -> Bool {
        self == .gre ? word.tags.contains(Self.greTag) : word.difficulty == self
    }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PartOfSpeech: String, Codable, Sendable, CaseIterable {
    case noun, verb, adjective, adverb

    public var title: String {
        switch self {
        case .noun: String(localized: "noun", bundle: .module)
        case .verb: String(localized: "verb", bundle: .module)
        case .adjective: String(localized: "adjective", bundle: .module)
        case .adverb: String(localized: "adverb", bundle: .module)
        }
    }
}

/// One entry in the word library.
public struct Word: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let word: String
    public let ipa: String
    public let partOfSpeech: PartOfSpeech
    public let definition: String
    public let examples: [String]
    public let etymology: String
    public let difficulty: Difficulty
    public let tags: [String]

    public init(
        id: String,
        word: String,
        ipa: String,
        partOfSpeech: PartOfSpeech,
        definition: String,
        examples: [String],
        etymology: String,
        difficulty: Difficulty,
        tags: [String]
    ) {
        self.id = id
        self.word = word
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.examples = examples
        self.etymology = etymology
        self.difficulty = difficulty
        self.tags = tags
    }
}

public extension Word {
    /// A sample entry for previews and tests, identical to the library entry.
    static let sample = Word(
        id: "verdant",
        word: "verdant",
        ipa: "/ˈvɜrdənt/",
        partOfSpeech: .adjective,
        definition: "Green with lush plant growth.",
        examples: [
            "After the rains, the hills turned verdant.",
            "They hiked through a verdant valley.",
        ],
        etymology: "Perhaps from Old French verdeant, from Latin viridis 'green'.",
        difficulty: .elevated,
        tags: ["nature"]
    )
}
