import Foundation
import Observation
import SequoiaCore

/// State and actions for a practice round.
@MainActor
@Observable
final class PracticeViewModel {
    enum Phase: Equatable {
        case menu
        case playing(PracticeRound)
        case finished(correct: Int, total: Int, rings: Int)
    }

    let store: SequoiaStore
    private let generator = PracticeGenerator()

    private(set) var phase: Phase = .menu
    private(set) var questionIndex = 0
    /// The option picked for the current question, once answered.
    private(set) var selectedIndex: Int?
    private(set) var correctCount = 0
    /// Incremented on each answer, to trigger a soft haptic.
    private(set) var answerCount = 0

    init(store: SequoiaStore) {
        self.store = store
    }

    var seenCount: Int {
        _ = store.revision
        return store.seenWords().count
    }

    /// Words still needed before practice opens, or nil once it is open.
    var wordsToGo: Int? {
        let missing = PracticeGenerator.minimumSeenWords - seenCount
        return missing > 0 ? missing : nil
    }

    var currentQuestion: PracticeQuestion? {
        guard case .playing(let round) = phase, round.questions.indices.contains(questionIndex) else { return nil }
        return round.questions[questionIndex]
    }

    var questionCount: Int {
        guard case .playing(let round) = phase else { return 0 }
        return round.questions.count
    }

    var isLastQuestion: Bool { questionIndex == questionCount - 1 }

    func start(_ game: PracticeGame) {
        guard case .success(let round) = generator.round(game, from: store.seenWords().map(\.word)) else { return }
        questionIndex = 0
        selectedIndex = nil
        correctCount = 0
        phase = .playing(round)
    }

    func choose(_ index: Int) {
        guard selectedIndex == nil, let question = currentQuestion else { return }
        selectedIndex = index
        answerCount += 1
        if index == question.correctIndex { correctCount += 1 }
    }

    func next() {
        guard selectedIndex != nil else { return }
        if isLastQuestion {
            let rings = store.recordPractice(correctAnswers: correctCount)
            phase = .finished(correct: correctCount, total: questionCount, rings: rings)
        } else {
            questionIndex += 1
            selectedIndex = nil
        }
    }

    func backToMenu() {
        phase = .menu
        selectedIndex = nil
    }
}
