import SwiftUI
import DesignSystem
import SequoiaCore

/// Navigation targets inside the Forest tab.
enum ForestRoute: Hashable {
    case trees
    case tree(index: Int)
    case word(id: String)
}

/// Every planted tree, newest first.
struct PlantedTreesView: View {
    let store: SequoiaStore

    var body: some View {
        let trees = plantedTrees
        List(trees.reversed(), id: \.index) { tree in
            NavigationLink(value: ForestRoute.tree(index: tree.index)) {
                HStack(spacing: Theme.Spacing.m) {
                    TreeView(stage: .grownSequoia, showsGround: false, variant: tree.index)
                        .frame(height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Tree \(tree.index + 1)")
                            .font(Typography.headline)
                        Text(plantedLabel(tree))
                            .font(Typography.callout)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                    }
                }
                .padding(.vertical, Theme.Spacing.xxs)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .sequoiaScreen()
        .navigationTitle("Your trees")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var plantedTrees: [PlantedTreeRecord] {
        _ = store.revision
        return store.plantedTrees()
    }

    private func plantedLabel(_ tree: PlantedTreeRecord) -> String {
        let date = DayStamp(dayNumber: tree.plantedDay).startDate(in: store.currentClock.calendar)
        return String(localized: "Planted \(date.formatted(date: .abbreviated, time: .omitted))")
    }
}

/// One planted tree and the words that grew it.
struct PlantedTreeDetailView: View {
    let store: SequoiaStore
    let index: Int

    var body: some View {
        let tree = store.plantedTrees().first { $0.index == index }
        let words = tree.map { store.words(grownInto: $0) } ?? []
        List {
            Section {
                VStack(spacing: Theme.Spacing.s) {
                    TreeView(stage: .grownSequoia, variant: index)
                        .frame(height: 260)
                        .accessibilityHidden(true)
                    if let tree {
                        Text(plantedLabel(tree))
                            .font(Typography.callout)
                            .foregroundStyle(Theme.Palette.soilSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                if words.isEmpty {
                    Text("This tree's words weren't recorded.")
                        .font(Typography.callout)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                } else {
                    ForEach(words) { word in
                        NavigationLink(value: ForestRoute.word(id: word.id)) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(word.word)
                                    .font(Typography.wordTitle)
                                Text(word.definition)
                                    .font(Typography.callout)
                                    .foregroundStyle(Theme.Palette.soilSecondary)
                                    .lineLimit(2)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            } header: {
                Text(words.isEmpty ? String(localized: "Words") : String(localized: "Grown from \(words.count) words"))
                    .font(Typography.label)
                    .foregroundStyle(Theme.Palette.soilSecondary)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .sequoiaScreen()
        .navigationTitle("Tree \(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func plantedLabel(_ tree: PlantedTreeRecord) -> String {
        let date = DayStamp(dayNumber: tree.plantedDay).startDate(in: store.currentClock.calendar)
        return String(localized: "Planted \(date.formatted(date: .long, time: .omitted))")
    }
}

#Preview("Trees") { NavigationStack { PlantedTreesView(store: .preview) } }
#Preview("Tree") { NavigationStack { PlantedTreeDetailView(store: .preview, index: 0) } }
