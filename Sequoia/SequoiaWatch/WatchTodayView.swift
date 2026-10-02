import SwiftUI
import DesignSystem
import SequoiaCore

/// A compact Today: the word, the current tree and "Got it".
struct WatchTodayView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.word.partOfSpeech.title.uppercased())
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.Palette.bark)
                        Text(model.word.word)
                            .font(Typography.wordTitle)
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("watchWord")
                    }
                    Spacer(minLength: 0)
                    TreeView(stage: model.stage)
                        .frame(height: 40)
                        .id(model.stage)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                        .accessibilityLabel(treeLabel)
                }
                Text(model.word.ipa)
                    .font(Typography.ipa)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                Text(model.word.definition)
                    .font(Typography.callout)
                if model.snapshot.isCompleted {
                    Label(model.streak == 0 ? String(localized: "Done for today") : String(localized: "Day \(model.streak) complete"),
                          systemImage: "checkmark")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Palette.canopy)
                        .padding(.top, Theme.Spacing.xs)
                        .accessibilityIdentifier("watchDone")
                } else {
                    Button("Got it") {
                        withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { model.gotIt() }
                    }
                    .tint(Theme.Palette.bark)
                    .padding(.top, Theme.Spacing.xs)
                    .accessibilityIdentifier("watchGotIt")
                    .accessibilityHint("Marks today's word as learned and grows your tree")
                }
            }
            .foregroundStyle(Theme.Palette.soil)
        }
        .background(Theme.Palette.fog.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: model.checkInCount)
    }

    private var treeLabel: String {
        model.streak == 0
            ? String(localized: "No streak yet. \(model.stage.accessibilityDescription).")
            : String(localized: "\(model.stage.title), day \(model.streak) of your streak")
    }
}

#Preview { WatchTodayView().environment(WatchModel()) }
#Preview("Dark") { WatchTodayView().environment(WatchModel()).preferredColorScheme(.dark) }
