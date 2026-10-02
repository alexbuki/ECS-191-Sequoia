import SwiftUI
import SequoiaCore

/// Draws a stylized sequoia at any growth stage and any size, from a watch
/// complication to the full forest. Tall, conical canopy; reddish trunk.
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
            TreeRenderer(stage: stage, showsGround: showsGround, variant: variant)
                .draw(in: &context, size: size)
        }
        .aspectRatio(TreeRenderer.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(stage.accessibilityDescription)
    }
}

/// The drawing itself, in a unit coordinate space (x: 0...1, y: 0...1, y grows down).
struct TreeRenderer {
    static let aspectRatio: CGFloat = 0.5

    let stage: TreeStage
    let showsGround: Bool
    let variant: Int

    private var jitter: CGFloat {
        // A small, stable variation in [-1, 1] for natural-looking forests.
        let x = sin(Double(variant) * 12.9898) * 43_758.5453
        return CGFloat(x - x.rounded(.down)) * 2 - 1
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> CGRect {
            CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h)
        }

        let groundY: CGFloat = 0.95
        if showsGround {
            let groundWidth: CGFloat = stage <= .sprout ? 0.7 : 0.9
            context.fill(
                Path(ellipseIn: rect(0.5 - groundWidth / 2, groundY - 0.025, groundWidth, 0.05)),
                with: .color(Theme.Palette.moss)
            )
        }

