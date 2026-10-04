import SwiftUI
import SequoiaCore

/// The user's forest as a layered landscape: misty hills receding to the
/// horizon, older trees fading into the fog, the newest towering in front, and
/// the in-progress tree standing in a patch of sunlight.
public struct ForestScene: View {
    private let layout: ForestLayout
    private let currentStage: TreeStage?
    private let light: ForestLight
    private let undergrowth: Undergrowth

    /// - Parameters:
    ///   - planted: the number of trees planted in the forest.
    ///   - currentStage: the in-progress tree's stage, or `nil` to leave it out.
    ///   - light: the time of day's light.
    ///   - undergrowth: ferns and flowers on the forest floor.
    public init(planted: Int, currentStage: TreeStage?, light: ForestLight = .midday, undergrowth: Undergrowth = .none) {
        layout = ForestLayout(planted: planted)
        self.currentStage = currentStage
        self.light = light
        self.undergrowth = undergrowth
    }

    /// The color of the foreground ground in this light, for extending the
    /// forest floor beyond the scene's frame.
    public static func floorColor(_ light: ForestLight = .midday) -> some View {
        ZStack {
            Theme.Palette.moss
            Theme.Palette.sunlight.opacity(ForestSceneRenderer.warmWash * light.warmth)
            Color.black.opacity(ForestSceneRenderer.nightDim * light.night)
            Theme.Palette.fog.opacity(ForestSceneRenderer.foregroundVeil)
        }
    }

    public var body: some View {
        Canvas { context, size in
            ForestSceneRenderer(layout: layout, currentStage: currentStage, light: light, undergrowth: undergrowth)
                .draw(in: &context, size: size)
        }
        .clipped()
    }
}

struct ForestSceneRenderer {
    let layout: ForestLayout
    let currentStage: TreeStage?
    var light: ForestLight = .midday
    var undergrowth: Undergrowth = .none

    /// The in-progress tree's height relative to a grown tree, so the forest
    /// shows true scale: a seed is tiny beside the giants it will become.
    static func relativeHeight(of stage: TreeStage) -> CGFloat {
        switch stage {
        case .seed: 0.1
        case .sprout: 0.14
        case .sapling: 0.24
        case .youngSequoia: 0.5
        case .grownSequoia: 1
        }
    }

    /// Each layer's hill tint, from faint at the horizon to solid in front.
    private static func hillColor(_ layer: ForestLayout.Layer) -> Color {
        switch layer {
        case .horizon: Theme.Palette.canopy.opacity(0.1)
        case .far: Theme.Palette.canopy.opacity(0.16)
        case .mid: Theme.Palette.canopy.opacity(0.24)
        case .near: Theme.Palette.moss
        }
    }

    /// The fog laid over everything behind a layer before that layer is drawn.
    static let foregroundVeil = 0.12
    /// How strongly golden hour warms, and night dims, the whole scene.
    static let warmWash = 0.2
    static let nightDim = 0.32

    private static func fogBefore(_ layer: ForestLayout.Layer) -> Double {
        switch layer {
        case .horizon: 0
        case .far: 0.42
        case .mid: 0.36
        case .near: 0.24
        }
    }

    /// The height of a layer's hill at x (0...1 across the scene), as a
    /// fraction of the scene height.
    private static func ground(_ layer: ForestLayout.Layer, at x: CGFloat) -> CGFloat {
        let phase = CGFloat(layer.rawValue) * 1.9
        let amplitude: CGFloat = layer == .near ? 0.018 : 0.03
        return layer.groundLine
            + sin(x * 5.2 + phase) * amplitude
            + sin(x * 11.7 + phase * 2) * amplitude * 0.35
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let full = Path(CGRect(origin: .zero, size: size))
        drawSky(in: &context, size: size)
        for layer in ForestLayout.Layer.allCases {
            // Mist thins at night so the far hills sink into the dark.
            let fog = Self.fogBefore(layer) * (1 - 0.55 * Double(light.night)) + (layer == .horizon ? 0 : 0.2 * Double(light.mist))
            if fog > 0 { context.fill(full, with: .color(Theme.Palette.fog.opacity(fog))) }
            drawLayer(layer, in: &context, size: size)
        }
        drawUndergrowth(in: &context, size: size)
        // Golden hour warms everything; night dims it.
        if light.warmth > 0 {
            context.fill(full, with: .color(Theme.Palette.sunlight.opacity(Self.warmWash * light.warmth)))
        }
        if light.night > 0 {
            context.fill(full, with: .color(Color.black.opacity(Self.nightDim * light.night)))
        }
        // A light veil keeps the foreground from overpowering the scene (most of
        // all the pale dark-mode canopy), and today's tree stands above it, the
        // brightest thing in view.
        context.fill(full, with: .color(Theme.Palette.fog.opacity(Self.foregroundVeil)))
        if let currentStage { drawCurrentTree(currentStage, in: &context, size: size) }
    }

