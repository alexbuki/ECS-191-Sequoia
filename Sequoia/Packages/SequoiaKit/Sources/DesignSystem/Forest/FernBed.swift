import SwiftUI

/// A strip of forest floor with one fern per practice round, like the ferns
/// those rounds grow in the forest. Empty, it shows faint outlines to fill.
public struct FernBed: View {
    let ferns: Int

    /// Ferns drawn at most, so the strip stays calm.
    static let maxFerns = 9
    /// Faint outlines shown before the first round.
    static let placeholders = 3

    public init(ferns: Int) {
        self.ferns = max(0, ferns)
    }

    public var body: some View {
        Canvas { context, size in
            let groundY = size.height * 0.86
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: size.height))
            ground.addLine(to: CGPoint(x: 0, y: groundY))
            ground.addQuadCurve(to: CGPoint(x: size.width, y: groundY),
                                control: CGPoint(x: size.width / 2, y: groundY - size.height * 0.08))
            ground.addLine(to: CGPoint(x: size.width, y: size.height))
            ground.closeSubpath()
            context.fill(ground, with: .color(Theme.Palette.canopy.opacity(0.18)))

            let shown = ferns == 0 ? Self.placeholders : min(ferns, Self.maxFerns)
            let color = ferns == 0 ? Theme.Palette.canopy.opacity(0.25) : Theme.Palette.canopy
            var rng = SeededRandom(seed: 0xFE4)
            for index in 0..<shown {
                // Spread evenly with a little jitter, so the bed fills from the middle out.
                let slot = (CGFloat(index) + 0.5) / CGFloat(shown)
                let x = (0.08 + slot * 0.84 + rng.range(-0.02, 0.02)) * size.width
                let height = size.height * rng.range(0.5, 0.68)
                ForestSceneRenderer.drawFern(&context, at: CGPoint(x: x, y: groundY + size.height * 0.04),
                                             height: height, lean: rng.range(-0.2, 0.2), color: color)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Fern bed") {
    VStack(spacing: 20) {
        FernBed(ferns: 0)
        FernBed(ferns: 3)
        FernBed(ferns: 40)
    }
    .frame(height: 240)
    .padding()
    .background(Theme.Palette.surface)
}
