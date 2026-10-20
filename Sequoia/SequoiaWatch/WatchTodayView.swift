import SwiftUI
import DesignSystem
import SequoiaCore

/// A compact Today: the tree, the word and "Got it".
struct WatchTodayView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.s) {
                    hero
                    wordDetails
                    action
                }
                .scenePadding(.horizontal)
                .padding(.bottom, Theme.Spacing.xs)
            }
            .foregroundStyle(Theme.Palette.soil)
            .containerBackground(background, for: .navigation)
        }
        .sensoryFeedback(.success, trigger: model.checkInCount)
    }

    /// The tree on a soft patch of light, with the streak beneath it.
    private var hero: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            TreeView(stage: model.stage)
                .frame(height: 78)
                .id(model.stage)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .accessibilityLabel(treeLabel)
            if model.streak > 0 {
                Text("Day \(model.streak)")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.canopy)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Theme.Palette.moss, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var wordDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.word.partOfSpeech.title.uppercased())
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.bark)
            Text(model.word.word)
                .font(Typography.wordTitle)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("watchWord")
            Text(model.word.ipa)
                .font(Typography.ipa)
                .foregroundStyle(Theme.Palette.soilSecondary)
            Text(model.word.definition)
                .font(Typography.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var action: some View {
        if model.snapshot.isCompleted {
            Label(model.streak == 0 ? String(localized: "Done for today") : String(localized: "Day \(model.streak) complete"),
                  systemImage: "checkmark.circle.fill")
                .font(Typography.label)
                .foregroundStyle(Theme.Palette.canopy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Palette.moss, in: Capsule())
                .accessibilityIdentifier("watchDone")
        } else if model.plantsTree {
            // The planting is the iPhone app's moment.
            Label("Your sequoia is ready. Open Sequoia on your iPhone to plant it.", systemImage: "iphone")
                .font(Typography.label)
                .foregroundStyle(Theme.Palette.canopy)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("watchPlantOnPhone")
        } else {
            Button {
                withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { model.gotIt() }
            } label: {
                Text("Got it")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.canopy)
            .foregroundStyle(Theme.Palette.fog)
            .accessibilityIdentifier("watchGotIt")
            .accessibilityHint("Marks today's word as learned and grows your tree")
        }
    }

    /// Evergreen fading into the night, like the forest at dusk.
    private var background: LinearGradient {
        LinearGradient(colors: [Theme.Palette.moss, Theme.Palette.fog], startPoint: .top, endPoint: .bottom)
    }

    private var treeLabel: String {
        model.streak == 0
            ? String(localized: "No streak yet. \(model.stage.accessibilityDescription).")
            : String(localized: "\(model.stage.title), day \(model.streak) of your streak")
    }
}

#Preview { WatchTodayView().environment(WatchModel()).preferredColorScheme(.dark) }
