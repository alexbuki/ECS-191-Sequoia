import SwiftUI
import WidgetKit
import DesignSystem
import SequoiaCore

/// The streak with a tree glyph, for the Lock Screen.
struct StreakWidget: Widget {
    static let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WordTimelineProvider()) { entry in
            StreakWidgetView(snapshot: entry.snapshot)
                .containerBackground(Theme.Palette.fog, for: .widget)
                .widgetURL(URL(string: "sequoia://today"))
        }
        .configurationDisplayName("Streak")
        .description("Your streak and the current stage of your tree.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct StreakWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                TreeView(stage: snapshot.stage, showsGround: false)
                    .frame(height: 24)
                    .widgetAccentable()
                Text("\(snapshot.streak)")
                    .font(Typography.headline.monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
            .padding(Theme.Spacing.xxs)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.streak == 0
            ? String(localized: "No streak yet. \(snapshot.stage.accessibilityDescription).")
            : String(localized: "\(snapshot.stage.title), day \(snapshot.streak) of your streak"))
    }
}

#Preview("Circular", as: .accessoryCircular) { StreakWidget() } timeline: { WordEntry.sample }
#Preview("Circular – dark") {
    StreakWidgetView(snapshot: WordEntry.sample.snapshot)
        .frame(width: 72, height: 72)
        .preferredColorScheme(.dark)
}
