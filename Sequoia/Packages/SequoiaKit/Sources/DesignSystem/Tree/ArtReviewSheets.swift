import SwiftUI
import SequoiaCore

/// Review sheet for the tree art: every stage at full, widget and complication
/// sizes, at relative scale, and a row of grown variants.
struct TreeArtSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            label("Stages")
            row(height: 220)
            label("Small (64 pt, 28 pt)")
            HStack(alignment: .bottom, spacing: 28) {
                row(height: 64)
                row(height: 28)
            }
            label("Relative scale")
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(TreeStage.allCases) { stage in
                    TreeView(stage: stage).frame(height: 380 * ForestSceneRenderer.relativeHeight(of: stage))
                }
            }
            label("Grown variants")
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<8) { TreeView(stage: .grownSequoia, variant: $0).frame(height: 160) }
            }
        }
        .padding(24)
        .frame(width: 720)
        .background(Theme.Palette.fog)
    }

    private func row(height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(TreeStage.allCases) { TreeView(stage: $0).frame(height: height) }
        }
    }
}

/// Review sheet for the forest scene with 0, 1, 10 and 100+ planted trees.
struct ForestSceneSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach([(0, TreeStage.seed), (1, .sprout), (10, .sapling), (120, .youngSequoia)], id: \.0) { planted, stage in
                label("\(planted) planted · current: \(stage.title)")
                ForestScene(planted: planted, currentStage: stage)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            label("Times of day, with 6 ferns and 9 flowers: dawn · midday · golden hour · night")
            LazyVGrid(columns: [GridItem(.fixed(330)), GridItem(.fixed(330))], spacing: 12) {
                ForEach([6.6, 12.75, 18.4, 23.0], id: \.self) { hour in
                    ForestScene(planted: 14, currentStage: .sapling, light: ForestLight(hour: hour),
                                undergrowth: Undergrowth(ferns: 6, flowers: 9))
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                }
            }
        }
        .padding(24)
        .frame(width: 720)
        .background(Theme.Palette.fog)
    }
}

private func label(_ text: String) -> some View {
    Text(text).font(Typography.headline).foregroundStyle(Theme.Palette.soil)
}

#Preview("Tree art") { TreeArtSheet() }
#Preview("Forest scenes – dark") { ForestSceneSheet().preferredColorScheme(.dark) }
