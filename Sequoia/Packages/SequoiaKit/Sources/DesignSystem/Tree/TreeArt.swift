import SwiftUI
import SequoiaCore

/// Second-generation tree art. Each stage has its own silhouette, following how a
/// real giant sequoia changes with age:
/// - seed: an egg-shaped sequoia cone resting on the soil
/// - sprout: a red-stemmed seedling with a starburst of needle-like seed leaves
/// - sapling: a broad, sharply pointed cone of clumpy foliage down to the ground
/// - young sequoia: the same youthful cone, carried on a straight bare trunk once
///   its shaded lower limbs have dropped
/// - grown sequoia: a massive buttressed trunk, bare low down, with stout crooked
///   limbs holding clumps of foliage, in one of several varieties
///   (rounded, snag-topped, twin-crowned, broad or slender)
///
/// Unit coordinate space (x: 0...1 of the width, y: 0...1 of the height, y grows down).
struct TreeArt {
    static let aspectRatio: CGFloat = 0.5
    static let groundY: CGFloat = 0.955

    let stage: TreeStage
    let showsGround: Bool
    let variant: Int
    /// Draws the compact silhouette at any size (the app icon), not only small ones.
    var simplified = false

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
        let compact = simplified || size.height < Self.compactHeight

        switch stage {
        case .seed:
            if showsGround { drawGround(&context, s, halfWidth: 0.34) }
            drawCone(&context, s)
        case .sprout:
            if showsGround { drawGround(&context, s, halfWidth: 0.3) }
            drawSeedling(&context, s)
        case .sapling:
            if showsGround { drawGround(&context, s, halfWidth: 0.34) }
            drawYoungCone(&context, s, top: 0.34, base: 0.93, halfWidth: 0.3, rows: 11, trunkHalf: 0.018,
                          compact: compact, rng: &rng)
        case .youngSequoia:
            if showsGround { drawGround(&context, s, halfWidth: 0.42) }
            drawYoungCone(&context, s, top: 0.06, base: 0.68, halfWidth: 0.27, rows: 13, trunkHalf: 0.045,
                          compact: compact, rng: &rng)
        case .grownSequoia:
            if showsGround { drawGround(&context, s, halfWidth: 0.48) }
            drawGiant(&context, s, form: Self.giantForm(.of(variant: variant), &rng), compact: compact, rng: &rng)
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

    // MARK: Sapling and young sequoia: the youthful cone

    /// A young sequoia is an evenly tapered, sharply pointed cone of dense,
    /// clumpy foliage. A sapling keeps that foliage to the ground; as the tree
    /// grows, its shaded lower limbs die and drop, until the cone rides on a
    /// straight, bare, red trunk.
    private func drawYoungCone(_ c: inout GraphicsContext, _ s: Space, top: CGFloat, base: CGFloat,
                               halfWidth: CGFloat, rows: Int, trunkHalf: CGFloat, compact: Bool,
                               rng: inout SeededRandom) {
        let ground = Self.groundY
        let cx: CGFloat = 0.5 + rng.range(-0.006, 0.006)
        /// Cone half-width at height y, with a softly rounded base.
        func envelope(_ y: CGFloat) -> CGFloat {
            let t = max(0, min(1, (y - top) / (base - top)))
            let round = 1 - pow(max(0, (t - 0.86) / 0.14), 2) * 0.14
            return halfWidth * (0.05 + 0.95 * pow(t, 0.95)) * round
        }

        // A straight trunk with a slight flare at the ground.
        var trunk = Path()
        let trunkTop = top + (base - top) * 0.3
        trunk.move(to: s.p(cx - trunkHalf * 0.35, trunkTop))
        trunk.addLine(to: s.p(cx + trunkHalf * 0.35, trunkTop))
        trunk.addLine(to: s.p(cx + trunkHalf, ground - 0.05))
        trunk.addQuadCurve(to: s.p(cx + trunkHalf * 1.8, ground), control: s.p(cx + trunkHalf * 1.05, ground - 0.012))
        trunk.addLine(to: s.p(cx - trunkHalf * 1.8, ground))
        trunk.addQuadCurve(to: s.p(cx - trunkHalf, ground - 0.05), control: s.p(cx - trunkHalf * 1.05, ground - 0.012))
        trunk.closeSubpath()
        c.fill(trunk, with: .color(Theme.Palette.bark))
        var bark = c
        bark.clip(to: trunk)
        bark.fill(Path(s.rect(cx - trunkHalf * 2, top, trunkHalf * 1.5, 1)), with: .color(Self.light))
        bark.fill(Path(s.rect(cx + trunkHalf * 0.35, top, trunkHalf * 2, 1)), with: .color(Self.shade))

        // Dead, self-pruned twigs on the bare stretch of trunk.
        if !compact && ground - base > 0.1 {
            for (k, side) in [CGFloat(-1), 1, -1].enumerated() {
                let y = base + 0.035 + CGFloat(k) * (ground - base - 0.09) / 3
                var twig = Path()
                twig.move(to: s.p(cx + side * trunkHalf * 0.6, y))
                twig.addLine(to: s.p(cx + side * (trunkHalf + 0.05), y + 0.012))
                c.stroke(twig, with: .color(Theme.Palette.bark),
                         style: StrokeStyle(lineWidth: max(0.8, trunkHalf * 0.35 * s.w), lineCap: .round))
            }
        }

        // A dark inner body, so the cone stays solid between the tufts.
        var body = Path()
        body.move(to: s.p(cx, top + 0.02))
        for y in stride(from: top + 0.02, through: base, by: 0.01) { body.addLine(to: s.p(cx + envelope(y) * 0.85, y)) }
        for y in stride(from: base, through: top + 0.02, by: -0.01) { body.addLine(to: s.p(cx - envelope(y) * 0.85, y)) }
        body.closeSubpath()
        c.fill(body, with: .color(Theme.Palette.canopy))
        c.fill(body, with: .color(Self.deepShade))

        // The sharp leader.
        var leader = Path()
        let leaderHalf = halfWidth * 0.06
        leader.move(to: s.p(cx - leaderHalf, top + 0.05))
        leader.addQuadCurve(to: s.p(cx, top - 0.03), control: s.p(cx - leaderHalf * 0.4, top))
        leader.addQuadCurve(to: s.p(cx + leaderHalf, top + 0.05), control: s.p(cx + leaderHalf * 0.4, top))
        leader.closeSubpath()
        c.fill(leader, with: .color(Theme.Palette.canopy))

        // Rows of tufts across the cone, top to bottom so each row's sunlit tops
        // sit against the shaded undersides of the row above.
        let rowCount = compact ? max(5, rows / 2) : rows
        let step = (base - top) / CGFloat(rowCount)
        for row in 0..<rowCount {
            let y = top + step * (CGFloat(row) + 0.7)
            let e = envelope(y)
            // `step * 2` converts a height to width units (the art is half as wide as tall).
            let rx = max(0.022, min(e * 0.8, step * 2 * (compact ? 1.45 : 1.1)))
            let count = max(1, Int((2 * e / (rx * 1.3)).rounded(.up)))
            let reach = max(0, e - rx * 0.75)
            // Centre tufts first, then outwards, so the edge tufts bulge over them.
            let order = (0..<count).sorted { abs(CGFloat($0) - CGFloat(count - 1) / 2) < abs(CGFloat($1) - CGFloat(count - 1) / 2) }
            for k in order {
                let f = count == 1 ? 0 : CGFloat(k) / CGFloat(count - 1) * 2 - 1
                // Edge tufts droop a little, like the young tree's swooping limbs.
                let droop = abs(f) * step * 0.3 + rng.range(-0.004, 0.004)
                let size = rng.range(0.88, 1.12)
                drawTuft(&c, s, x: cx + f * reach + rng.range(-0.008, 0.008), y: y + droop,
                         rx: rx * size, ry: rx * size * 0.62, shaded: f > 0.25 ? 0.07 : 0,
                         detailed: !compact, rng: &rng)
            }
        }
    }

    // MARK: Grown sequoia: the giant

    /// The proportions of one grown giant.
    private struct GiantForm {
        enum Top { case dome, flat, twin }

        var top: Top = .dome
        var crownTop: CGFloat
        var crownBase: CGFloat
        var crownWidth: CGFloat
        /// How far the top of the crown drifts sideways from the trunk base.
        var lean: CGFloat = 0
        var trunkBody: CGFloat = 0.08
        var flare: CGFloat = 0.15
        var limbs = 7
        var reach: CGFloat = 1
        var tuftScale: CGFloat = 1
        var stubs = 2
        /// A dead, silvered spike above the crown where the leader broke off.
        var snag = false
        /// A charred cavity at the base from an old fire.
        var fireScar = false
    }

    /// Named kinds of grown giant, so the trees of a forest differ in character
    /// and not only in detail.
    enum Variety: CaseIterable {
        /// A dense, rounded crown on a straight column.
        case classic
        /// A flattened crown below the dead spike of a lightning-struck leader.
        case snagTop
        /// The trunk forks high up into two rounded tops, like the Clothespin Tree.
        case twinCrown
        /// Long, heavy limbs in a wide crown on a massive, leaning trunk.
        case broad
        /// A tall, narrow crown high on a long bare trunk.
        case slender

        var title: String {
            switch self {
            case .classic: "Classic"
            case .snagTop: "Snag top"
            case .twinCrown: "Twin crown"
            case .broad: "Broad"
            case .slender: "Slender"
            }
        }

        /// The variety for a tree, stable for its variant. Variant 0, the tree
        /// shown on its own, is always the classic giant.
        static func of(variant: Int) -> Variety {
            guard variant != 0 else { return .classic }
            var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: variant) &* 0xD1B5_4A32_D192_ED03 &+ 5)
            switch rng.unit() {
            case ..<0.28: return .classic
            case ..<0.46: return .snagTop
            case ..<0.64: return .twinCrown
            case ..<0.82: return .broad
            default: return .slender
            }
        }

