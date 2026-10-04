import SwiftUI
import SequoiaCore

/// Draws a stylized sequoia at any growth stage and any size, from a watch
/// complication to the full forest. The drawing itself lives in `TreeArt`.
public struct TreeView: View {
    private let stage: TreeStage
    private let showsGround: Bool
    private let variant: Int

    /// - Parameters:
    ///   - stage: the growth stage to draw.
    ///   - showsGround: whether to draw a small patch of ground.
    ///   - variant: a seed for subtle, deterministic shape variation in the forest.
    public init(stage: TreeStage, showsGround: Bool = true, variant: Int = 0) {
        self.stage = stage
        self.showsGround = showsGround
        self.variant = variant
    }

    public var body: some View {
        Canvas { context, size in
            TreeArt(stage: stage, showsGround: showsGround, variant: variant)
                .draw(in: &context, size: size)
        }
        .aspectRatio(TreeArt.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(stage.accessibilityDescription)
    }
}

#Preview("All stages") {
    HStack(alignment: .bottom) {
        ForEach(TreeStage.allCases) { TreeView(stage: $0).frame(height: 160) }
    }
    .padding()
    .sequoiaScreen()
}

#Preview("All stages – dark") {
    HStack(alignment: .bottom) {
        ForEach(TreeStage.allCases) { TreeView(stage: $0).frame(height: 160) }
    }
    .padding()
    .sequoiaScreen()
    .preferredColorScheme(.dark)
}