    private func drawSky(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let full = Path(CGRect(origin: .zero, size: size))
        context.fill(full, with: .color(Theme.Palette.fog))
        if light.warmth > 0 {
            context.fill(full, with: .color(Theme.Palette.sunlight.opacity(0.42 * light.warmth)))
        }
        if light.night > 0 {
            context.fill(full, with: .color(Theme.Palette.canopy.opacity(0.55 * light.night)))
            context.fill(full, with: .color(Color.black.opacity(0.4 * light.night)))
            // A scatter of stars, steady from night to night.
            var rng = SeededRandom(seed: 0x57A2_5EED)
            var stars = Path()
            for _ in 0..<26 {
                let x = rng.range(0.02, 0.98), y = rng.range(0.03, 0.42), r = rng.range(0.9, 1.9)
                stars.addEllipse(in: CGRect(x: x * w - r, y: y * h - r, width: r * 2, height: r * 2))
            }
            context.fill(stars, with: .color(Theme.Palette.sunlight.opacity(light.night)))
        }
        // The sun, or a paler moon, glowing through the mist.
        let radius = h * (light.night > 0 ? 0.06 : 0.09)
        let orb = CGRect(x: w * light.orbX - radius, y: h * light.orbY - radius, width: radius * 2, height: radius * 2)
        let glow = light.night > 0 ? 0.12 : 0.1 + 0.2 * light.warmth
        let body = light.night > 0 ? 0.85 : 0.28 + 0.4 * light.warmth
        context.fill(Path(ellipseIn: orb.insetBy(dx: -h * 0.06, dy: -h * 0.06)),
                     with: .color(Theme.Palette.sunlight.opacity(glow)))
        context.fill(Path(ellipseIn: orb), with: .color(Theme.Palette.sunlight.opacity(body)))
    }

    /// Ferns and wildflowers along the foreground, clear of today's tree.
    private func drawUndergrowth(in context: inout GraphicsContext, size: CGSize) {
        var rng = SeededRandom(seed: 0xF3_2A5)
        func spot() -> CGPoint {
            var x = rng.range(0.02, 0.98)
            if abs(x - ForestLayout.currentTreeX) < 0.09 { x = x < ForestLayout.currentTreeX ? x - 0.1 : x + 0.1 }
            let y = Self.ground(.near, at: x) + rng.range(0.03, 0.1)
            return CGPoint(x: x * size.width, y: y * size.height)
        }
        for _ in 0..<min(undergrowth.ferns, Undergrowth.maxFerns) {
            drawFern(&context, at: spot(), height: size.height * rng.range(0.06, 0.1), lean: rng.range(-0.15, 0.15))
        }
        var flowers = Path(), stems = Path()
        var accents = Path()
        for index in 0..<min(undergrowth.flowers, Undergrowth.maxFlowers) {
            let base = spot()
            let height = size.height * rng.range(0.03, 0.055)
            let top = CGPoint(x: base.x + rng.range(-2, 2), y: base.y - height)
            stems.move(to: base)
            stems.addLine(to: top)
            let r = max(2, size.height * 0.012)
            let bloom = CGRect(x: top.x - r, y: top.y - r, width: r * 2, height: r * 2)
            if index % 3 == 2 { accents.addEllipse(in: bloom) } else { flowers.addEllipse(in: bloom) }
        }
        context.stroke(stems, with: .color(Theme.Palette.canopy), lineWidth: max(0.8, size.height * 0.003))
        context.fill(flowers, with: .color(Theme.Palette.sunlight))
        context.fill(accents, with: .color(Theme.Palette.bark))
    }

