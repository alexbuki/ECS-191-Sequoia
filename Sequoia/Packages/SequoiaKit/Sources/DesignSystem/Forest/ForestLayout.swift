import CoreGraphics

/// Where each planted tree stands in the forest scene. Pure and deterministic:
/// the same number of trees always produces the same forest.
///
/// The newest trees stand nearest, at towering scale; older trees recede layer by
/// layer into the mist, so the forest deepens as it grows.
public struct ForestLayout: Equatable, Sendable {
    /// A depth layer of the scene, from the horizon to the foreground.
    public enum Layer: Int, CaseIterable, Comparable, Sendable {
        case horizon, far, mid, near

        /// How many trees fit before the next-older trees move back a layer.
        var capacity: Int {
            switch self {
            case .near: 3
            case .mid: 8
            case .far: 20
            case .horizon: 160
            }
        }

        /// A grown tree's height as a fraction of the scene's height. Near trees
        /// are taller than the scene and run off the top.
        var treeHeight: CGFloat {
            switch self {
            case .horizon: 0.17
            case .far: 0.3
            case .mid: 0.56
            case .near: 1.12
            }
        }

        /// The average height of this layer's ground line (0 is the top of the scene).
        var groundLine: CGFloat {
            switch self {
            case .horizon: 0.56
            case .far: 0.66
            case .mid: 0.79
            case .near: 0.88
            }
        }

        public static func < (lhs: Layer, rhs: Layer) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public struct Placement: Equatable, Sendable {
        /// The tree's index in planting order, also its art variant.
        public var index: Int
        public var layer: Layer
        /// Horizontal centre, 0...1 across the scene.
        public var x: CGFloat
        /// Extra drop below the layer's ground line, for staggered rows.
        public var drop: CGFloat
        /// Height multiplier for natural variety.
        public var scale: CGFloat
    }

    /// Where the in-progress tree stands, in the near layer.
    public static let currentTreeX: CGFloat = 0.7

    /// The most trees drawn. Beyond this the horizon is already a dense band.
    public static let maxVisibleTrees = Layer.allCases.reduce(0) { $0 + $1.capacity }

    public let placements: [Placement]

    public init(planted: Int) {
        var placements: [Placement] = []
        var remaining = max(0, planted)
        var newest = remaining - 1
        for layer in Layer.allCases.reversed() where remaining > 0 {
            let count = min(remaining, layer.capacity)
            let indices = (0..<count).map { newest - $0 }
            placements += Self.place(indices, in: layer)
            remaining -= count
            newest -= count
        }
        // Back to front, top to bottom, so nearer trees overlap farther ones.
        self.placements = placements.sorted { ($0.layer, $0.drop) < ($1.layer, $1.drop) }
    }

    private static func place(_ indices: [Int], in layer: Layer) -> [Placement] {
        var rng = SeededRandom(seed: UInt64(layer.rawValue + 1) &* 0x51_7CC1_B727)
        let rows = layer == .horizon ? max(1, (indices.count + 39) / 40) : 1
        let slots: [CGFloat]
        if layer == .near {
            // Fixed spots that leave room for the in-progress tree.
            slots = [0.14, 0.42, 0.97].prefix(indices.count).map { $0 }
        } else {
            let perRow = Int((Double(indices.count) / Double(rows)).rounded(.up))
            slots = (0..<indices.count).map { k in
                let column = k / rows, row = k % rows
                let offset = CGFloat(row) / CGFloat(rows) // stagger rows
                return (CGFloat(column) + 0.5 + offset * 0.5) / CGFloat(perRow)
            }
        }
        // Shuffle which tree gets which slot, so neighbours aren't in planting order.
        var order = Array(indices.indices)
        for i in order.indices.reversed() where i > 0 {
            order.swapAt(i, Int(rng.unit() * CGFloat(i + 1)) % (i + 1))
        }
        let spacing = 1 / CGFloat(max(slots.count, 1))
        return order.enumerated().map { slot, k in
            Placement(
                index: indices[k],
                layer: layer,
                x: slots[slot] + (layer == .near ? 0 : rng.range(-0.25, 0.25) * spacing),
                drop: CGFloat(slot % rows) * 0.025 + rng.range(0, 0.02),
                scale: rng.range(0.82, 1.08)
            )
        }
    }
}
