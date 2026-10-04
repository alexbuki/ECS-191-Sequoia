import SwiftUI
import DesignSystem
import SequoiaCore
import SequoiaSocial

struct ForestView: View {
    @State private var model: ForestViewModel
    @State private var showsSettings = false
    @State private var snapshot: Image?

    init(store: SequoiaStore) {
        _model = State(initialValue: ForestViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.s) {
                        // A link to the trees once there are some; never disabled, which would dim it.
                        Group {
                            if model.plantedCount > 0 {
                                NavigationLink(value: ForestRoute.trees) { grove }
                                    .buttonStyle(.plain)
                            } else {
                                grove
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(model.accessibilityDescription)
                        .accessibilityIdentifier("grove")
                        if model.plantedCount > 0 {
                            NavigationLink(value: ForestRoute.trees) {
                                HStack {
                                    Label(model.plantedCount == 1 ? String(localized: "Your tree")
                                                                   : String(localized: "Your \(model.plantedCount) trees"),
                                          systemImage: "tree")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(Typography.caption)
                                        .foregroundStyle(Theme.Palette.soilSecondary)
                                        .accessibilityHidden(true)
                                }
                                .font(Typography.headline)
                                .padding(Theme.Spacing.m)
                                .frame(minHeight: Theme.Size.minTapTarget)
                                .background(Theme.Palette.surface,
                                            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Shows each tree and the words that grew it")
                            .accessibilityIdentifier("yourTrees")
                        }
                    }
                    stats
                    StreakCalendar(model: model)
                    FriendsSection()
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .sequoiaScreen()
            .navigationTitle("Forest")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let snapshot {
                        ShareLink(item: snapshot, preview: SharePreview("My Sequoia forest", image: snapshot)) {
                            Label("Share forest", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(for: ForestRoute.self) { route in
                switch route {
                case .trees: PlantedTreesView(store: model.store)
                case .tree(let index): PlantedTreeDetailView(store: model.store, index: index)
                case .word(let id):
                    if let word = model.store.provider.word(id: id) {
                        WordDetailView(store: model.store, word: word)
                    }
                }
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
            .task(id: model.store.revision) { renderSnapshot() }
        }
    }

    private var grove: some View {
        GroveView(planted: model.plantedTrees.count, stage: model.stage,
                  treeDays: model.growth.treeDays, daysToFullGrowth: model.daysToFullGrowth,
                  light: model.store.forestLight, undergrowth: model.store.undergrowth)
    }

    private var stats: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.s)]
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            StatTile(value: "\(model.growth.currentStreak)", label: "Current streak", systemImage: "flame")
            StatTile(value: "\(model.growth.longestStreak)", label: "Longest streak", systemImage: "trophy")
            StatTile(value: "\(model.wordsLearned)", label: "Words learned", systemImage: "text.book.closed")
            StatTile(value: model.growth.totalRings.formatted(), label: "Rings", systemImage: "circle.circle")
            StatTile(value: "\(model.plantedCount)", label: "Trees planted", systemImage: "tree")
        }
    }

    private func renderSnapshot() {
        let view = ForestSnapshotView(planted: model.plantedCount, stage: model.stage, treeDays: model.growth.treeDays,
                                      streak: model.growth.currentStreak, rings: model.growth.totalRings,
                                      daysToFullGrowth: model.daysToFullGrowth, undergrowth: model.store.undergrowth)
        snapshot = ShareRenderer.render(view).map(Image.init(uiImage:))
    }
}

/// The forest scene with the in-progress tree's status beneath it.
struct GroveView: View {
    let planted: Int
    let stage: TreeStage
    let treeDays: Int
    let daysToFullGrowth: Int
    var light: ForestLight = .midday
    var undergrowth: Undergrowth = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForestScene(planted: planted, currentStage: stage, light: light, undergrowth: undergrowth)
                .frame(height: 260)
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(treeDays == 0 ? String(localized: "A new seed") : stage.title)
                        .font(Typography.headline)
                    Text(treeDays == 0
                         ? String(localized: "Check in today to plant it.")
                         : String(localized: "Day \(treeDays) of \(daysToFullGrowth)"))
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                    if planted == 0 {
                        Text("Grown trees are planted here, forever.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                    } else if planted > ForestLayout.maxVisibleTrees {
                        Text("+\(planted - ForestLayout.maxVisibleTrees) more beyond the hills")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                    }
                }
                Spacer(minLength: 0)
                ProgressView(value: Double(treeDays), total: Double(daysToFullGrowth))
                    .tint(Theme.Palette.canopy)
                    .frame(maxWidth: 120)
            }
            .padding(Theme.Spacing.m)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// The shareable forest image.
struct ForestSnapshotView: View {
    let planted: Int
    let stage: TreeStage
    let treeDays: Int
    let streak: Int
    let rings: Int
    let daysToFullGrowth: Int
    var undergrowth: Undergrowth = .none

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("My forest")
                .font(Typography.wordTitle)
            // Shared images always show the forest at midday.
            GroveView(planted: planted, stage: stage, treeDays: treeDays, daysToFullGrowth: daysToFullGrowth,
                      undergrowth: undergrowth)
            HStack {
                Text("\(planted) trees · \(streak)-day streak · \(rings) rings")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                Spacer()
                Text("Sequoia")
                    .font(Typography.headline)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 420)
        .background(Theme.Palette.fog)
        .foregroundStyle(Theme.Palette.soil)
        .font(Typography.body)
    }
}

/// A month of check-ins.
struct StreakCalendar: View {
    let model: ForestViewModel

    /// A month arrow with a full-size tap target.
    private func monthArrow(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
            .contentShape(Rectangle())
    }

    var body: some View {
        let completed = model.completedDays
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(model.monthTitle).font(Typography.headline)
                Spacer()
                Button { model.showPreviousMonth() } label: { monthArrow("chevron.left") }
                    .accessibilityLabel("Previous month")
                Button { model.showNextMonth() } label: { monthArrow("chevron.right") }
                    .disabled(!model.canShowNextMonth)
                    .accessibilityLabel("Next month")
            }
            .foregroundStyle(Theme.Palette.bark)

            let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xxs), count: 7)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.xxs) {
                ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .accessibilityHidden(true)
                }
                ForEach(Array(model.calendarCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let done = completed.contains(day)
                        let isToday = day == model.store.today
                        Text("\(day.day)")
                            .font(Typography.caption.weight(done ? .bold : .regular))
                            .foregroundStyle(done ? Theme.Palette.soil : Theme.Palette.soilSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(done ? Theme.Palette.moss : .clear, in: Circle())
                            .overlay(Circle().stroke(isToday ? Theme.Palette.bark : .clear, lineWidth: 1.5))
                            .accessibilityLabel(Text(day.startDate(in: model.store.currentClock.calendar).formatted(date: .long, time: .omitted)))
                            .accessibilityValue(done ? Text("Completed") : Text("Not completed"))
                    } else {
                        Color.clear.frame(minHeight: 34).accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }
}

/// Friends and leaderboards through Game Center. Entirely optional: signed-out
/// players see a calm opt-in, and nothing else depends on it.
struct FriendsSection: View {
    @Environment(AppModel.self) private var app

    private var social: SocialModel { app.social }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("Friends").font(Typography.headline)
                Spacer()
                if social.isSignedIn {
                    Button { social.showLeaderboards() } label: {
                        Text("All leaderboards")
                            .frame(minHeight: Theme.Size.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.bark)
                }
            }
            content
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        }
        .task(id: social.status) { await social.loadEntries() }
        .task(id: social.selectedKind) { await social.loadEntries() }
        .task(id: app.store.revision) { await social.loadEntries() }
    }

    @ViewBuilder
    private var content: some View {
        switch social.status {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case .signedOut:
            CalmEmptyState(
                "Grow alongside friends",
                message: "Connect Game Center to compare streaks, trees and rings with friends. It's optional; everything else works without it.",
                systemImage: "person.2"
            ) {
                Button("Connect Game Center") { social.signIn() }
                    .buttonStyle(.sequoiaSecondary)
                    .accessibilityIdentifier("connectGameCenter")
            }
            .accessibilityIdentifier("friendsOptIn")
        case .unavailable:
            CalmEmptyState(
                "Friends aren't available",
                message: "Game Center isn't available on this device. Your forest keeps growing all the same.",
                systemImage: "person.2.slash"
            )
        case .signedIn:
            leaderboard
        }
    }

    private var leaderboard: some View {
        @Bindable var social = social
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Picker("Leaderboard", selection: $social.selectedKind) {
                ForEach(LeaderboardKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("leaderboardPicker")

            if social.hasFriends {
                ForEach(social.entries[social.selectedKind] ?? []) { entry in
                    LeaderboardRow(entry: entry)
                }
            } else {
                CalmEmptyState(
                    "No friends here yet",
                    message: "Add friends in Game Center to see how their forests grow next to yours.",
                    systemImage: "person.badge.plus"
                ) {
                    Button("Find friends") { social.showFriends() }
                        .buttonStyle(.sequoiaSecondary)
                }
                .accessibilityIdentifier("friendsEmpty")
            }
        }
        .padding(Theme.Spacing.m)
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("\(entry.rank)")
                .font(Typography.label.monospacedDigit())
                .foregroundStyle(Theme.Palette.soilSecondary)
                .frame(minWidth: 24, alignment: .leading)
            Text(entry.name)
                .font(entry.isLocalPlayer ? Typography.headline : Typography.body)
                .foregroundStyle(Theme.Palette.soil)
            Spacer()
            Text(entry.score.formatted())
                .font(Typography.headline.monospacedDigit())
                .foregroundStyle(entry.isLocalPlayer ? Theme.Palette.canopy : Theme.Palette.soil)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.s)
        .background(entry.isLocalPlayer ? Theme.Palette.moss.opacity(0.5) : .clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Rank \(entry.rank), \(entry.name), \(entry.score)"))
        .accessibilityIdentifier(entry.isLocalPlayer ? "leaderboardRow-you" : "leaderboardRow")
    }
}

#Preview("Forest") { ForestView(store: .preview).environment(AppModel.preview) }
#Preview("Forest – dark") { ForestView(store: .preview).environment(AppModel.preview).preferredColorScheme(.dark) }
#Preview("Grove · 12") { GroveView(planted: 12, stage: .sapling, treeDays: 9, daysToFullGrowth: 30).padding().sequoiaScreen() }