    /// A small fern: arching fronds fanning from one point.
    private func drawFern(_ context: inout GraphicsContext, at base: CGPoint, height: CGFloat, lean: CGFloat) {
        var fronds = Path()
        for (angle, length) in [(-150.0, 0.8), (-120.0, 1.0), (-90.0, 1.05), (-60.0, 1.0), (-30.0, 0.8)] {
            let radians = (angle + Double(lean) * 60) * .pi / 180
            let tip = CGPoint(x: base.x + cos(radians) * height * length * 0.9, y: base.y + sin(radians) * height * length)
            let control = CGPoint(x: base.x + cos(radians) * height * 0.5, y: base.y + sin(radians) * height * 0.9 - height * 0.15)
            var frond = Path()
            frond.move(to: base)
            frond.addQuadCurve(to: tip, control: control)
            fronds.addPath(frond.strokedPath(StrokeStyle(lineWidth: max(1.2, height * 0.13), lineCap: .round)))
        }
        context.fill(fronds, with: .color(Theme.Palette.canopy))
    }

    /// Draws one layer: its hill and its trees.
    private func drawLayer(_ layer: ForestLayout.Layer, in context: inout GraphicsContext, size: CGSize) {
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: size.height))
        for step in 0...48 {
            let x = CGFloat(step) / 48
            hill.addLine(to: CGPoint(x: x * size.width, y: Self.ground(layer, at: x) * size.height))
        }
        hill.addLine(to: CGPoint(x: size.width, y: size.height))
        hill.closeSubpath()
        context.fill(hill, with: .color(Self.hillColor(layer)))
        if layer == .horizon { drawWildTreeline(&context, size: size) }

        for placement in layout.placements where placement.layer == layer {
            let baseY = Self.ground(layer, at: placement.x) + placement.drop + 0.02
            Self.drawTree(&context, size: size, stage: .grownSequoia, variant: placement.index,
                          x: placement.x, baseY: baseY, height: layer.treeHeight * placement.scale)
        }
    }

    /// The in-progress tree in a patch of sunlight.
    private func drawCurrentTree(_ stage: TreeStage, in context: inout GraphicsContext, size: CGSize) {
        let x = ForestLayout.currentTreeX
        let baseY = Self.ground(.near, at: x) + 0.03
        let patch = CGRect(x: (x - 0.09) * size.width, y: (baseY - 0.025) * size.height,
                           width: 0.18 * size.width, height: 0.05 * size.height)
        context.fill(Path(ellipseIn: patch), with: .color(Theme.Palette.sunlight.opacity(0.35)))
        Self.drawTree(&context, size: size, stage: stage, variant: layout.placements.count,
                      x: x, baseY: baseY, height: ForestLayout.Layer.near.treeHeight * Self.relativeHeight(of: stage))
    }

    /// A faint wild forest along the horizon, so the scene is a place even
    /// before anything is planted. Plain silhouettes in the hill's tint, so they
    /// never read as the user's own trees.
    private func drawWildTreeline(_ context: inout GraphicsContext, size: CGSize) {
        var rng = SeededRandom(seed: 0x5EED_F0E5)
        var silhouettes = Path()
        var x: CGFloat = -0.01
        while x < 1.02 {
            let base = Self.ground(.horizon, at: x) + 0.02
            let height = rng.range(0.06, 0.13)
            let half = height * rng.range(0.16, 0.24) * size.height / size.width
            func point(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: px * size.width, y: py * size.height) }
            silhouettes.move(to: point(x - half, base))
            silhouettes.addQuadCurve(to: point(x, base - height), control: point(x - half * 0.7, base - height * 0.55))
            silhouettes.addQuadCurve(to: point(x + half, base), control: point(x + half * 0.7, base - height * 0.55))
            silhouettes.closeSubpath()
            x += rng.range(0.012, 0.03)
        }
        context.fill(silhouettes, with: .color(Theme.Palette.canopy.opacity(0.09)))
    }

    /// Draws one tree with its trunk base at (x, baseY), in fractions of `size`.
    private static func drawTree(_ context: inout GraphicsContext, size: CGSize, stage: TreeStage, variant: Int,
                                 x: CGFloat, baseY: CGFloat, height: CGFloat) {
        let treeHeight = height * size.height
        let treeWidth = treeHeight * TreeArt.aspectRatio
        var tree = context
        // TreeArt's trunk base sits at `groundY` of its frame.
        tree.translateBy(x: x * size.width - treeWidth / 2, y: baseY * size.height - treeHeight * TreeArt.groundY)
        TreeArt(stage: stage, showsGround: false, variant: variant)
            .draw(in: &tree, size: CGSize(width: treeWidth, height: treeHeight))
    }
}

#Preview("Forest · 12") {
    ForestScene(planted: 12, currentStage: .sapling).frame(height: 300)
}

#Preview("Forest · 100 – dark") {
    ForestScene(planted: 100, currentStage: .youngSequoia).frame(height: 300).preferredColorScheme(.dark)
}
