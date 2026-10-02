import Foundation

/// The two practice games. Both use only words the user has already seen.
public enum PracticeGame: String, CaseIterable, Identifiable, Sendable {
    /// Choose the definition of a word from four options.
    case definitionMatch
    /// Complete an example sentence with the right word.
    case fillTheBlank

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .definitionMatch: String(localized: "Definition Match", bundle: .module)
        case .fillTheBlank: String(localized: "Fill the Blank", bundle: .module)
        }
    }

    public var subtitle: String {
        switch self {
        case .definitionMatch: String(localized: "Pick the meaning of each word.", bundle: .module)
        case .fillTheBlank: String(localized: "Finish each sentence with the right word.", bundle: .module)
        }
    }
}

/// One multiple-choice question.
public struct PracticeQuestion: Identifiable, Equatable, Sendable {
    public let id: Int
    /// The word being practiced.
    public let word: Word
    /// The word itself (Definition Match) or a sentence with a blank (Fill the Blank).
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int

    public var correctAnswer: String { options[correctIndex] }
}

/// A short round of questions.
public struct PracticeRound: Equatable, Sendable {
    public let game: PracticeGame
    public let questions: [PracticeQuestion]
}

/// Why a round couldn't be made.
public enum PracticeUnavailable: Equatable, Sendable, Error {
    /// Fewer seen words than a question needs options. `needed` more to go.
    case tooFewWords(seen: Int, needed: Int)
}

/// Builds practice rounds from the words a user has seen.
public struct PracticeGenerator: Sendable {
    public static let questionsPerRound = 5
    public static let optionsPerQuestion = 4
    /// The blank shown in Fill the Blank sentences.
    public static let blank = "_____"

    public init() {}

    /// Words needed before practice opens: one per answer option.
    public static var minimumSeenWords: Int { optionsPerQuestion }

    public func round(
        _ game: PracticeGame,
        from seen: [Word],
        using generator: inout some RandomNumberGenerator
    ) -> Result<PracticeRound, PracticeUnavailable> {
        // A word can only appear once per round, and options must be distinct text.
        let unique = Self.deduplicated(seen, by: game)
        let eligible = game == .fillTheBlank ? unique.filter { Self.blanked($0) != nil } : unique
        guard unique.count >= Self.optionsPerQuestion, !eligible.isEmpty else {
            return .failure(.tooFewWords(seen: unique.count, needed: max(1, Self.optionsPerQuestion - unique.count)))
        }

        let answers = Array(eligible.shuffled(using: &generator).prefix(Self.questionsPerRound))
        let questions = answers.enumerated().map { index, word in
            question(index, game: game, answer: word, pool: unique, using: &generator)
        }
        return .success(PracticeRound(game: game, questions: questions))
    }

    /// Convenience using the system random source.
    public func round(_ game: PracticeGame, from seen: [Word]) -> Result<PracticeRound, PracticeUnavailable> {
        var generator = SystemRandomNumberGenerator()
        return round(game, from: seen, using: &generator)
    }

    private func question(
        _ index: Int, game: PracticeGame, answer: Word, pool: [Word],
        using generator: inout some RandomNumberGenerator
    ) -> PracticeQuestion {
        let others = pool.filter { $0.id != answer.id }.shuffled(using: &generator)
        // For sentences, prefer distractors of the same part of speech so every
        // option reads plausibly; fall back to any other seen word.
        let ordered = game == .fillTheBlank
            ? others.filter { $0.partOfSpeech == answer.partOfSpeech } + others.filter { $0.partOfSpeech != answer.partOfSpeech }
            : others
        let distractors = ordered.prefix(Self.optionsPerQuestion - 1)
        let options = ([answer] + distractors).shuffled(using: &generator)
        let text = options.map { Self.optionText($0, game: game) }
        return PracticeQuestion(
            id: index,
            word: answer,
            prompt: game == .definitionMatch ? answer.word : (Self.blanked(answer) ?? answer.word),
            options: text,
            correctIndex: options.firstIndex(of: answer) ?? 0
        )
    }

    static func optionText(_ word: Word, game: PracticeGame) -> String {
        game == .definitionMatch ? word.definition : word.word
    }

    /// Drops words whose option text would repeat another's (case-insensitively).
    static func deduplicated(_ words: [Word], by game: PracticeGame) -> [Word] {
        var seenText = Set<String>()
        var seenIDs = Set<String>()
        return words.filter { word in
            let key = optionText(word, game: game).lowercased()
            guard !seenText.contains(key), !seenIDs.contains(word.id) else { return false }
            seenText.insert(key)
            seenIDs.insert(word.id)
            return true
        }
    }

    /// "a _____" or "an _____" would give the answer away, so the article
    /// before a blank becomes "a(n)".
    static func neutralizingArticle(in sentence: String) -> String {
        let pattern = "\\b([Aa])n? " + NSRegularExpression.escapedPattern(for: blank)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return sentence }
        let range = NSRange(sentence.startIndex..., in: sentence)
        return regex.stringByReplacingMatches(in: sentence, range: range, withTemplate: "$1(n) " + blank)
    }

    /// The first example sentence with the word replaced by a blank, if any
    /// example contains the word on its own.
    static func blanked(_ word: Word) -> String? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word.word) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        for example in word.examples {
            let range = NSRange(example.startIndex..., in: example)
            if regex.firstMatch(in: example, range: range) != nil {
                let blanked = regex.stringByReplacingMatches(in: example, range: range, withTemplate: blank)
                return neutralizingArticle(in: blanked)
            }
        }
        return nil
    }
}
