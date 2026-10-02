import Foundation
import SwiftData
import Testing
@testable import SequoiaCore

/// A small deterministic random source, so rounds are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct PracticeGeneratorTests {
    let library = BundledWordProvider.shared.words
    let generator = PracticeGenerator()

    func round(_ game: PracticeGame, seen: Int, seed: UInt64 = 1) throws -> PracticeRound {
        var rng = SeededGenerator(seed: seed)
        return try generator.round(game, from: Array(library.prefix(seen)), using: &rng).get()
    }

    @Test(arguments: PracticeGame.allCases, [4, 5, 12, 60])
    func roundsAreValid(game: PracticeGame, seen: Int) throws {
        for seed in UInt64(1)...25 {
            let round = try round(game, seen: seen, seed: seed)
            let seenWords = Array(library.prefix(seen))
            #expect(round.questions.count == min(PracticeGenerator.questionsPerRound, seen))
            #expect(Set(round.questions.map(\.word.id)).count == round.questions.count, "no word is asked twice")
            for question in round.questions {
                #expect(question.options.count == PracticeGenerator.optionsPerQuestion)
                #expect(Set(question.options.map { $0.lowercased() }).count == question.options.count, "no duplicate options")
                #expect(seenWords.contains(question.word), "only seen words are asked")
                let optionSource = seenWords.map { PracticeGenerator.optionText($0, game: game) }
                #expect(question.options.allSatisfy(optionSource.contains), "options come only from seen words")
                #expect(question.correctAnswer == PracticeGenerator.optionText(question.word, game: game))
            }
        }
    }

    @Test func definitionMatchAsksTheWord() throws {
        let question = try #require(try round(.definitionMatch, seen: 10).questions.first)
        #expect(question.prompt == question.word.word)
        #expect(question.correctAnswer == question.word.definition)
    }

    @Test func fillTheBlankHidesTheWord() throws {
        for question in try round(.fillTheBlank, seen: 30).questions {
            #expect(question.prompt.contains(PracticeGenerator.blank))
            #expect(!question.prompt.lowercased().contains(" \(question.word.word.lowercased()) "))
            #expect(question.correctAnswer == question.word.word)
        }
    }

    @Test func theArticleBeforeABlankGivesNothingAway() {
        let blank = PracticeGenerator.blank
        #expect(PracticeGenerator.neutralizingArticle(in: "The jury gave an \(blank) verdict.") == "The jury gave a(n) \(blank) verdict.")
        #expect(PracticeGenerator.neutralizingArticle(in: "A \(blank) reply.") == "A(n) \(blank) reply.")
        #expect(PracticeGenerator.neutralizingArticle(in: "Banana \(blank) split.") == "Banana \(blank) split.", "only whole-word articles")
        for word in library {
            guard let sentence = PracticeGenerator.blanked(word) else { continue }
            #expect(!sentence.lowercased().contains(" an \(blank)") && !sentence.lowercased().contains(" a \(blank)"))
        }
    }

    @Test func fillTheBlankPrefersTheSamePartOfSpeech() throws {
        let nouns = library.filter { $0.partOfSpeech == .noun }.prefix(6)
        let verbs = library.filter { $0.partOfSpeech == .verb }.prefix(6)
        var rng = SeededGenerator(seed: 7)
        let round = try generator.round(.fillTheBlank, from: Array(nouns + verbs), using: &rng).get()
        let byWord = Dictionary(uniqueKeysWithValues: (nouns + verbs).map { ($0.word, $0) })
        for question in round.questions {
            let kinds = Set(question.options.compactMap { byWord[$0]?.partOfSpeech })
            #expect(kinds == [question.word.partOfSpeech], "every option fits the sentence grammatically")
        }
    }

    @Test(arguments: [0, 1, 3])
    func tooFewWordsIsAFriendlyFailure(seen: Int) {
        var rng = SeededGenerator(seed: 1)
        for game in PracticeGame.allCases {
            let result = generator.round(game, from: Array(library.prefix(seen)), using: &rng)
            #expect(result == .failure(.tooFewWords(seen: seen, needed: PracticeGenerator.minimumSeenWords - seen)))
        }
    }

    @Test func duplicateWordsDoNotCountTwice() {
        let word = library[0]
        var rng = SeededGenerator(seed: 1)
        let result = generator.round(.definitionMatch, from: [word, word, word, word, library[1]], using: &rng)
        #expect(result == .failure(.tooFewWords(seen: 2, needed: 2)))
    }

    @Test func sameSeedSameRound() throws {
        #expect(try round(.definitionMatch, seen: 20, seed: 42) == round(.definitionMatch, seen: 20, seed: 42))
    }

    @MainActor
    @Test func aCompletedRoundAwardsBonusRings() throws {
        let store = SequoiaStore(container: try Persistence.makeContainer(.inMemory))
        let before = store.growth.totalRings
        let awarded = store.recordPractice(correctAnswers: 4)
        let config = GrowthConfig.standard
        #expect(awarded == config.ringsPerPracticeRound + 4 * config.ringsPerCorrectAnswer)
        #expect(store.growth.totalRings == before + awarded)
        #expect(store.practiceRounds == 1)
    }
}
