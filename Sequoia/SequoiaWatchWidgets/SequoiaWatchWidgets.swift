import SwiftUI
import WidgetKit
import DesignSystem
import SequoiaCore

struct WatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot

    var word: Word { snapshot.word() }
    var stage: TreeStage { snapshot.stage() }
    var streak: Int { snapshot.growth.currentStreak }
}

/// Reads the snapshot the watch app saved, and plans the next entry for local
/// midnight, when the word changes.
struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, snapshot: .initial(today: AppClock.live.today()))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, snapshot: WatchSnapshotStore.current()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WatchEntry>) -> Void) {
        let clock = AppClock.live
        let now = WatchSnapshotStore.current(clock: clock)
        let tomorrow = now.day.adding(days: 1)
        let midnight = tomorrow.startDate(in: clock.calendar).addingTimeInterval(-AppClock.developerOffset)
        let entries = [
            WatchEntry(date: .now, snapshot: now),
            WatchEntry(date: midnight, snapshot: now.current(today: tomorrow)),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

/// The complication: the tree and streak, or the word.
struct SequoiaComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SequoiaComplication", provider: WatchProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(Theme.Palette.fog, for: .widget)
        }
        .configurationDisplayName("Sequoia")
        .description("Your tree and streak, or today's word.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct ComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.word.word)
                        .font(Typography.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.word.definition)
                        .font(Typography.caption)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                TreeView(stage: entry.stage, showsGround: false)
                    .frame(width: 22)
            }
            .accessibilityElement(children: .combine)
        case .accessoryInline:
            Label(entry.word.word, systemImage: "leaf")
        case .accessoryCorner:
            TreeView(stage: entry.stage, showsGround: false)
                .widgetAccentable()
                .widgetLabel("\(entry.streak)")
                .accessibilityLabel(treeLabel)
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    TreeView(stage: entry.stage, showsGround: false)
                        .frame(height: 22)
                        .widgetAccentable()
                    Text("\(entry.streak)")
                        .font(Typography.headline.monospacedDigit())
                        .minimumScaleFactor(0.6)
                }
                .padding(Theme.Spacing.xxs)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(treeLabel)
        }
    }

    private var treeLabel: String {
        entry.streak == 0
            ? String(localized: "No streak yet. \(entry.stage.accessibilityDescription).")
            : String(localized: "\(entry.stage.title), day \(entry.streak) of your streak")
    }
}

@main
struct SequoiaWatchWidgetsBundle: WidgetBundle {
    var body: some Widget { SequoiaComplication() }
}

private let previewEntry = WatchEntry(
    date: .now,
    snapshot: WatchSnapshot(day: AppClock.live.today(), wordID: WatchSnapshot.initial(today: AppClock.live.today()).wordID,
                            difficulty: .elevated, growth: GrowthState(currentStreak: 9, longestStreak: 9, treeDays: 9),
                            isCompleted: false)
)

#Preview("Circular", as: .accessoryCircular) { SequoiaComplication() } timeline: { previewEntry }
#Preview("Rectangular", as: .accessoryRectangular) { SequoiaComplication() } timeline: { previewEntry }
#Preview("Corner", as: .accessoryCorner) { SequoiaComplication() } timeline: { previewEntry }
#Preview("Inline", as: .accessoryInline) { SequoiaComplication() } timeline: { previewEntry }
#Preview("Circular – dark") {
    ComplicationView(entry: previewEntry)
        .frame(width: 50, height: 50)
        .preferredColorScheme(.dark)
}
