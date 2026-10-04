import Foundation

/// The five growth stages of a tree.
public enum TreeStage: Int, Codable, CaseIterable, Sendable, Comparable, Identifiable {
    case seed
    case sprout
    case sapling
    case youngSequoia
    case grownSequoia

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .seed: String(localized: "Seed", bundle: .module)
        case .sprout: String(localized: "Sprout", bundle: .module)
        case .sapling: String(localized: "Sapling", bundle: .module)
        case .youngSequoia: String(localized: "Young sequoia", bundle: .module)
        case .grownSequoia: String(localized: "Grown sequoia", bundle: .module)
        }
    }

    /// A short VoiceOver description of what the tree looks like.
    public var accessibilityDescription: String {
        switch self {
        case .seed: String(localized: "A sequoia cone resting on the soil", bundle: .module)
        case .sprout: String(localized: "A tiny seedling with a star of seed leaves", bundle: .module)
        case .sapling: String(localized: "A slender, pointed sapling", bundle: .module)
        case .youngSequoia: String(localized: "A young sequoia, tall and pointed", bundle: .module)
        case .grownSequoia: String(localized: "A towering sequoia with a massive red trunk", bundle: .module)
        }
    }

    public static func < (lhs: TreeStage, rhs: TreeStage) -> Bool { lhs.rawValue < rhs.rawValue }
}
