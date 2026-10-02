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
                    GroveView(planted: model.plantedTrees.count, stage: model.stage, treeDays: model.growth.treeDays,
                              daysToFullGrowth: model.daysToFullGrowth)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(model.accessibilityDescription)
                        .accessibilityIdentifier("grove")
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
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
            .task(id: model.store.revision) { renderSnapshot() }
        }
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
                                      daysToFullGrowth: model.daysToFullGrowth)
        snapshot = ShareRenderer.render(view).map(Image.init(uiImage:))
    }
}

/// A calm grove: every planted tree, with the in-progress tree in front.
struct GroveView: View {
    let planted: Int
    let stage: TreeStage
    let treeDays: Int
    let daysToFullGrowth: Int
    var maxVisibleTrees: Int = .max

    var body: some View {
        VStack(spacing: 0) {
            if planted > 0 {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34, maximum: 46), spacing: 0)], spacing: -18) {
                    ForEach(0..<min(planted, maxVisibleTrees), id: \.self) { index in
                        let scale = 0.78 + CGFloat((index * 37) % 23) / 100
                        TreeView(stage: .grownSequoia, showsGround: false, variant: index)
                            .frame(height: 76 * scale)
                            .frame(height: 76, alignment: .bottom)
                            .offset(y: CGFloat((index * 13) % 7) - 3)
                    }
                }
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.m)
                if planted > maxVisibleTrees {
                    Text("+\(planted - maxVisibleTrees) more")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                }
            }

            HStack(alignment: .bottom, spacing: Theme.Spacing.m) {
                TreeView(stage: stage)
                    .frame(height: planted > 0 ? 130 : 170)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(treeDays == 0 ? String(localized: "A new seed") : stage.title)
                        .font(Typography.headline)
                    Text(treeDays == 0
                         ? String(localized: "Check in today to plant it.")
                         : String(localized: "Day \(treeDays) of \(daysToFullGrowth)"))
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                    ProgressView(value: Double(treeDays), total: Double(daysToFullGrowth))
                        .tint(Theme.Palette.canopy)
                        .frame(maxWidth: 160)
                    if planted == 0 {
                        Text("Grown trees are planted here, forever.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                    }
                }
                .padding(.bottom, Theme.Spacing.m)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            Theme.Palette.moss.opacity(0.55)
                .frame(height: 56)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Theme.Radius.card, bottomTrailingRadius: Theme.Radius.card))
        }
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("My forest")
                .font(Typography.wordTitle)
            GroveView(planted: planted, stage: stage, treeDays: treeDays, daysToFullGrowth: daysToFullGrowth, maxVisibleTrees: 40)
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

    var body: some View {
        let completed = model.completedDays
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(model.monthTitle).font(Typography.headline)
                Spacer()
                Button { model.showPreviousMonth() } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Button { model.showNextMonth() } label: { Image(systemName: "chevron.right") }
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
                    Button("All leaderboards") { social.showLeaderboards() }
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
