import Foundation
import Testing
@testable import SequoiaCore

struct WordLibraryTests {
    let provider: BundledWordProvider

    init() throws {
        provider = try BundledWordProvider()
    }

    @Test func bundledJSONDecodesAtLeastAYearOfWords() {
        #expect(provider.words.count >= 365)
        #expect(Set(provider.words.map(\.id)).count == provider.words.count, "ids must be unique")
    }

    @Test func everyEntryHasRequiredFields() {
        for word in provider.words {
            #expect(!word.id.isEmpty)
            #expect(!word.word.isEmpty)
            #expect(word.ipa.hasPrefix("/") && word.ipa.hasSuffix("/"), "\(word.id) ipa")
            // General American, so no length marks; IPA letters only (j, not y).
            #expect(!word.ipa.contains("ː") && !word.ipa.contains("y"), "\(word.id) ipa \(word.ipa)")
            #expect(!word.definition.isEmpty, "\(word.id) definition")
            #expect((1...2).contains(word.examples.count), "\(word.id) examples")
            #expect(!word.etymology.isEmpty, "\(word.id) etymology")
            #expect(!word.tags.isEmpty, "\(word.id) tags")
        }
    }

    /// Every example uses the exact headword once, so any example can be a fill-the-blank.
    @Test func examplesUseTheWord() throws {
        for word in provider.words {
            // The same matching as PracticeGenerator.blanked.
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word.word) + "\\b"
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            for example in word.examples {
                let matches = regex.numberOfMatches(in: example, range: NSRange(example.startIndex..., in: example))
                #expect(matches == 1, "\(word.id): \(example)")
            }
        }
    }

    @Test func everyDifficultyHasWords() {
        let selector = DailyWordSelector(provider: provider)
        for level in Difficulty.allCases where level != .gre {
            // Five years of words at each level (with a leap day), so a daily
            // user at one level doesn't see a repeat for five years.
            #expect(selector.pool(for: level).count >= 5 * 365 + 1, "\(level)")
        }
    }

    @Test func greSetIsAboutAThousandWordsFromEveryLevel() {
        let pool = DailyWordSelector(provider: provider).pool(for: .gre)
        #expect((1_000...1_100).contains(pool.count))
        for level in Difficulty.allCases where level != .gre {
            #expect(pool.contains { $0.difficulty == level }, "\(level)")
        }
        for id in ["abate", "laconic", "obsequious", "prevaricate", "tacit", "vacillate"] {
            #expect(pool.contains { $0.id == id }, "\(id)")
        }
    }

    @Test func everyWordCanBeAFillTheBlank() {
        for word in provider.words {
            #expect(PracticeGenerator.blanked(word) != nil, "\(word.id) needs an example with the word on its own")
        }
    }

    @Test func sampleWordIsALibraryEntry() {
        #expect(provider.word(id: Word.sample.id) == .sample)
    }

    @Test func lookupById() {
        let first = provider.words[0]
        #expect(provider.word(id: first.id) == first)
        #expect(provider.word(id: "not-a-word") == nil)
    }
}

struct DailyWordSelectorTests {
    let start = DayStamp(year: 2026, month: 1, day: 1)

    @Test(arguments: Difficulty.allCases)
    func sameDateAlwaysYieldsSameWord(difficulty: Difficulty) {
        let a = DailyWordSelector()
        let b = DailyWordSelector(provider: BundledWordProvider.shared)
        for offset in 0..<60 {
            let day = start.adding(days: offset)
            #expect(a.word(for: day, difficulty: difficulty) == b.word(for: day, difficulty: difficulty))
        }
    }

    @Test(arguments: Difficulty.allCases)
    func consecutiveDaysYieldDifferentWords(difficulty: Difficulty) {
        let selector = DailyWordSelector()
        for offset in 0..<400 {
            let today = selector.word(for: start.adding(days: offset), difficulty: difficulty)
            let tomorrow = selector.word(for: start.adding(days: offset + 1), difficulty: difficulty)
            #expect(today != tomorrow)
        }
    }

    @Test(arguments: Difficulty.allCases)
    func difficultyFilteringWorks(difficulty: Difficulty) {
        let selector = DailyWordSelector()
        for offset in 0..<100 {
            #expect(difficulty.includes(selector.word(for: start.adding(days: offset), difficulty: difficulty)))
        }
    }

    @Test func aFullCycleShowsEveryWordOnce() {
        let selector = DailyWordSelector()
        let pool = selector.pool(for: .elevated)
        let seen = (0..<pool.count).map { selector.word(for: start.adding(days: $0), difficulty: .elevated).id }
        #expect(Set(seen).count == pool.count)
    }

    @Test func emptyPoolFallsBackToAnotherLevel() {
        let provider = BundledWordProvider(words: [.sample])
        let selector = DailyWordSelector(provider: provider)
        #expect(selector.word(for: start, difficulty: .erudite) == .sample)
    }

    @Test func theDayChangesAtLocalMidnight() throws {
        let tz = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let beforeMidnight = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59)))
        let afterMidnight = beforeMidnight.addingTimeInterval(120)
        let selector = DailyWordSelector()
        let a = selector.word(for: AppClock.fixed(beforeMidnight, timeZone: tz).today(), difficulty: .everyday)
        let b = selector.word(for: AppClock.fixed(afterMidnight, timeZone: tz).today(), difficulty: .everyday)
        #expect(a != b)
    }
}
