import Foundation

/// How challenging a word is. Users pick a preferred level during onboarding.
public enum Difficulty: Int, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case everyday = 1
    case elevated = 2
    case erudite = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .everyday: String(localized: "Everyday", bundle: .module)
        case .elevated: String(localized: "Elevated", bundle: .module)
        case .erudite: String(localized: "Erudite", bundle: .module)
        }
    }

    public var subtitle: String {
        switch self {
        case .everyday: String(localized: "Useful words you'll hear this week", bundle: .module)
        case .elevated: String(localized: "Sharper words for writing and work", bundle: .module)
        case .erudite: String(localized: "Rare, literary, delightfully precise", bundle: .module)
        }
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
    /// A sample entry for previews and tests.
    static let sample = Word(
        id: "sonder",
        word: "sonder",
        ipa: "/ˈsɑːndər/",
        partOfSpeech: .noun,
        definition: "The realization that each passerby has a life as vivid and complex as your own.",
        examples: [
            "Watching the crowded train platform, she felt a quiet wave of sonder.",
            "Sonder made him kinder to the stranger who cut him off.",
        ],
        etymology: "Coined in 2012 by John Koenig for The Dictionary of Obscure Sorrows.",
        difficulty: .elevated,
        tags: ["emotion", "society"]
    )
}
