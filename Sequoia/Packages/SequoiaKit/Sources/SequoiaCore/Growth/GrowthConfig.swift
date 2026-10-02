import Foundation

/// Every tunable number in the growth system lives here, so thresholds and
/// rewards can be adjusted without touching code elsewhere.
public struct GrowthConfig: Codable, Equatable, Sendable {
    /// The tree day on which each stage begins. Must start with `.seed` at day 1.
    public var stageThresholds: [StageThreshold]
    /// Rings for each daily check-in.
    public var ringsPerCheckIn: Int
    /// Base rings for completing a practice round.
    public var ringsPerPracticeRound: Int
    /// Extra rings per correct practice answer.
    public var ringsPerCorrectAnswer: Int
    /// Bonus rings when a tree reaches a new stage.
    public var milestoneRings: [StageReward]
    /// Missed days forgiven before a streak resets. Zero today; reserved for a
    /// future earned "rain day" that protects a streak.
    public var graceDays: Int

    public struct StageThreshold: Codable, Equatable, Sendable {
        public var stage: TreeStage
        public var day: Int
        public init(_ stage: TreeStage, day: Int) {
            self.stage = stage
            self.day = day
        }
    }

    public struct StageReward: Codable, Equatable, Sendable {
        public var stage: TreeStage
        public var rings: Int
        public init(_ stage: TreeStage, rings: Int) {
            self.stage = stage
            self.rings = rings
        }
    }

    public init(
        stageThresholds: [StageThreshold],
        ringsPerCheckIn: Int,
        ringsPerPracticeRound: Int,
        ringsPerCorrectAnswer: Int,
        milestoneRings: [StageReward],
        graceDays: Int
    ) {
        self.stageThresholds = stageThresholds.sorted { $0.day < $1.day }
        self.ringsPerCheckIn = ringsPerCheckIn
        self.ringsPerPracticeRound = ringsPerPracticeRound
        self.ringsPerCorrectAnswer = ringsPerCorrectAnswer
        self.milestoneRings = milestoneRings
        self.graceDays = graceDays
    }

    /// The tuned defaults: seed day 1, sprout 3, sapling 7, young 14, grown 30.
    public static let standard = GrowthConfig(
        stageThresholds: [
            .init(.seed, day: 1),
            .init(.sprout, day: 3),
            .init(.sapling, day: 7),
            .init(.youngSequoia, day: 14),
            .init(.grownSequoia, day: 30),
        ],
        ringsPerCheckIn: 10,
        ringsPerPracticeRound: 5,
        ringsPerCorrectAnswer: 2,
        milestoneRings: [
            .init(.sprout, rings: 5),
            .init(.sapling, rings: 10),
            .init(.youngSequoia, rings: 20),
            .init(.grownSequoia, rings: 50),
        ],
        graceDays: 0
    )

    /// The tree day on which a stage begins.
    public func threshold(for stage: TreeStage) -> Int {
        stageThresholds.first { $0.stage == stage }?.day ?? 1
    }

    /// Days needed to grow a tree to full size and plant it.
    public var daysToFullGrowth: Int { threshold(for: .grownSequoia) }

    public func milestoneReward(for stage: TreeStage) -> Int {
        milestoneRings.first { $0.stage == stage }?.rings ?? 0
    }
}
