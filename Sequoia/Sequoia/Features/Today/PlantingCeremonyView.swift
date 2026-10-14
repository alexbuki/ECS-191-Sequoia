import SwiftUI
import DesignSystem
import SequoiaCore

/// A tree that has just been planted, for the ceremony.
struct PlantedTreeMoment: Identifiable, Equatable {
    /// The tree's index in the forest, also its art variant.
    let index: Int
    /// The words of the days that grew it, oldest first.
    let words: [Word]
    /// How many trees this ceremony celebrates: more than one when several were
    /// planted while the app was closed. `index` is the newest of them.
    var count = 1
    /// The welcome tree, planted by the very first word.
    var isWelcome = false

    var id: Int { index }

    /// The trees planted since the last ceremony, shown as one moment for the newest.
    @MainActor
    static func pending(in store: SequoiaStore) -> PlantedTreeMoment? {
        let trees = store.treesAwaitingCeremony()
        guard let newest = trees.last else { return nil }
        return PlantedTreeMoment(index: newest.index, words: store.words(grownInto: newest), count: trees.count,
                                 isWelcome: trees.count == 1 && store.isWelcomeTree(newest))
    }

    #if SEQUOIA_DEV
    /// The latest tree for previewing the ceremony, borrowing recently seen
    /// words when it has none (trees planted by developer tools).
    @MainActor
    static func preview(in store: SequoiaStore) -> PlantedTreeMoment {
        let latest = store.plantedTrees().last
        let grown = latest.map { store.words(grownInto: $0) } ?? []
        let words = grown.isEmpty
            ? Array(store.seenWords().map(\.word).prefix(store.engine.config.daysToFullGrowth))
            : grown
        return PlantedTreeMoment(index: latest?.index ?? 0, words: words)
    }
    #endif
}

