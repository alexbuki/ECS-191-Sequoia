import SwiftUI
import WidgetKit
import AppIntents
import DesignSystem
import SequoiaCore

/// Today's word with the current tree: small and medium on the Home Screen,
/// rectangular and inline on the Lock Screen.
struct WordWidget: Widget {
    static let kind = "WordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WordTimelineProvider()) { entry in
            WordWidgetView(entry: entry)
                .containerBackground(Theme.Palette.fog, for: .widget)
                .widgetURL(URL(string: "sequoia://today"))
        }
        .configurationDisplayName("Today's word")
        .description("The daily word and your growing tree.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct WordWidgetView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            partOfSpeech
            Text(snapshot.word.word)
                .font(Typography.wordTitle)
                .foregroundStyle(Theme.Palette.soil)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                streakLabel
                Spacer(minLength: 0)
                TreeView(stage: snapshot.stage)
                    .frame(height: 52)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    partOfSpeech
                    Text(snapshot.word.word)
                        .font(Typography.wordTitle)
                        .foregroundStyle(Theme.Palette.soil)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(snapshot.word.definition)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .lineLimit(3)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                if snapshot.isCompleted {
                    Label("Done for today", systemImage: "checkmark")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Palette.canopy)
                } else {
                    Button(intent: GotItIntent()) {
                        Text("Got it")
                            .font(Typography.label)
                            .padding(.horizontal, Theme.Spacing.s)
                            .padding(.vertical, Theme.Spacing.xxs)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.onBark)
                    .background(Theme.Palette.bark, in: Capsule())
                    .accessibilityHint("Marks today's word as learned and grows your tree")
                }
            }
            VStack(spacing: Theme.Spacing.xxs) {
                TreeView(stage: snapshot.stage)
                    .frame(maxHeight: .infinity)
                streakLabel
            }
            .frame(width: 80)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(treeSummary)
        }
    }

    private var partOfSpeech: some View {
        Text(snapshot.word.partOfSpeech.title.uppercased())
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.Palette.bark)
            .lineLimit(1)
    }

    private var streakLabel: some View {
        Text(snapshot.streak == 0 ? String(localized: "Plant a seed") : String(localized: "Day \(snapshot.streak)"))
            .font(Typography.label)
            .foregroundStyle(Theme.Palette.soilSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.word.word)
                .font(Typography.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(snapshot.word.definition)
                .font(Typography.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var inline: some View {
        Label(snapshot.word.word, systemImage: "leaf")
    }

    // MARK: Accessibility

    private var treeSummary: String {
        snapshot.streak == 0
            ? String(localized: "No streak yet. \(snapshot.stage.accessibilityDescription).")
            : String(localized: "\(snapshot.stage.title), day \(snapshot.streak) of your streak")
    }

    private var accessibilitySummary: String {
        String(localized: "Today's word: \(snapshot.word.word). \(treeSummary)")
    }
}

#Preview("Small", as: .systemSmall) { WordWidget() } timeline: { WordEntry.sample }
#Preview("Medium", as: .systemMedium) { WordWidget() } timeline: { WordEntry.sample }
#Preview("Rectangular", as: .accessoryRectangular) { WordWidget() } timeline: { WordEntry.sample }
#Preview("Inline", as: .accessoryInline) { WordWidget() } timeline: { WordEntry.sample }
#Preview("Small – dark") {
    WordWidgetView(entry: .sample)
        .padding()
        .frame(width: 170, height: 170)
        .background(Theme.Palette.fog)
        .preferredColorScheme(.dark)
}
