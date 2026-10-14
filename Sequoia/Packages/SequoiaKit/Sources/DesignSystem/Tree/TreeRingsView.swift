import SwiftUI

/// A cross-section of a sequoia trunk, its growth rings standing for the
/// rings earned. More rings draw more growth lines, up to a calm maximum.
public struct TreeRingsView: View {
    let rings: Int
    @Environment(\.colorScheme) private var colorScheme

    /// Growth lines drawn at most.
    static let maxLines = 14
    /// Rings earned per growth line.
    static let ringsPerLine = 120

    public init(rings: Int) {
        self.rings = max(0, rings)
    }

    static func lineCount(for rings: Int) -> Int {
        min(maxLines, 2 + rings / ringsPerLine)
    }

    public var body: some View {
        let dark = colorScheme == .dark
        // Sequoia wood: pale sapwood around a warm, reddish heartwood.
        let sapwood = dark ? Color(red: 0.80, green: 0.66, blue: 0.48) : Color(red: 0.95, green: 0.84, blue: 0.66)
        let heartwood = dark ? Color(red: 0.70, green: 0.45, blue: 0.30) : Color(red: 0.84, green: 0.58, blue: 0.40)
        let heartwoodCore = dark ? Color(red: 0.62, green: 0.38, blue: 0.25) : Color(red: 0.78, green: 0.50, blue: 0.33)
        let grain = dark ? Color(red: 0.36, green: 0.20, blue: 0.13) : Color(red: 0.48, green: 0.27, blue: 0.16)
        let bark = dark ? Color(red: 0.30, green: 0.17, blue: 0.11) : Color(red: 0.40, green: 0.22, blue: 0.14)

        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // The pith sits a little off-center, as it does in real trunks.
            let pith = CGPoint(x: center.x - radius * 0.07, y: center.y + radius * 0.05)
            var rng = SeededRandom(seed: 0x51C0)
            // One gentle shape shared by every ring, so the rings nest without crossing.
            let shape = TrunkShape(rng: &rng)

            let wood = radius * 0.9
            // Rings drift from the pith toward the true center as they grow.
            func ringCenter(_ t: CGFloat) -> CGPoint {
                CGPoint(x: pith.x + (center.x - pith.x) * t, y: pith.y + (center.y - pith.y) * t)
            }

            // Bark: a thin rim with soft, plated fissures.
            context.fill(shape.path(center: center, radius: radius, roundness: 1, roughness: 0.03, rng: &rng),
                         with: .color(bark))
            context.fill(shape.path(center: center, radius: wood, roundness: 1),
                         with: .color(sapwood))
            // The heartwood follows the ring geometry, so its edge reads as a ring.
            let heart: CGFloat = 0.8
            context.fill(shape.path(center: ringCenter(heart), radius: wood * heart, roundness: heart),
                         with: .radialGradient(Gradient(colors: [heartwoodCore, heartwood]),
                                               center: pith, startRadius: 0, endRadius: wood * heart))

            // Rings crowd together toward the bark, as growth slows with age.
            let lines = Self.lineCount(for: rings)
            let fine = max(0.6, radius * 0.014)
            for line in 1...lines {
                let t = pow(CGFloat(line) / CGFloat(lines + 1), 0.8)
                let path = shape.path(center: ringCenter(t), radius: wood * t, roundness: t)
                context.stroke(path, with: .color(grain.opacity(line.isMultiple(of: 3) ? 0.5 : 0.32)),
                               lineWidth: line.isMultiple(of: 3) ? fine * 1.4 : fine)
            }

            // A drying check: a fine radial crack from the rim toward the pith.
            let angle = CGFloat.pi * 0.28
            let outer = wood * 0.97, inner = wood * 0.42, halfWidth = radius * 0.018
            var check = Path()
            check.move(to: CGPoint(x: center.x + cos(angle) * outer - sin(angle) * halfWidth,
                                   y: center.y + sin(angle) * outer + cos(angle) * halfWidth))
            check.addLine(to: CGPoint(x: center.x + cos(angle) * outer + sin(angle) * halfWidth,
                                      y: center.y + sin(angle) * outer - cos(angle) * halfWidth))
            check.addLine(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            check.closeSubpath()
            context.fill(check, with: .color(grain.opacity(0.55)))

            context.fill(Path(ellipseIn: CGRect(x: pith.x - radius * 0.03, y: pith.y - radius * 0.03,
                                                width: radius * 0.06, height: radius * 0.06)),
                         with: .color(grain.opacity(0.8)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The trunk's outline: a near-circle with two soft lobes, optionally with a
/// rough bark edge. `roundness` scales the lobes, so inner rings are rounder.
private struct TrunkShape {
    let phase2: CGFloat
    let phase3: CGFloat

    init(rng: inout SeededRandom) {
        phase2 = rng.range(0, 2 * .pi)
        phase3 = rng.range(0, 2 * .pi)
    }

    func path(center: CGPoint, radius: CGFloat, roundness: CGFloat) -> Path {
        var none = SeededRandom(seed: 0)
        return path(center: center, radius: radius, roundness: roundness, roughness: 0, rng: &none)
    }

    func path(center: CGPoint, radius: CGFloat, roundness: CGFloat, roughness: CGFloat, rng: inout SeededRandom) -> Path {
        let steps = 120
        // Bark plates: random dips at a few knots, eased between them.
        let knots = 40
        let dips = (0..<knots).map { _ in rng.range(0, roughness) }
        var path = Path()
        for step in 0..<steps {
            let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
            var r = 1 + roundness * (0.035 * sin(angle * 2 + phase2) + 0.018 * sin(angle * 3 + phase3))
            if roughness > 0 {
                let position = CGFloat(step) / CGFloat(steps) * CGFloat(knots)
                let index = Int(position), f = position - CGFloat(index)
                let ease = (1 - cos(f * .pi)) / 2
                r -= dips[index % knots] * (1 - ease) + dips[(index + 1) % knots] * ease
            }
            let point = CGPoint(x: center.x + cos(angle) * radius * r, y: center.y + sin(angle) * radius * r)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The ring total as a tree cross-section, for the Forest stats.
public struct RingsTile: View {
    private let rings: Int

    public init(rings: Int) {
        self.rings = rings
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(rings.formatted())
                    .font(Typography.stat)
                    .foregroundStyle(Theme.Palette.soil)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Rings", bundle: .module)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                Text("Every day you learn adds rings, like a growing trunk.", bundle: .module)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            TreeRingsView(rings: rings)
                .frame(width: 76, height: 76)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rings", bundle: .module))
        .accessibilityValue(Text(rings.formatted()))
    }
}

#Preview("Tree rings") {
    VStack(spacing: 16) {
        HStack { ForEach([0, 120, 475, 2000], id: \.self) { TreeRingsView(rings: $0).frame(width: 80) } }
        RingsTile(rings: 475)
    }
    .padding()
    .sequoiaScreen()
}

#Preview("Tree rings – dark") {
    RingsTile(rings: 475).padding().sequoiaScreen().preferredColorScheme(.dark)
}
