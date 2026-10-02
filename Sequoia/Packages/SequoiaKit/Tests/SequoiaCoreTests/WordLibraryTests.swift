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
            #expect(!word.definition.isEmpty, "\(word.id) definition")
            #expect((1...2).contains(word.examples.count), "\(word.id) examples")
            #expect(!word.etymology.isEmpty, "\(word.id) etymology")
            #expect(!word.tags.isEmpty, "\(word.id) tags")
        }
    }

    @Test func examplesUseTheWord() {
        for word in provider.words {
            for example in word.examples {
                #expect(example.localizedCaseInsensitiveContains(word.word), "\(word.id): \(example)")
            }
        }
    }

    @Test func everyDifficultyHasWords() {
        let selector = DailyWordSelector(provider: provider)
        for level in Difficulty.allCases {
            #expect(selector.pool(for: level).count >= 100, "\(level)")
        }
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
            #expect(selector.word(for: start.adding(days: offset), difficulty: difficulty).difficulty == difficulty)
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
