import SwiftUI
import DesignSystem
import SequoiaCore

/// Short games that reinforce words the user has already seen.
struct PracticeView: View {
    @State private var model: PracticeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: SequoiaStore) {
        _model = State(initialValue: PracticeViewModel(store: store))
    }

    /// Pushed from Library (no navigation stack of its own).
    var body: some View {
        Group {
            switch model.phase {
            case .menu: menu
            case .playing: playing
            case .finished(let correct, let total, _): finished(correct: correct, total: total)
            }
        }
        .animation(reduceMotion ? Theme.Motion.fade : Theme.Motion.settle, value: model.phase)
        .sequoiaScreen()
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: model.answerCount)
    }

    // MARK: Menu

    @ViewBuilder
    private var menu: some View {
        if let toGo = model.wordsToGo {
            CalmEmptyState(
                "Practice opens soon",
                message: "Games use only words you've learned. Come back after ^[\(toGo) more word](inflect: true).",
                systemImage: "leaf"
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("practiceLocked")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    fernCard
                    Text("A quick round of \(PracticeGenerator.questionsPerRound) questions from the \(model.seenCount) words you've seen.")
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                    ForEach(PracticeGame.allCases) { game in
                        Button { model.start(game) } label: {
                            GameCard(game: game, best: model.practiceRounds > 0 ? model.bestScore(for: game) : nil)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("practiceGame-\(game.rawValue)")
                    }
                    if model.revisitCount > 0 {
                        Label(model.revisitCount == 1
                              ? String(localized: "Rounds start with a word you missed.")
                              : String(localized: "Rounds start with \(min(model.revisitCount, PracticeGenerator.maxRevisitsPerRound)) of the \(model.revisitCount) words you missed."),
                              systemImage: "arrow.uturn.backward")
                            .font(Typography.callout)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                            .accessibilityIdentifier("practiceRevisit")
                    }
                }
                .padding(Theme.Spacing.m)
            }
        }
    }

    /// Rounds played, shown as the ferns they grow in the forest.
    private var fernCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            FernBed(ferns: model.practiceRounds)
                .frame(height: 64)
            Text(model.practiceRounds == 0
                 ? String(localized: "Each round you finish grows a fern in your forest.")
                 : model.practiceRounds == 1
                    ? String(localized: "1 round played. Its fern grows in your forest.")
                    : String(localized: "\(model.practiceRounds) rounds played. Their ferns grow in your forest."))
                .font(Typography.callout)
                .foregroundStyle(Theme.Palette.soil)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("practiceFerns")
    }

    // MARK: Playing

    @ViewBuilder
    private var playing: some View {
        if let question = model.currentQuestion {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    ProgressView(value: Double(model.questionIndex + (model.selectedIndex == nil ? 0 : 1)), total: Double(model.questionCount))
                        .tint(Theme.Palette.canopy)
                        .accessibilityHidden(true)
                    Text("Question \(model.questionIndex + 1) of \(model.questionCount)")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .textCase(.uppercase)
                    prompt(for: question)
                    VStack(spacing: Theme.Spacing.s) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            OptionButton(
                                text: option,
                                state: optionState(index, question: question)
                            ) { model.choose(index) }
                            .accessibilityIdentifier("practiceOption-\(index)")
                        }
                    }
                }
                .padding(Theme.Spacing.m)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                if model.selectedIndex != nil {
                    Button(model.isLastQuestion ? "See results" : "Next") { model.next() }
                        .buttonStyle(.sequoiaPrimary)
                        .accessibilityIdentifier("practiceNext")
                        .padding(Theme.Spacing.m)
                        .transition(.opacity)
                }
            }
            .id(question.id)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
    }

    @ViewBuilder
    private func prompt(for question: PracticeQuestion) -> some View {
        switch model.phaseGame {
        case .definitionMatch:
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("What does this word mean?")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                Text(question.prompt)
                    .font(Typography.wordHero)
                    .foregroundStyle(Theme.Palette.soil)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("practicePrompt")
            }
        case .fillTheBlank, nil:
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Which word completes the sentence?")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                Text(question.prompt)
                    .font(Typography.quote)
                    .foregroundStyle(Theme.Palette.soil)
                    .accessibilityLabel(question.prompt.replacingOccurrences(of: PracticeGenerator.blank, with: String(localized: "blank")))
                    .accessibilityIdentifier("practicePrompt")
            }
        }
    }

    private func optionState(_ index: Int, question: PracticeQuestion) -> OptionButton.State {
        guard let selected = model.selectedIndex else { return .idle }
        if index == question.correctIndex { return .correct }
        if index == selected { return .incorrect }
        return .dimmed
    }

    // MARK: Finished

    /// The reward is the fern this round grows in the forest.
    private func finished(correct: Int, total: Int) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)
            FernBed(ferns: 1)
                .frame(width: 96, height: 64)
                .accessibilityHidden(true)
            Text("\(correct) of \(total) correct")
                .font(Typography.title)
                .foregroundStyle(Theme.Palette.soil)
            Text("A new fern grows in your forest")
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.canopy)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("practiceFern")
            Text(correct == total ? "Every answer right. Your words are taking root." : "Each round helps the words take root.")
                .font(Typography.callout)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button("Done") { model.backToMenu() }
                .buttonStyle(.sequoiaPrimary)
                .accessibilityIdentifier("practiceDone")
        }
        .padding(Theme.Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practiceResult")
    }
}

extension PracticeViewModel {
    var phaseGame: PracticeGame? {
        if case .playing(let round) = phase { return round.game }
        return nil
    }
}

/// A game choice on the Practice menu.
private struct GameCard: View {
    let game: PracticeGame
    /// The best score so far, once any round has been played.
    let best: Int?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: game == .definitionMatch ? "text.book.closed" : "text.cursor")
                .font(Typography.iconSmall)
                .foregroundStyle(Theme.Palette.canopy)
                .frame(width: 44, height: 44)
                .background(Theme.Palette.moss, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(game.title)
                    .font(Typography.headline)
                    .foregroundStyle(Theme.Palette.soil)
                Text(game.subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                if let best, best > 0 {
                    Text("Best: \(best) of \(PracticeGenerator.questionsPerRound)")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Palette.canopy)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(Typography.label)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// One answer option. After answering, the right answer is marked and a wrong
/// pick is shown, with an icon as well as color.
private struct OptionButton: View {
    enum State { case idle, correct, incorrect, dimmed }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text(text)
                    .font(Typography.body)
                    // Unchosen answers recede through color, not opacity, to keep contrast.
                    .foregroundStyle(state == .dimmed ? Theme.Palette.soilSecondary : Theme.Palette.soil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Always laid out, so marking an answer never reflows the text.
                Image(systemName: icon ?? "circle")
                    .foregroundStyle(tint)
                    .opacity(icon == nil ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(tint, lineWidth: state == .correct || state == .incorrect ? 2 : 0)
            }
        }
        .buttonStyle(.plain)
        // Not `.disabled`, which would dim the marked answers; the model ignores repeat taps.
        .allowsHitTesting(state == .idle)
        .accessibilityValue(accessibilityValue)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        default: nil
        }
    }

    private var tint: Color {
        switch state {
        case .correct: Theme.Palette.canopy
        case .incorrect: Theme.Palette.bark
        default: .clear
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .correct: String(localized: "Correct answer")
        case .incorrect: String(localized: "Your answer, incorrect")
        default: ""
        }
    }
}

#Preview("Practice") { NavigationStack { PracticeView(store: .preview) } }
#Preview("Practice – dark") { NavigationStack { PracticeView(store: .preview) }.preferredColorScheme(.dark) }
