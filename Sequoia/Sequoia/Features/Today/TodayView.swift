import SwiftUI
import DesignSystem
import SequoiaCore

/// The home screen. It exists to show today's word.
struct TodayView: View {
    @State private var model: TodayViewModel
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: SequoiaStore) {
        _model = State(initialValue: TodayViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    WordCard(word: model.word) {
                        Button(action: model.speak) {
                            Image(systemName: "speaker.wave.2")
                        }
                        .buttonStyle(IconButtonStyle())
                        .accessibilityLabel("Play pronunciation")
                    }
                    secondaryActions
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.l)
            }
            .scrollIndicators(.hidden)
            // Inside the bottom inset, so the forest floor meets the top of "Got it".
            .background {
                TodayForest(planted: model.forestSize, stage: model.stage,
                            light: model.store.forestLight, undergrowth: model.store.undergrowth)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomPanel }
            .sequoiaScreen()
            .toolbar(.hidden, for: .navigationBar)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.checkInCount)
        .sensoryFeedback(.success, trigger: model.plantedCount)
        .task(id: model.word.id) { model.prepareShareImage() }
        .presentsCeremony($model.plantedMoment) { app.selectedTab = .forest }
        #if SEQUOIA_DEV
        .onAppear {
            LaunchTiming.wordDidAppear()
            if DevLaunchActions.showsCeremony { model.plantedMoment = .preview(in: model.store) }
        }
        #endif
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .center))
        return layout {
            Text(model.dateTitle)
                .font(Typography.label)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            StreakChip(stage: model.stage, day: model.streak)
                .animation(Theme.Motion.growth(reduceMotion: reduceMotion), value: model.streak)
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: model.toggleFavorite) {
                Image(systemName: model.isFavorite ? "heart.fill" : "heart")
            }
            .buttonStyle(IconButtonStyle(isActive: model.isFavorite))
            .accessibilityLabel(model.isFavorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityIdentifier("favorite")

            if let image = model.shareImage {
                ShareLink(item: image, preview: SharePreview(model.word.word, image: image)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Share word card")
                .accessibilityIdentifier("share")
            }

            Spacer(minLength: Theme.Spacing.xs)

            if !model.isCompleted {
                Button("I already knew this", action: model.alreadyKnewIt)
                    .buttonStyle(.sequoiaSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .accessibilityHint("Completes today and marks the word as already known")
            }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: Theme.Spacing.s) {
            if model.isCompleted {
                GrowthPanel(
                    stage: model.displayedStage,
                    streak: model.streak,
                    outcome: model.lastOutcome
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                if model.showsFreshStartMessage {
                    Text("Plant a new seed today. Your forest is safe.")
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("Got it") {
                    withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { model.gotIt() }
                }
                .buttonStyle(.sequoiaPrimary)
                .accessibilityIdentifier("gotIt")
                .accessibilityHint("Marks today's word as learned and grows your tree")
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.xs)
        // The panel stands on the forest floor, which also hides content scrolled beneath it.
        .background { TodayForest.floor(model.store.forestLight) }
    }
}

/// The user's forest filling the lower half of Today, behind the word card.
/// Its sky is the page's fog, so it rises out of the background seamlessly;
/// an extra veil keeps it quieter than on the Forest tab.
struct TodayForest: View {
    let planted: Int
    let stage: TreeStage
    var light: ForestLight = .midday
    var undergrowth: Undergrowth = .none

    private static let veil = Theme.Palette.fog.opacity(0.3)

    static func floor(_ light: ForestLight) -> some View {
        ZStack {
            ForestScene.floorColor(light)
            veil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ForestScene(planted: planted, currentStage: stage, light: light, undergrowth: undergrowth)
                .containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
                .overlay(Self.veil)
                // The sky fades into the page, so a dark night sky has no hard edge.
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)],
                                   startPoint: .top, endPoint: .bottom)
                }
            // The forest floor continues under the button and the tab bar.
            Self.floor(light)
                .frame(height: 0)
            .ignoresSafeArea(edges: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Shown once today is complete: the tree, the streak, and what was earned.
struct GrowthPanel: View {
    let stage: TreeStage
    let streak: Int
    let outcome: CheckInOutcome?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            TreeView(stage: stage)
                .frame(height: 76)
                .id(stage)
                .transition(reduceMotion
                    ? .opacity
                    : .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Theme.Palette.soil)
                Text(subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                if let outcome {
                    Text("+\(outcome.ringsEarned) rings")
                        .font(Typography.label)
                        .foregroundStyle(outcome.plantedTree ? Theme.Palette.onSunlight : Theme.Palette.canopy)
                        .padding(.horizontal, outcome.plantedTree ? Theme.Spacing.xs : 0)
                        .padding(.vertical, outcome.plantedTree ? 2 : 0)
                        .background(outcome.plantedTree ? Theme.Palette.sunlight : .clear, in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("growthPanel")
    }

    private var title: String {
        if outcome?.plantedTree == true { return String(localized: "A sequoia joined your forest") }
        if let outcome, outcome.stageChanged { return String(localized: "Your tree is now a \(outcome.reachedStage.title.lowercased())") }
        return String(localized: "Day \(streak) complete")
    }

    private var subtitle: String {
        if outcome?.plantedTree == true { return String(localized: "A new seed is planted. See you tomorrow.") }
        return String(localized: "Come back tomorrow to keep it growing.")
    }
}

#Preview("Today") {
    TodayView(store: .preview).environment(AppModel.preview)
}

#Preview("Today – dark") {
    TodayView(store: .preview).environment(AppModel.preview).preferredColorScheme(.dark)
}

#Preview("Growth panel") {
    GrowthPanel(stage: .sapling, streak: 7, outcome: nil).padding().sequoiaScreen()
}
