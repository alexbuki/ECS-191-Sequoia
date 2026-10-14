import Testing
import SequoiaCore
import DesignSystem
@testable import Sequoia

struct ForestDescriptionTests {
    @Test func describesTheForestForVoiceOver() {
        #expect(ForestViewModel.describe(planted: 4, stage: .sapling, treeDays: 9)
                == "Your forest: 4 grown sequoias and a sapling on day 9.")
        #expect(ForestViewModel.describe(planted: 1, stage: .sprout, treeDays: 3)
                == "Your forest: 1 grown sequoia and a sprout on day 3.")
        #expect(ForestViewModel.describe(planted: 0, stage: .seed, treeDays: 0)
                == "Your forest: no grown sequoias yet and a seed waiting to be planted.")
    }

    @Test func mentionsTheTimeOfDayAndTheForestFloor() {
        #expect(ForestViewModel.describe(planted: 12, stage: .youngSequoia, treeDays: 14, phase: .goldenHour,
                                         undergrowth: Undergrowth(ferns: 3, flowers: 2))
                == "Your forest at sunset: 12 grown sequoias and a young sequoia on day 14. Ferns and wildflowers grow below.")
        #expect(ForestViewModel.describe(planted: 1, stage: .seed, treeDays: 0, phase: .night, undergrowth: Undergrowth(ferns: 1))
                == "Your forest at night: 1 grown sequoia and a seed waiting to be planted. Ferns grow below.")
    }
}
