import SwiftUI
import DesignSystem
import SequoiaCore

/// The home screen. It exists to show today's word.
struct TodayView: View {
    @State private var model: TodayViewModel
    @Environment(AppModel.self) private var app
    @AppStorage(AppModel.reminderOfferDismissedKey) private var reminderOfferDismissed = false
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
                    if model.isFirstWord {
                        wordLevelMenu
                    }
                    // Favorite and share come after the word is learned, so before
                    // "Got it" the screen holds just the word and the button.
                    if model.isCompleted {
                        secondaryActions
                    }
                    // In the scrolling content, not the fixed bottom panel, so large
                    // text never squeezes the growth panel.
                    if model.offersReminder && !reminderOfferDismissed {
                        ReminderOffer(time: model.reminderTime) { time in
                            Task { await app.enableReminder(at: time) }
                        } dismiss: {
                            withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { reminderOfferDismissed = true }
                        }
                        .transition(.opacity)
                    }
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
        #if SEQUOIA_DEV
        .onAppear { LaunchTiming.wordDidAppear() }
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

    /// On the first word only: change its level in place, instead of being
    /// asked during onboarding before seeing a single word.
    private var wordLevelMenu: some View {
        Menu {
            Picker("Word level", selection: $model.difficulty) {
                ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Label("Word level: \(model.difficulty.title)", systemImage: "slider.horizontal.3")
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(Theme.Palette.bark)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.Size.minTapTarget)
                // On a surface, since the forest stands behind this part of the screen.
                .background(Theme.Palette.surface, in: Capsule())
                .contentShape(Capsule())
        }
        .accessibilityHint("Swaps today's word for an easier or harder one")
        .accessibilityIdentifier("wordLevel")
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

            Spacer(minLength: 0)
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: Theme.Spacing.s) {
            if model.isCompleted {
                GrowthPanel(
                    stage: model.displayedStage,
                    streak: model.streak,
                    outcome: model.lastOutcome,
                    treeDays: model.treeDays,
                    daysToFullGrowth: model.daysToFullGrowth
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                if let rainNote = model.rainNote {
                    // Text on the forest floor uses `soil`: `soilSecondary` dims too far at night.
                    Label(rainNote, systemImage: "cloud.rain")
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soil)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("rainNote")
                }
                if model.showsFreshStartMessage {
                    Text("Plant a new seed today. Your forest is safe.")
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soil)
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

/// Shown once today is complete: the tree, what changed, and how far it is
/// to the next grown sequoia.
struct GrowthPanel: View {
    let stage: TreeStage
    let streak: Int
    let outcome: CheckInOutcome?
    var treeDays = 0
    var daysToFullGrowth = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The stage before this check-in, drawn for a moment when the tree just
    /// grew, so the growth itself is seen.
    @State private var previousStage: TreeStage?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            let shown = previousStage ?? stage
            TreeView(stage: shown)
                .frame(height: 76)
                .id(shown)
                .transition(reduceMotion
                    ? .opacity
                    : .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Theme.Palette.soil)
                subtitle
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                ProgressView(value: Double(progressDays), total: Double(daysToFullGrowth))
                    .tint(Theme.Palette.canopy)
                    .padding(.top, Theme.Spacing.xxs)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("growthPanel")
        .task(id: outcome?.streak) { await showGrowth() }
    }

    /// Plays the stage change: the old stage, then the new one grows in.
    private func showGrowth() async {
        guard let outcome, outcome.stageChanged, !isPlanting, !reduceMotion else { return }
        previousStage = outcome.previousStage
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { previousStage = nil }
    }

    /// A grown tree was planted this check-in (not the welcome tree).
    private var isPlanting: Bool { outcome?.plantedTree == true && outcome?.plantedWelcomeTree != true }

    private var progressDays: Int { isPlanting ? daysToFullGrowth : treeDays }

    private var wordsToGo: Int { max(0, daysToFullGrowth - treeDays) }

    private var title: String {
        if outcome?.plantedWelcomeTree == true { return String(localized: "Your first sequoia is planted") }
        if isPlanting { return String(localized: "A sequoia joined your forest") }
        if let outcome, outcome.stageChanged { return String(localized: "Your tree is now a \(outcome.reachedStage.title.lowercased())") }
        return String(localized: "Day \(streak) complete")
    }

    private var subtitle: Text {
        if outcome?.plantedWelcomeTree == true {
            return Text("Your next one has sprouted. ^[\(wordsToGo) more word](inflect: true) to grow it.")
        }
        if isPlanting { return Text("A new seed is planted. See you tomorrow.") }
        return Text("^[\(wordsToGo) more word](inflect: true) to a grown sequoia.")
    }
}

/// Offered once, right after the first "Got it": a daily reminder for the
/// next word, at a time the user picks.
struct ReminderOffer: View {
    let accept: (DateComponents) -> Void
    let dismiss: () -> Void
    @State private var time: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(time: DateComponents, accept: @escaping (DateComponents) -> Void, dismiss: @escaping () -> Void) {
        self.accept = accept
        self.dismiss = dismiss
        _time = State(initialValue: Calendar.current.date(from: time) ?? .now)
    }

    var body: some View {
        // Side by side normally; stacked at accessibility text sizes so nothing clips.
        let controls = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.s))
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Want tomorrow's word on time?")
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.soil)
                .fixedSize(horizontal: false, vertical: true)
            controls {
                DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button("Not now", action: dismiss)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.bark)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("reminderOfferDismiss")
                Button("Remind me") {
                    accept(Calendar.current.dateComponents([.hour, .minute], from: time))
                }
                .buttonStyle(.sequoiaSecondary)
                .accessibilityIdentifier("reminderOfferAccept")
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminderOffer")
    }
}

#Preview("Today") {
    TodayView(store: .preview).environment(AppModel.preview)
}

#Preview("Today – dark") {
    TodayView(store: .preview).environment(AppModel.preview).preferredColorScheme(.dark)
}

#Preview("Growth panel") {
    GrowthPanel(stage: .sapling, streak: 7, outcome: nil, treeDays: 7).padding().sequoiaScreen()
}
