import SwiftUI
import SequoiaCore

/// The word card: the visual hero of the app.
///
/// The word is set large in the system serif. Everything else is quiet.
public struct WordCard<Accessory: View>: View {
    public enum Style: Sendable {
        /// The full Today/detail card.
        case full
        /// A shorter card for sharing and small surfaces.
        case compact
    }

    private let word: Word
    private let style: Style
    private let accessory: Accessory

    public init(word: Word, style: Style = .full, @ViewBuilder accessory: () -> Accessory) {
        self.word = word
        self.style = style
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(word.partOfSpeech.title.uppercased())
                    .font(Typography.label)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.bark)
                Text(word.word)
                    .font(Typography.wordHero)
                    .foregroundStyle(Theme.Palette.soil)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityValue(Text(word.difficulty.title))
                    .accessibilityIdentifier("wordTitle")
                HStack(spacing: Theme.Spacing.s) {
                    Text(word.ipa)
                        .font(Typography.ipa)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .accessibilityLabel(Text("Pronunciation \(word.ipa)", bundle: .module))
                    Spacer(minLength: 0)
                    accessory
                }
            }

            Text(word.definition)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Theme.Palette.soil)
                .fixedSize(horizontal: false, vertical: true)

            if style == .full {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(word.examples, id: \.self) { example in
                        HStack(alignment: .top, spacing: Theme.Spacing.s) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Palette.moss)
                                .frame(width: 3)
                                .accessibilityHidden(true)
                            Text(example)
                                .font(Typography.quote)
                                .foregroundStyle(Theme.Palette.soilSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Origin", bundle: .module)
                        .font(Typography.label)
                        .foregroundStyle(Theme.Palette.canopy)
                    Text(word.etymology)
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

public extension WordCard where Accessory == EmptyView {
    init(word: Word, style: Style = .full) {
        self.init(word: word, style: style) { EmptyView() }
    }
}

/// A self-contained, shareable image of a word, rendered with `ImageRenderer`.
public struct WordShareCard: View {
    private let word: Word
    private let stage: TreeStage
    private let streak: Int

    public init(word: Word, stage: TreeStage, streak: Int) {
        self.word = word
        self.stage = stage
        self.streak = streak
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            WordCard(word: word, style: .compact)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Sequoia", bundle: .module)
                        .font(Typography.headline)
                        .foregroundStyle(Theme.Palette.soil)
                    Text(streak > 0 ? String(localized: "Day \(streak) of my streak", bundle: .module) : String(localized: "Daily Vocab", bundle: .module))
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                }
                Spacer()
                TreeView(stage: stage).frame(height: 64)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 390)
        .background(Theme.Palette.fog)
        .font(Typography.body)
    }
}

#Preview("Word card") {
    ScrollView {
        WordCard(word: .sample) {
            Button {} label: { Image(systemName: "speaker.wave.2") }.buttonStyle(IconButtonStyle())
        }
        .padding()
    }
    .sequoiaScreen()
}

#Preview("Word card – dark") {
    ScrollView { WordCard(word: .sample).padding() }
        .sequoiaScreen()
        .preferredColorScheme(.dark)
}

#Preview("Share card") {
    WordShareCard(word: .sample, stage: .sapling, streak: 9)
}