/// The moment a tree reaches full growth: the view rises from the roots of a
/// towering sequoia to its sunlit crown, then names the words that grew it.
struct PlantingCeremonyView: View {
    let moment: PlantedTreeMoment
    let onSeeForest: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 is close in on the base of the trunk; 1 shows the whole tree.
    @State private var rise: CGFloat = 0
    @State private var showsSunlight = false
    @State private var showsCard = false
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // At rest the whole tree stands with its crown near the top. The
            // ceremony starts close in on the trunk's base and pulls back as it
            // tilts up, so the tree seems to rise out of view and then fit.
            let treeHeight = size.height * 1.15
            let restTop = size.height * 0.03
            let baseLift = treeHeight + restTop - size.height * 0.96
            ZStack(alignment: .top) {
                Theme.Palette.fog
                Circle()
                    .fill(Theme.Palette.sunlight.opacity(0.32))
                    .frame(width: size.width * 1.1)
                    .blur(radius: 40)
                    .offset(y: size.height * 0.02)
                    .opacity(showsSunlight ? 1 : 0)
                    .scaleEffect(showsSunlight ? 1 : 0.6)
                // Sized by height, wider than the screen if need be (the sides clip).
                TreeView(stage: .grownSequoia, showsGround: true, variant: moment.index)
                    .frame(width: treeHeight * 0.5, height: treeHeight)
                    .frame(width: size.width)
                    .scaleEffect(1 + (1 - rise) * 1.6, anchor: .bottom)
                    .offset(y: restTop - (1 - rise) * baseLift)
                    .opacity(reduceMotion && rise == 0 ? 0 : 1)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            if showsCard {
                card
                    .padding(Theme.Spacing.m)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sequoiaScreen()
        // Presented without the sheet slide (see `presentsCeremony`); fades in instead.
        .opacity(isVisible ? 1 : 0)
        .task { await play() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: showsSunlight)
    }

    private var card: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(title)
                    .font(Typography.wordTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                if moment.isWelcome, let first = moment.words.first {
                    Text("Planted with “\(first.word)”")
                        .font(Typography.quote)
                        .foregroundStyle(Theme.Palette.soil)
                        .accessibilityIdentifier("ceremonyWords")
                } else if !moment.words.isEmpty {
                    Text("Grown from \(wordList)")
                        .font(Typography.quote)
                        .foregroundStyle(Theme.Palette.soil)
                        .accessibilityIdentifier("ceremonyWords")
                }
                VStack(spacing: Theme.Spacing.xs) {
                    Button("See your forest", action: onSeeForest)
                        .buttonStyle(.sequoiaPrimary)
                        .accessibilityIdentifier("ceremonySeeForest")
                    Button("Done", action: onDone)
                        .buttonStyle(.sequoiaSecondary)
                        .accessibilityIdentifier("ceremonyDone")
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var title: String {
        if moment.isWelcome { return String(localized: "Your first sequoia") }
        return moment.count > 1
            ? String(localized: "\(moment.count) sequoias joined your forest")
            : String(localized: "A sequoia joined your forest")
    }

    private var subtitle: String {
        if moment.isWelcome {
            return String(localized: "A welcome gift for your first word. Every word from now on grows the next one, and it stands beside this one forever.")
        }
        return moment.count > 1
            ? String(localized: "Trees \(moment.index + 2 - moment.count)–\(moment.index + 1) in your forest. They will stand there forever.")
            : String(localized: "Tree \(moment.index + 1) in your forest. It will stand there forever.")
    }

    /// The first words in full, then a count, so the card stays compact.
    private var wordList: String {
        let shown = 12
        let names = moment.words.map(\.word)
        guard names.count > shown + 1 else { return names.formatted(.list(type: .and)) }
        let more = String(localized: "\(names.count - shown) more")
        return (names.prefix(shown) + [more]).formatted(.list(type: .and))
    }

    /// Rise up the trunk, let the sunlight bloom, then show the card. Each step
    /// stays under a second; with Reduce Motion the tree simply fades in.
    private func play() async {
        withAnimation(Theme.Motion.fade) { isVisible = true }
        if reduceMotion {
            withAnimation(Theme.Motion.fade) { rise = 1 }
        } else {
            withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 0.95)) { rise = 1 }
        }
        try? await Task.sleep(for: .seconds(reduceMotion ? 0.25 : 0.85))
        withAnimation(reduceMotion ? Theme.Motion.fade : Theme.Motion.grow) { showsSunlight = true }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(reduceMotion ? Theme.Motion.fade : Theme.Motion.settle) { showsCard = true }
    }
}

extension View {
    /// Shows the planting ceremony full screen, fading in rather than sliding up.
    func presentsCeremony(_ moment: Binding<PlantedTreeMoment?>, onSeeForest: @escaping () -> Void) -> some View {
        modifier(CeremonyPresenter(moment: moment, onSeeForest: onSeeForest))
    }
}

/// Presents the ceremony. "See your forest" acts once the cover has gone, since
/// changing tabs while it is still dismissing is ignored.
private struct CeremonyPresenter: ViewModifier {
    @Binding var moment: PlantedTreeMoment?
    let onSeeForest: () -> Void
    @State private var seesForest = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $moment, onDismiss: {
                if seesForest { onSeeForest() }
                seesForest = false
            }) { current in
                PlantingCeremonyView(moment: current) {
                    seesForest = true
                    moment = nil
                } onDone: {
                    moment = nil
                }
                .presentationBackground(.clear)
            }
            .transaction(value: moment) { $0.disablesAnimations = true }
    }
}

#Preview("Ceremony") {
    PlantingCeremonyView(moment: .init(index: 3, words: Array(BundledWordProvider.shared.words.prefix(30))),
                         onSeeForest: {}, onDone: {})
}

#Preview("Ceremony – dark") {
    PlantingCeremonyView(moment: .init(index: 0, words: Array(BundledWordProvider.shared.words.prefix(30))),
                         onSeeForest: {}, onDone: {})
        .preferredColorScheme(.dark)
}
