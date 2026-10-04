import SwiftUI
import SequoiaCore

/// Second-generation tree art. Each stage has its own silhouette, following how a
/// real giant sequoia changes with age:
/// - seed: an egg-shaped sequoia cone resting on the soil
/// - sprout: a red-stemmed seedling with a starburst of needle-like seed leaves
/// - sapling and young sequoia: a narrow, pointed spire with foliage to the ground
/// - grown sequoia: a massive buttressed trunk, bare low down, with stout crooked
///   limbs holding flat-bottomed clouds of foliage and a rounded crown
///
/// Unit coordinate space (x: 0...1 of the width, y: 0...1 of the height, y grows down).
struct TreeArt {
    static let aspectRatio: CGFloat = 0.5
    static let groundY: CGFloat = 0.955

    let stage: TreeStage
    let showsGround: Bool
    let variant: Int

    // Shading overlays. They darken or warm whatever palette color sits beneath,
    // so they work on both the light and dark variants of `bark` and `canopy`.
    private static let shade = Color.black.opacity(0.16)
    private static let deepShade = Color.black.opacity(0.26)
    private static let light = Theme.Palette.sunlight.opacity(0.22)
    /// Sunlight on foliage: a fresh lift with a touch of warmth, rather than the
    /// olive that amber alone gives over green.
    private static let foliageLift = Color.white.opacity(0.13)
    private static let foliageWarmth = Theme.Palette.sunlight.opacity(0.08)
    /// Below this height the art drops fine detail (furrows, limbs, many tiers)
    /// so it stays legible on complications and lock screen widgets.
    static let compactHeight: CGFloat = 56