        /// The first variant that draws as this variety, for galleries.
        var sampleVariant: Int {
            (0...).first { Variety.of(variant: $0) == self } ?? 0
        }
    }

    private static func giantForm(_ variety: Variety, _ rng: inout SeededRandom) -> GiantForm {
        var form = GiantForm(crownTop: 0.04 + rng.range(0, 0.03), crownBase: 0.53 + rng.range(-0.03, 0.03),
                             crownWidth: 0.28 + rng.range(-0.02, 0.02), lean: rng.range(-0.02, 0.02))
        switch variety {
        case .classic:
            form.fireScar = rng.unit() < 0.2
        case .snagTop:
            form.top = .flat
            form.crownTop = 0.16 + rng.range(0, 0.02)
            form.crownBase = 0.56 + rng.range(-0.02, 0.02)
            form.crownWidth += 0.02
            form.limbs = 6
            form.snag = true
            form.fireScar = rng.unit() < 0.5
        case .twinCrown:
            form.top = .twin
            form.crownTop = 0.06 + rng.range(0, 0.02)
            form.crownWidth = 0.3 + rng.range(-0.02, 0.02)
            form.fireScar = rng.unit() < 0.25
        case .broad:
            form.crownTop = 0.1 + rng.range(0, 0.03)
            form.crownBase = 0.5 + rng.range(-0.02, 0.02)
            form.crownWidth = 0.31 + rng.range(-0.01, 0.01)
            form.lean = (rng.unit() < 0.5 ? -1 : 1) * rng.range(0.03, 0.045)
            form.trunkBody = 0.09
            form.flare = 0.17
            form.reach = 1.08
            form.tuftScale = 1.08
            form.stubs = 3
        case .slender:
            form.crownTop = 0.03 + rng.range(0, 0.02)
            form.crownBase = 0.44 + rng.range(-0.02, 0.02)
            form.crownWidth = 0.19 + rng.range(-0.015, 0.015)
            form.trunkBody = 0.07
            form.flare = 0.12
            form.reach = 0.9
            form.tuftScale = 0.85
            form.fireScar = rng.unit() < 0.5
        }
        return form
    }

    /// A grown giant: a massive buttressed trunk, bare low down, holding a crown
    /// of a few huge, crooked limbs that bend upwards and end in dense clumps of
    /// foliage.
    private func drawGiant(_ c: inout GraphicsContext, _ s: Space, form: GiantForm, compact: Bool,
                           rng: inout SeededRandom) {
        let ground = Self.groundY
        let cx = 0.5 + rng.range(-0.012, 0.012)
        let crownTop = form.crownTop, crownBase = form.crownBase, crownWidth = form.crownWidth
        let isTwin = form.top == .twin
        // The trunk ends inside the crown so it never pokes through; a twin's
        // ends lower, where it forks.
        let trunkTop = crownTop + (isTwin ? 0.24 : 0.08)

        /// The trunk's centre at height y: straight below the crown, then
        /// drifting with the lean towards the top.
        func center(_ y: CGFloat) -> CGFloat {
            let t = max(0, min(1, (crownBase - y) / (crownBase - crownTop)))
            return cx + form.lean * pow(t, 1.5)
        }
        /// Trunk half-width at height y: a gentle taper, then the buttress flare.
        func half(_ y: CGFloat) -> CGFloat {
            let topHalf = form.trunkBody * 0.42
            let taper = topHalf + max(0, min(1, (y - crownTop) / (0.8 - crownTop))) * (form.trunkBody - topHalf)
            let flare = pow(max(0, (y - 0.76) / (ground - 0.76)), 2.4) * form.flare
            return taper + flare
        }
        /// Crown half-width at height y: a rounded top easing into a column.
        func envelope(_ y: CGFloat) -> CGFloat {
            let t = max(0, min(1, (y - crownTop) / (crownBase - crownTop)))
            let dome = sqrt(min(1, t / (form.top == .dome ? 0.32 : 0.18)))
            let skirt = 1 - pow(max(0, (t - 0.8) / 0.2), 2) * 0.3
            return crownWidth * dome * skirt
        }

        struct Tuft { var x: CGFloat; var y: CGFloat; var rx: CGFloat }
        var tufts: [Tuft] = []
        let tuftScale = form.tuftScale * (compact ? 1.3 : 1)

        // A shaded mass of foliage behind the trunk keeps the crown dense.
        var y = crownTop + 0.05
        var backSide: CGFloat = 1
        while y < crownBase - 0.03 {
            let e = envelope(y)
            let split = isTwin && y < trunkTop ? backSide * crownWidth * 0.55 : 0
            drawTuft(&c, s, x: center(y) + split + rng.range(-0.04, 0.04), y: y, rx: e * (isTwin ? 0.5 : 0.6), ry: e * 0.4,
                     back: true, detailed: !compact, rng: &rng)
            backSide = -backSide
            y += compact ? 0.09 : 0.07
        }

        // Trunk.
        var trunk = Path()
        let samples = stride(from: trunkTop, through: ground, by: 0.01).map { CGFloat($0) }
        trunk.move(to: s.p(center(trunkTop), trunkTop))
        for y in samples {
            trunk.addLine(to: s.p(center(y) + half(y) + sin(y * 31) * 0.003, y))
        }
        for y in samples.reversed() {
            trunk.addLine(to: s.p(center(y) - half(y) + sin(y * 27 + 1) * 0.003, y))
        }
        trunk.closeSubpath()
        c.fill(trunk, with: .color(Theme.Palette.bark))

        // Deep vertical furrows, a sunlit left side and a shaded right side.
        var bark = c
        bark.clip(to: trunk)
        func band(from a: CGFloat, to b: CGFloat) -> Path {
            var path = Path()
            path.move(to: s.p(center(trunkTop) + a * half(trunkTop), trunkTop))
            for y in samples { path.addLine(to: s.p(center(y) + a * half(y), y)) }
            for y in samples.reversed() { path.addLine(to: s.p(center(y) + b * half(y), y)) }
            path.closeSubpath()
            return path
        }
        bark.fill(band(from: -1.1, to: -0.45), with: .color(Self.light))
        bark.fill(band(from: 0.4, to: 1.1), with: .color(Self.shade))
        // The crown casts the upper trunk into shade.
        bark.fill(Path(s.rect(0, 0, 1, crownBase - 0.04)), with: .color(Self.shade))
        bark.fill(Path(s.rect(0, crownBase - 0.04, 1, 0.04)), with: .color(Self.shade.opacity(0.5)))
        let furrowCount = compact ? 0 : 7
        for k in 0..<furrowCount {
            let f = (CGFloat(k) + 0.5) / CGFloat(furrowCount) * 2 - 1
            var furrow = Path()
            let start = crownBase - 0.08 + rng.range(-0.04, 0.04)
            furrow.move(to: s.p(center(start) + f * half(start) * 0.92, start))
            for y in stride(from: start, through: ground, by: 0.01) {
                let wobble = sin(y * 55 + CGFloat(k) * 1.7) * 0.0035
                furrow.addLine(to: s.p(center(y) + f * half(y) * 0.92 + wobble, y))
            }
            bark.stroke(furrow, with: .color(Self.deepShade), style: StrokeStyle(lineWidth: max(0.5, 0.0075 * s.w), lineCap: .round))
        }

        // A charred cavity at the foot of the trunk, where a fire once burned
        // through the bark. Giants survive these for centuries.
        if form.fireScar && !compact {
            let x = cx + rng.range(-0.04, 0.03)
            let height = rng.range(0.08, 0.13), width = rng.range(0.03, 0.045)
            var scar = Path()
            scar.move(to: s.p(x - width, ground + 0.01))
            scar.addQuadCurve(to: s.p(x + rng.range(-0.01, 0.01), ground - height), control: s.p(x - width * 0.8, ground - height * 0.45))
            scar.addQuadCurve(to: s.p(x + width, ground + 0.01), control: s.p(x + width * 0.7, ground - height * 0.4))
            scar.closeSubpath()
            bark.fill(scar, with: .color(Self.deepShade))
            bark.fill(scar, with: .color(Self.shade))
            bark.stroke(scar, with: .color(Self.light), lineWidth: max(0.5, 0.008 * s.w))
        }

        // A few broken branch stubs on the bare lower trunk.
        for k in 0..<(compact ? 0 : form.stubs) {
            let side: CGFloat = k % 2 == 0 ? 1 : -1
            let y = crownBase + 0.06 + CGFloat(k) * 0.06
            var stub = Path()
            stub.move(to: s.p(center(y) + side * half(y) * 0.8, y))
            stub.addLine(to: s.p(center(y) + side * (half(y) + 0.035), y - 0.015))
            c.stroke(stub, with: .color(Theme.Palette.bark),
                     style: StrokeStyle(lineWidth: max(1, half(y) * 0.4 * s.w), lineCap: .round))
        }

        // The dead spike of a broken leader, bleached silver by the weather.
        if form.snag {
            let x = center(crownTop)
            var spike = Path()
            spike.move(to: s.p(x - 0.028, crownTop + 0.08))
            spike.addLine(to: s.p(x - 0.012, crownTop - 0.09))
            spike.addLine(to: s.p(x - 0.004, crownTop - 0.15))
            spike.addLine(to: s.p(x + 0.004, crownTop - 0.1))
            spike.addLine(to: s.p(x + 0.012, crownTop - 0.118))
            spike.addLine(to: s.p(x + 0.026, crownTop + 0.08))
            spike.closeSubpath()
            var limb = Path()
            limb.move(to: s.p(x + 0.006, crownTop - 0.04))
            limb.addLine(to: s.p(x + 0.07, crownTop - 0.08))
            let silver = Color.white.opacity(0.4)
            for path in [spike, limb.strokedPath(StrokeStyle(lineWidth: max(1, 0.016 * s.w), lineCap: .round))] {
                c.fill(path, with: .color(Theme.Palette.bark))
                c.fill(path, with: .color(silver))
            }
            var shaded = c
            shaded.clip(to: spike)
            shaded.fill(Path(s.rect(x, crownTop - 0.16, 0.03, 0.26)), with: .color(Self.shade))
        }

        /// A crooked limb: out from the trunk, bending at an elbow, then up.
        func drawLimb(from start: CGPoint, elbow: CGPoint, end: CGPoint, width: CGFloat) {
            var inner = Path()
            inner.move(to: s.p(start.x, start.y))
            inner.addQuadCurve(to: s.p(elbow.x, elbow.y), control: s.p((start.x + elbow.x) / 2, elbow.y + 0.012))
            c.stroke(inner, with: .color(Theme.Palette.bark),
                     style: StrokeStyle(lineWidth: max(1, width * s.w), lineCap: .round, lineJoin: .round))
            var outer = Path()
            outer.move(to: s.p(elbow.x, elbow.y))
            outer.addQuadCurve(to: s.p(end.x, end.y), control: s.p(end.x, elbow.y))
            c.stroke(outer, with: .color(Theme.Palette.bark),
                     style: StrokeStyle(lineWidth: max(1, width * 0.6 * s.w), lineCap: .round, lineJoin: .round))
        }

        // A twin's two leaders, forking from the trunk, each with its own top.
        var tops: [CGPoint] = []
        if isTwin {
            for side in [CGFloat(-1), 1] {
                let top = CGPoint(x: center(crownTop) + side * crownWidth * 0.58, y: crownTop + 0.05 + rng.range(0, 0.03))
                drawLimb(from: CGPoint(x: center(trunkTop + 0.03), y: trunkTop + 0.03),
                         elbow: CGPoint(x: center(trunkTop) + side * crownWidth * 0.35, y: trunkTop - 0.07),
                         end: top, width: half(trunkTop) * 1.1)
                tops.append(top)
            }
        } else {
            tops.append(CGPoint(x: center(crownTop), y: crownTop + (form.top == .flat ? 0.035 : 0.03)))
        }

        // The limbs, alternating sides with the odd repeat, each ending in a
        // cluster of tufts.
        let limbCount = compact ? 5 : form.limbs
        var side: CGFloat = rng.unit() < 0.5 ? -1 : 1
        let lowest = crownBase - 0.03, highest = crownTop + (isTwin ? 0.2 : 0.11)
        for k in 0..<limbCount {
            let t = CGFloat(k) / CGFloat(max(1, limbCount - 1))
            let y0 = lowest - t * (lowest - highest) + rng.range(-0.012, 0.012)
            let origin = CGPoint(x: center(y0), y: y0)
            let room = (side > 0 ? 1 - origin.x : origin.x) - 0.14
            let reach = min(0.36, room, envelope(y0 - 0.04) * rng.range(0.78, 1.05) * form.reach)
            let elbow = CGPoint(x: origin.x + side * reach * rng.range(0.45, 0.6), y: y0 + rng.range(-0.005, 0.015))
            let end = CGPoint(x: origin.x + side * reach, y: y0 - rng.range(0.035, 0.075))
            if !compact {
                drawLimb(from: origin, elbow: elbow, end: end, width: half(y0) * rng.range(0.7, 0.95))
            }
            let rx = (0.06 + reach * 0.32) * tuftScale * rng.range(0.9, 1.12)
            tufts.append(Tuft(x: end.x, y: end.y, rx: rx))
            tufts.append(Tuft(x: end.x - side * rx * 0.75, y: end.y - rx * 0.3, rx: rx * 0.72))
            if rng.unit() < 0.35 {
                tufts.append(Tuft(x: elbow.x, y: elbow.y - rx * 0.55, rx: rx * 0.6))
            }
            side = rng.unit() < 0.8 ? -side : side
        }
        // A few tufts in front of the trunk, so it disappears into the crown.
        for k in 0..<(compact ? 1 : 3) {
            let first = isTwin ? trunkTop : crownTop + 0.12
            let fy = first + (CGFloat(k) + rng.range(0.1, 0.9)) * (crownBase - first - 0.03) / 3
            tufts.append(Tuft(x: center(fy) + rng.range(-0.05, 0.05), y: fy, rx: rng.range(0.06, 0.09) * tuftScale))
        }
        // The top of the crown (or each of a twin's tops).
        for top in tops {
            let width = isTwin ? crownWidth * 0.3 : crownWidth * (form.top == .flat ? 0.52 : 0.4)
            tufts.append(Tuft(x: top.x + rng.range(-0.01, 0.01), y: top.y, rx: width * tuftScale))
            tufts.append(Tuft(x: top.x - width * 0.65, y: top.y + 0.035, rx: width * 0.8 * tuftScale))
            tufts.append(Tuft(x: top.x + width * 0.65, y: top.y + 0.04, rx: width * 0.8 * tuftScale))
        }

        // Upper tufts first, so lower ones overlap their shaded undersides.
        for tuft in tufts.sorted(by: { $0.y < $1.y }) {
            // Keep the crown inside the frame (a tuft reaches about 1.15 rx out).
            let x = min(max(tuft.x, tuft.rx * 1.15), 1 - tuft.rx * 1.15)
            drawTuft(&c, s, x: x, y: tuft.y, rx: tuft.rx, ry: tuft.rx * 0.6,
                     shaded: x > center(tuft.y) + crownWidth * 0.25 ? 0.06 : 0, detailed: !compact, rng: &rng)
        }
    }

    // MARK: Foliage

    /// A clump of sequoia foliage: a scalloped mass of small rounded tufts, lit
    /// from the upper left, with a shaded underside. Sizes are in width units.
    private func drawTuft(_ c: inout GraphicsContext, _ s: Space, x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat,
                          back: Bool = false, shaded: Double = 0, detailed: Bool, rng: inout SeededRandom) {
        let center = s.p(x, y)
        let a = rx * s.w, b = ry * s.w
        var outline = Path(ellipseIn: CGRect(x: center.x - a * 0.8, y: center.y - b * 0.7, width: a * 1.6, height: b * 1.45))
        var lights = Path()
        let bumps = detailed ? 8 : 5
        for i in 0..<bumps {
            // Bumps run around the sides and top; the underside stays flatter.
            let angle = (160 + 220 * Double(i) / Double(bumps - 1)) * .pi / 180 + Double(rng.range(-0.12, 0.12))
            let dx = CGFloat(cos(angle)) * a * 0.72, dy = CGFloat(sin(angle)) * b * 0.62
            let r = b * rng.range(0.5, 0.68)
            outline.addEllipse(in: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2))
            if cos(angle) < 0.35 && sin(angle) < 0.1 {
                let lr = r * 0.62
                lights.addEllipse(in: CGRect(x: center.x + dx - r * 0.2 - lr, y: center.y + dy - r * 0.25 - lr,
                                             width: lr * 2, height: lr * 1.6))
            }
        }
        c.fill(outline, with: .color(Theme.Palette.canopy))
        if back {
            c.fill(outline, with: .color(Self.deepShade))
            return
        }
        c.fill(Path(ellipseIn: CGRect(x: center.x - a * 0.7, y: center.y + b * 0.08, width: a * 1.4, height: b * 0.62)),
               with: .color(Self.shade))
        if detailed { lightFoliage(&c, lights) }
        if shaded > 0 { c.fill(outline, with: .color(.black.opacity(shaded))) }
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