        switch stage {
        case .seed:
            var seed = context
            seed.translateBy(x: 0.5 * w, y: (groundY - 0.065) * h)
            seed.rotate(by: .degrees(-18))
            seed.fill(Path(ellipseIn: CGRect(x: -0.24 * w, y: -0.06 * h, width: 0.48 * w, height: 0.12 * h)),
                      with: .color(Theme.Palette.bark))
            // A tiny shoot hinting at what's to come.
            var shoot = Path()
            shoot.move(to: CGPoint(x: 0.12 * w, y: -0.045 * h))
            shoot.addQuadCurve(to: CGPoint(x: 0.2 * w, y: -0.16 * h), control: CGPoint(x: 0.26 * w, y: -0.08 * h))
            seed.stroke(shoot, with: .color(Theme.Palette.canopy), style: StrokeStyle(lineWidth: max(1.5, 0.07 * w), lineCap: .round))

        case .sprout:
            var stem = Path()
            stem.move(to: p(0.5, groundY))
            stem.addQuadCurve(to: p(0.5, 0.68), control: p(0.46, 0.82))
            context.stroke(stem, with: .color(Theme.Palette.canopy),
                           style: StrokeStyle(lineWidth: max(1.5, 0.07 * w), lineCap: .round))
            drawLeaf(in: &context, at: p(0.5, 0.69), angle: -30, length: 0.4 * w, width: 0.18 * w)
            drawLeaf(in: &context, at: p(0.5, 0.69), angle: -150, length: 0.34 * w, width: 0.15 * w)

        case .sapling:
            drawTrunk(in: &context, w: w, h: h, top: 0.55, bottom: groundY, topWidth: 0.04, bottomWidth: 0.08)
            drawCrown(in: &context, w: w, h: h, top: 0.34, bottom: 0.8, halfWidth: 0.22, clumps: [])

        case .youngSequoia:
            drawTrunk(in: &context, w: w, h: h, top: 0.4, bottom: groundY, topWidth: 0.05, bottomWidth: 0.12)
            drawCrown(in: &context, w: w, h: h, top: 0.14, bottom: 0.68, halfWidth: 0.27,
                      clumps: [(0.92, 0.55, 0.16), (-0.95, 0.42, 0.14)])

        case .grownSequoia:
            let lean = jitter * 0.012
            drawTrunk(in: &context, w: w, h: h, top: 0.22, bottom: groundY, topWidth: 0.06, bottomWidth: 0.2, flare: true)
            drawCrown(in: &context, w: w, h: h, top: 0.02 + abs(jitter) * 0.025, bottom: 0.6,
                      halfWidth: 0.3 + jitter * 0.025,
                      clumps: [(0.95, 0.58, 0.17), (-0.98, 0.47, 0.16), (0.9, 0.33, 0.13), (-0.85, 0.22, 0.11)],
                      lean: lean)
        }
    }

    private func drawTrunk(in context: inout GraphicsContext, w: CGFloat, h: CGFloat,
                           top: CGFloat, bottom: CGFloat, topWidth: CGFloat, bottomWidth: CGFloat, flare: Bool = false) {
        var trunk = Path()
        trunk.move(to: CGPoint(x: (0.5 - topWidth / 2) * w, y: top * h))
        trunk.addLine(to: CGPoint(x: (0.5 + topWidth / 2) * w, y: top * h))
        if flare {
            trunk.addQuadCurve(to: CGPoint(x: (0.5 + bottomWidth / 2) * w, y: bottom * h),
                               control: CGPoint(x: (0.5 + topWidth / 2) * w, y: (bottom - 0.04) * h))
            trunk.addLine(to: CGPoint(x: (0.5 - bottomWidth / 2) * w, y: bottom * h))
            trunk.addQuadCurve(to: CGPoint(x: (0.5 - topWidth / 2) * w, y: top * h),
                               control: CGPoint(x: (0.5 - topWidth / 2) * w, y: (bottom - 0.04) * h))
        } else {
            trunk.addLine(to: CGPoint(x: (0.5 + bottomWidth / 2) * w, y: bottom * h))
            trunk.addLine(to: CGPoint(x: (0.5 - bottomWidth / 2) * w, y: bottom * h))
        }
        trunk.closeSubpath()
        context.fill(trunk, with: .color(Theme.Palette.bark))
    }

    /// A narrow, round-topped crown with a few foliage clumps along its edges:
    /// the columnar silhouette of a sequoia rather than a tiered pine.
    ///
    /// Each clump is (side × halfWidth offset, vertical position 0...1 within the crown, radius).
    private func drawCrown(in context: inout GraphicsContext, w: CGFloat, h: CGFloat,
                           top: CGFloat, bottom: CGFloat, halfWidth: CGFloat,
                           clumps: [(CGFloat, CGFloat, CGFloat)], lean: CGFloat = 0) {
        let cx = 0.5 + lean
        let height = bottom - top
        let tip = halfWidth * 0.18
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

        var crown = Path()
        crown.move(to: pt(cx - tip, top + tip * 0.9))
        crown.addQuadCurve(to: pt(cx + tip, top + tip * 0.9), control: pt(cx, top - tip * 0.4))
        crown.addQuadCurve(to: pt(cx + halfWidth, bottom - height * 0.12),
                           control: pt(cx + halfWidth * 0.8, top + height * 0.35))
        crown.addQuadCurve(to: pt(cx - halfWidth, bottom - height * 0.12),
                           control: pt(cx, bottom + height * 0.08))
        crown.addQuadCurve(to: pt(cx - tip, top + tip * 0.9),
                           control: pt(cx - halfWidth * 0.8, top + height * 0.35))
        crown.closeSubpath()

        for (side, position, radius) in clumps {
            let y = top + height * position
            // Edge of the crown at this height, so clumps hug the silhouette.
            let edge = halfWidth * min(1, 0.35 + position * 0.75)
            let x = cx + side * edge
            crown.addEllipse(in: CGRect(x: (x - radius * 0.62) * w, y: (y - radius * 0.38) * h,
                                        width: radius * 1.24 * w, height: radius * 0.76 * h))
        }
        context.fill(crown, with: .color(Theme.Palette.canopy))

        // A soft highlight on the sunlit side for gentle depth.
        var light = Path()
        light.move(to: pt(cx - tip * 0.5, top + tip))
        light.addQuadCurve(to: pt(cx - halfWidth * 0.82, bottom - height * 0.16),
                           control: pt(cx - halfWidth * 0.62, top + height * 0.38))
        light.addQuadCurve(to: pt(cx - halfWidth * 0.2, top + height * 0.2),
                           control: pt(cx - halfWidth * 0.3, top + height * 0.6))
        light.closeSubpath()
        context.fill(light, with: .color(Theme.Palette.moss.opacity(0.22)))
    }

    private func drawLeaf(in context: inout GraphicsContext, at origin: CGPoint, angle: Double, length: CGFloat, width: CGFloat) {
        var leafContext = context
        leafContext.translateBy(x: origin.x, y: origin.y)
        leafContext.rotate(by: .degrees(angle))
        var leaf = Path()
        leaf.move(to: .zero)
        leaf.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -width))
        leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: width * 0.6))
        leafContext.fill(leaf, with: .color(Theme.Palette.canopy))
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