    private func lightFoliage(_ c: inout GraphicsContext, _ path: Path) {
        c.fill(path, with: .color(Self.foliageLift))
        c.fill(path, with: .color(Self.foliageWarmth))
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let s = Space(w: size.width, h: size.height)
        var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: variant) &* 0x9E37_79B9 &+ 17)
        let compact = size.height < Self.compactHeight

        switch stage {
        case .seed:
            if showsGround { drawGround(&context, s, halfWidth: 0.34) }
            drawCone(&context, s)
        case .sprout:
            if showsGround { drawGround(&context, s, halfWidth: 0.3) }
            drawSeedling(&context, s)
        case .sapling:
            if showsGround { drawGround(&context, s, halfWidth: 0.34) }
            drawSpire(&context, s, top: 0.36, base: 0.87, halfWidth: 0.2, tiers: compact ? 4 : 6,
                      trunkHalf: 0.022, compact: compact, rng: &rng)
        case .youngSequoia:
            if showsGround { drawGround(&context, s, halfWidth: 0.42) }
            drawSpire(&context, s, top: 0.08, base: 0.8, halfWidth: 0.3, tiers: compact ? 5 : 10,
                      trunkHalf: 0.05, compact: compact, rng: &rng)
        case .grownSequoia:
            if showsGround { drawGround(&context, s, halfWidth: 0.48) }
            drawGiant(&context, s, compact: compact, rng: &rng)
        }
    }

    // MARK: Ground

    private func drawGround(_ c: inout GraphicsContext, _ s: Space, halfWidth: CGFloat) {
        let y = Self.groundY
        c.fill(Path(ellipseIn: s.rect(0.5 - halfWidth, y - 0.022, halfWidth * 2, 0.044)),
               with: .color(Theme.Palette.moss))
    }

    // MARK: Seed: a sequoia cone

    private func drawCone(_ c: inout GraphicsContext, _ s: Space) {
        var cone = c
        cone.translateBy(x: 0.5 * s.w, y: (Self.groundY - 0.055) * s.h)
        cone.rotate(by: .degrees(-24))
        let length = 0.46 * s.w, girth = 0.32 * s.w
        let body = Path(ellipseIn: CGRect(x: -length / 2, y: -girth / 2, width: length, height: girth))
        cone.fill(body, with: .color(Theme.Palette.bark))

        // Diamond-shaped scales, the cone's signature texture.
        var scales = cone
        scales.clip(to: body)
        var grid = Path()
        let step = girth * 0.36
        var offset = -length
        while offset < length {
            grid.move(to: CGPoint(x: offset, y: -girth))
            grid.addLine(to: CGPoint(x: offset + girth * 2, y: girth))
            grid.move(to: CGPoint(x: offset, y: girth))
            grid.addLine(to: CGPoint(x: offset + girth * 2, y: -girth))
            offset += step
        }
        scales.stroke(grid, with: .color(Self.deepShade), lineWidth: max(0.6, 0.028 * s.w))
        scales.fill(Path(ellipseIn: CGRect(x: -length * 0.42, y: -girth * 0.5, width: length * 0.7, height: girth * 0.5)),
                    with: .color(Self.light))
        scales.fill(Path(CGRect(x: -length, y: girth * 0.18, width: length * 2, height: girth)),
                    with: .color(Self.shade))

        // A short woody stalk.
        var stalk = Path()
        stalk.move(to: CGPoint(x: length * 0.47, y: 0))
        stalk.addLine(to: CGPoint(x: length * 0.62, y: -girth * 0.08))
        cone.stroke(stalk, with: .color(Theme.Palette.bark), style: StrokeStyle(lineWidth: max(1, 0.05 * s.w), lineCap: .round))
    }

    // MARK: Sprout: a seedling

    private func drawSeedling(_ c: inout GraphicsContext, _ s: Space) {
        let top = s.p(0.5, 0.82)
        var stem = Path()
        stem.move(to: s.p(0.5, Self.groundY))
        stem.addQuadCurve(to: top, control: s.p(0.475, 0.89))
        // Sequoia seedlings have a reddish stem.
        c.stroke(stem, with: .color(Theme.Palette.bark), style: StrokeStyle(lineWidth: max(1.5, 0.06 * s.w), lineCap: .round))

        // Seed leaves spread almost flat, like a small star.
        for (angle, length) in [(-172.0, 0.2), (-8.0, 0.2), (-148.0, 0.17), (-32.0, 0.17)] {
            drawNeedle(&c, at: top, angle: angle, length: length * s.w, width: 0.045 * s.w)
        }
        // Above them, the first true shoot: a tiny upright conifer sprig with
        // pairs of short needles, the seedling's future trunk.
        let tip = s.p(0.5, 0.7)
        var shoot = Path()
        shoot.move(to: top)
        shoot.addLine(to: tip)
        c.stroke(shoot, with: .color(Theme.Palette.canopy), style: StrokeStyle(lineWidth: max(1, 0.035 * s.w), lineCap: .round))
        for (index, y) in [0.795, 0.765, 0.735, 0.71].enumerated() {
            let length = (0.13 - CGFloat(index) * 0.025) * s.w
            for angle in [-90.0 - 52, -90.0 + 52] {
                drawNeedle(&c, at: s.p(0.5, y), angle: angle, length: length, width: 0.032 * s.w)
            }
        }
    }

    private func drawNeedle(_ c: inout GraphicsContext, at origin: CGPoint, angle: Double, length: CGFloat, width: CGFloat) {
        var leaf = c
        leaf.translateBy(x: origin.x, y: origin.y)
        leaf.rotate(by: .degrees(angle))
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.45, y: -width))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.45, y: width * 0.7))
        leaf.fill(path, with: .color(Theme.Palette.canopy))
    }

    // MARK: Sapling and young sequoia: a pointed spire

    private func drawSpire(_ c: inout GraphicsContext, _ s: Space, top: CGFloat, base: CGFloat,
                           halfWidth: CGFloat, tiers: Int, trunkHalf: CGFloat, compact: Bool,
                           rng: inout SeededRandom) {
        let cx: CGFloat = 0.5
        let ground = Self.groundY

        // Trunk, visible only below the foliage, with a slight flare.
        var trunk = Path()
        trunk.move(to: s.p(cx - trunkHalf * 0.6, base - 0.1))
        trunk.addLine(to: s.p(cx + trunkHalf * 0.6, base - 0.1))
        trunk.addQuadCurve(to: s.p(cx + trunkHalf * 1.5, ground), control: s.p(cx + trunkHalf, ground - 0.03))
        trunk.addLine(to: s.p(cx - trunkHalf * 1.5, ground))
        trunk.addQuadCurve(to: s.p(cx - trunkHalf * 0.6, base - 0.1), control: s.p(cx - trunkHalf, ground - 0.03))
        trunk.closeSubpath()
        c.fill(trunk, with: .color(Theme.Palette.bark))

        // Foliage: a narrow cone whose edges are rows of drooping sprays. Rows
        // vary in spacing, and each side varies on its own, so no two rows match.
        let weights = (0..<tiers).map { _ in rng.range(0.75, 1.3) }
        let total = weights.reduce(0, +)
        var ys: [CGFloat] = []
        var y = top
        for weight in weights {
            y += (base - top) * weight / total
            ys.append(y)
        }
        typealias Segment = (point: CGPoint, control: CGPoint)
        /// One side's outline, as offsets from the centre line (x > 0).
        func side() -> [Segment] {
            var segments: [Segment] = []
            var previousY = top
            for (i, y) in ys.enumerated() {
                let step = y - previousY
                let t = (y - top) / (base - top)
                let half = halfWidth * pow(t, 0.8) * (1 + rng.range(-0.13, 0.13))
                let droop = rng.range(0.6, 0.9)
                segments.append((CGPoint(x: half, y: y), CGPoint(x: half * 0.92, y: y - step * droop)))
                if i < ys.count - 1 {
                    let nextStep = ys[i + 1] - y
                    segments.append((CGPoint(x: half * rng.range(0.55, 0.7), y: y - nextStep * 0.12),
                                     CGPoint(x: half * 0.86, y: y + step * 0.08)))
                }
                previousY = y
            }
            return segments
        }
        let right = side()
        let left = side()
        let lastStep = (ys.last ?? base) - (ys.count > 1 ? ys[ys.count - 2] : top)

        var foliage = Path()
        foliage.move(to: s.p(cx, top))
        for segment in right {
            foliage.addQuadCurve(to: s.p(cx + segment.point.x, segment.point.y), to: s,
                                 control: CGPoint(x: cx + segment.control.x, y: segment.control.y))
        }
        let bottomY = ys.last ?? base
        foliage.addQuadCurve(to: s.p(cx - (left.last?.point.x ?? 0), bottomY), control: s.p(cx, bottomY + lastStep * 0.7))
        // Back up the left side: each curve runs from point k + 1 to point k
        // using segment k + 1's control, so it matches the shape going down.
        for k in stride(from: left.count - 2, through: 0, by: -1) {
            let control = left[k + 1].control
            foliage.addQuadCurve(to: s.p(cx - left[k].point.x, left[k].point.y), to: s,
                                 control: CGPoint(x: cx - control.x, y: control.y))
        }
        if let first = left.first {
            foliage.addQuadCurve(to: s.p(cx, top), to: s, control: CGPoint(x: cx - first.control.x, y: first.control.y))
        }
        foliage.closeSubpath()
        c.fill(foliage, with: .color(Theme.Palette.canopy))

        var lit = c
        lit.clip(to: foliage)
        // Light catches the top of each spray on the left; the right side and
        // the underside of each spray fall into shade.
        if !compact {
            var previousY = top
            for (i, y) in ys.enumerated() {
                let step = y - previousY
                let half = left[i * 2].point.x
                lightFoliage(&lit, Path(ellipseIn: s.rect(cx - half * 1.1, y - step * 0.95, half * 1.0, step * 0.35)))
                lit.fill(Path(ellipseIn: s.rect(cx - half * 1.2, y - step * 0.18, half * 2.4, step * 0.36)),
                         with: .color(Self.shade.opacity(0.7)))
                previousY = y
            }
        }
        var shadeSide = Path()
        shadeSide.move(to: s.p(cx + halfWidth * 0.15, top))
        shadeSide.addLine(to: s.p(cx + halfWidth * 1.4, base + 0.1))
        shadeSide.addLine(to: s.p(cx + halfWidth * 0.45, base + 0.1))
        shadeSide.closeSubpath()
        lit.fill(shadeSide, with: .color(Self.shade))
    }

    // MARK: Grown sequoia: the giant

    private func drawGiant(_ c: inout GraphicsContext, _ s: Space, compact: Bool, rng: inout SeededRandom) {
        let ground = Self.groundY
        let cx = 0.5 + rng.range(-0.012, 0.012)
        let crownBase: CGFloat = 0.56 + rng.range(-0.03, 0.03)
        let crownTop: CGFloat = 0.05 + rng.range(0, 0.03)
        let crownWidth: CGFloat = 0.25 + rng.range(-0.03, 0.03)
        // Old giants often lose their leader and grow a broad, flattened top.
        let flatTop = rng.unit() < 0.35
        // The trunk ends inside the crown's cap so it never pokes through.
        let trunkTop = crownTop + 0.05

        /// Trunk half-width at height y: a gentle taper, then a strong buttress flare.
        func half(_ y: CGFloat) -> CGFloat {
            let taper = 0.018 + max(0, min(1, (y - 0.04) / 0.76)) * 0.062
            let flare = pow(max(0, (y - 0.76) / (ground - 0.76)), 2.4) * 0.15
            return taper + flare
        }

        // Trunk.
        var trunk = Path()
        let samples = stride(from: trunkTop, through: ground, by: 0.01).map { CGFloat($0) }
        trunk.move(to: s.p(cx, trunkTop))
        for y in samples {
            trunk.addLine(to: s.p(cx + half(y) + sin(y * 31) * 0.003, y))
        }
        for y in samples.reversed() {
            trunk.addLine(to: s.p(cx - half(y) + sin(y * 27 + 1) * 0.003, y))
        }
        trunk.closeSubpath()
        c.fill(trunk, with: .color(Theme.Palette.bark))

        // Deep vertical furrows, a sunlit left side and a shaded right side.
        var bark = c
        bark.clip(to: trunk)
        func band(from a: CGFloat, to b: CGFloat) -> Path {
            var path = Path()
            path.move(to: s.p(cx + a * half(trunkTop), trunkTop))
            for y in samples { path.addLine(to: s.p(cx + a * half(y), y)) }
            for y in samples.reversed() { path.addLine(to: s.p(cx + b * half(y), y)) }
            path.closeSubpath()
            return path
        }
        bark.fill(band(from: -1.1, to: -0.45), with: .color(Self.light))
        bark.fill(band(from: 0.4, to: 1.1), with: .color(Self.shade))
        let furrowCount = compact ? 0 : 7
        for k in 0..<furrowCount {
            let f = (CGFloat(k) + 0.5) / CGFloat(furrowCount) * 2 - 1
            var furrow = Path()
            let start = crownBase - 0.08 + rng.range(-0.04, 0.04)
            furrow.move(to: s.p(cx + f * half(start) * 0.92, start))
            for y in stride(from: start, through: ground, by: 0.01) {
                let wobble = sin(y * 55 + CGFloat(k) * 1.7) * 0.0035
                furrow.addLine(to: s.p(cx + f * half(y) * 0.92 + wobble, y))
            }
            bark.stroke(furrow, with: .color(Self.deepShade), style: StrokeStyle(lineWidth: max(0.5, 0.0075 * s.w), lineCap: .round))
        }

        // A couple of broken branch stubs on the bare lower trunk.
        for (side, y) in compact ? [] : [(CGFloat(1), crownBase + 0.07), (-1, crownBase + 0.13)] {
            var stub = Path()
            let start = s.p(cx + side * half(y) * 0.8, y)
            stub.move(to: start)
            stub.addLine(to: s.p(cx + side * (half(y) + 0.035), y - 0.015))
            c.stroke(stub, with: .color(Theme.Palette.bark), style: StrokeStyle(lineWidth: max(1, 0.018 * s.w), lineCap: .round))
        }

        // The crown: a dense, rounded column of overlapping foliage clouds. Most
        // of the upper trunk hides behind them; a few gaps show stout limbs.
        /// Crown half-width at height y: a rounded dome easing into a column.
        func envelope(_ y: CGFloat) -> CGFloat {
            let t = max(0, min(1, (y - crownTop) / (crownBase - crownTop)))
            let dome = sqrt(min(1, t / 0.35))
            let skirt = 1 - pow(max(0, (t - 0.85) / 0.15), 2) * 0.25
            return crownWidth * dome * skirt
        }

        struct Cloud { var x: CGFloat; var y: CGFloat; var r: CGFloat; var stretch: CGFloat = 1; var depth: Int }
        var clouds: [Cloud] = []
        // Fewer, larger pads at small sizes keep the silhouette readable.
        let rows = compact ? 4 : 8
        let padScale: CGFloat = compact ? 1.5 : 1
        let rowStep = (crownBase - crownTop - 0.06) / CGFloat(rows - 1)
        var side: CGFloat = rng.unit() < 0.5 ? -1 : 1
        for row in 0..<rows {
            let t = CGFloat(row) / CGFloat(rows - 1)
            let y = crownTop + 0.03 + t * (crownBase - crownTop - 0.06)
            let e = envelope(y + 0.02)
            // Wide, shaded clouds behind every other row fill the crown's middle.
            if compact || row % 2 == 1 {
                clouds.append(Cloud(x: cx + rng.range(-0.03, 0.03), y: y + rowStep * 0.4, r: 0.04 + e * 0.6, depth: 0))
            }
            // Pads alternate sides, half a row apart, so the crown never mirrors.
            for pass in 0..<2 {
                // Leave an occasional gap so a limb and the trunk show through.
                if !compact, row > 1, rng.unit() < 0.25 { side = -side; continue }
                let padY = y + CGFloat(pass) * rowStep * 0.5 + rng.range(-0.01, 0.01)
                let padE = envelope(padY + 0.02)
                let x = cx + side * max(0.02, padE - (compact ? 0.09 : 0.06)) * (1 + rng.range(-0.15, 0.1))
                // Pads vary in size and breadth: some big and spreading, some small and tight.
                let r = (0.05 + padE * 0.34) * rng.range(0.75, 1.22) * padScale
                clouds.append(Cloud(x: x, y: padY, r: r, stretch: rng.range(0.85, 1.2), depth: 1))
                side = -side
            }
        }
        // A rounded cap over the top of the crown.
        clouds.append(Cloud(x: cx + rng.range(-0.01, 0.01), y: crownTop + (flatTop ? 0.025 : 0.015),
                            r: crownWidth * (flatTop ? 0.66 : 0.5), depth: 1))

        // Limbs reaching out to the side clouds.
        for cloud in clouds where cloud.depth == 1 && !compact {
            let side: CGFloat = cloud.x < cx ? -1 : 1
            var limb = Path()
            limb.move(to: s.p(cx, cloud.y + 0.04))
            limb.addQuadCurve(to: s.p(cloud.x - side * cloud.r * 0.2, cloud.y + 0.005),
                              control: s.p(cx + side * abs(cloud.x - cx) * 0.6, cloud.y + 0.045))
            c.stroke(limb, with: .color(Theme.Palette.bark),
                     style: StrokeStyle(lineWidth: max(1, half(cloud.y) * 0.8 * s.w), lineCap: .round))
        }

        for cloud in clouds.sorted(by: { ($0.depth, $0.y) < ($1.depth, $1.y) }) {
            drawFoliageCloud(&c, s, x: cloud.x, y: cloud.y, r: cloud.r, stretch: cloud.stretch,
                             back: cloud.depth == 0, lit: !compact, rng: &rng)
        }
    }

    /// A rounded, cauliflower-like cloud of foliage, lit from the upper left,
    /// with a shaded flat underside.
    private func drawFoliageCloud(_ c: inout GraphicsContext, _ s: Space, x: CGFloat, y: CGFloat, r: CGFloat,
                                  stretch: CGFloat, back: Bool, lit hasRim: Bool, rng: inout SeededRandom) {
        let center = s.p(x, y)
        let radius = r * s.w
        func ellipse(_ dx: CGFloat, _ dy: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: center.x + (dx - rw) * stretch * radius, y: center.y + (dy - rh) * radius,
                                   width: rw * 2 * stretch * radius, height: rh * 2 * radius))
        }
        var cloud = ellipse(0, 0.08, 1.0, 0.36)
        cloud.addPath(ellipse(-0.42 + rng.range(-0.08, 0.08), -0.08, 0.5, 0.36))
        cloud.addPath(ellipse(0.4 + rng.range(-0.08, 0.08), -0.06, 0.52, 0.34))
        cloud.addPath(ellipse(rng.range(-0.15, 0.15), -0.24, 0.5, 0.34))

        c.fill(cloud, with: .color(Theme.Palette.canopy))
        var lit = c
        lit.clip(to: cloud)
        if back {
            lit.fill(cloud, with: .color(Self.shade))
        } else {
            if hasRim {
                // A thin sunlit rim along the top of the pad.
                var rim = lit
                rim.clip(to: ellipse(-0.05, -0.62, 1.05, 0.4))
                lightFoliage(&rim, cloud)
            }
            lit.fill(Path(CGRect(x: center.x - radius * 1.2 * stretch, y: center.y + radius * 0.22,
                                 width: radius * 2.4 * stretch, height: radius)), with: .color(Self.shade))
        }
    }
}

// MARK: - Helpers

/// Maps unit coordinates to the drawing's size.
private struct Space {
    let w: CGFloat
    let h: CGFloat

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> CGRect {
        CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h)
    }
}

private extension Path {
    /// Adds a quadratic curve whose control point is given in unit coordinates.
    mutating func addQuadCurve(to point: CGPoint, to space: Space, control: CGPoint) {
        addQuadCurve(to: point, control: space.p(control.x, control.y))
    }
}

/// A small deterministic random generator (SplitMix64), so each tree's variation
/// is stable across launches, devices and the widget and watch.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<1.
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }

    mutating func range(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat { lower + unit() * (upper - lower) }
}
