import SwiftUI
import SequoiaCore

/// Review sheet for the tree art: every stage at full, widget and complication
/// sizes, at relative scale, the grown varieties and a
/// row of grown variants.
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
            label("Grown varieties: classic · snag top · twin crown · broad · slender")
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(TreeArt.Variety.allCases, id: \.self) { variety in
                    TreeView(stage: .grownSequoia, variant: variety.sampleVariant).frame(height: 220)
                }
            }
            label("Grown variants 0–9")
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10) { TreeView(stage: .grownSequoia, variant: $0).frame(height: 130) }
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

/// Review sheet for the shared word card at midday, golden hour and night.
struct ShareCardSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ForEach([12.75, 18.4], id: \.self) { hour in
                    WordShareCard(word: .sample, stage: .sapling, streak: 9, planted: 12, light: ForestLight(hour: hour))
                }
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.3))
    }
}

/// Review sheet for the ring-count art, small and large.
struct RingsSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ForEach([0, 120, 475, 2000], id: \.self) { TreeRingsView(rings: $0).frame(width: 90) }
            }
            TreeRingsView(rings: 2000).frame(width: 240)
            RingsTile(rings: 475).frame(width: 390)
        }
        .padding(24)
        .sequoiaScreen()
    }
}

private func label(_ text: String) -> some View {
    Text(text).font(Typography.headline).foregroundStyle(Theme.Palette.soil)
}

#Preview("Tree art") { TreeArtSheet() }
#Preview("Forest scenes – dark") { ForestSceneSheet().preferredColorScheme(.dark) }
