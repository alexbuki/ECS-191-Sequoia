import Testing
import SequoiaCore
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
}
