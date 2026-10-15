import Testing
import SequoiaCore
@testable import Sequoia

struct AppShellTests {
    @Test func hasThreeTabsWithTodayFirst() {
        #expect(AppTab.allCases == [.today, .library, .forest])
    }

    /// Onboarding shows on the first launch, not again once finished, and
    /// returns on the launch after a reset.
    @MainActor @Test func resetProgressBringsOnboardingBackNextLaunch() {
        let store = SequoiaStore(container: Persistence.makeContainerOrFallback(.inMemory))
        let first = AppModel(store: store)
        #expect(first.needsOnboarding)
        first.completeOnboarding(level: .gre, reminderAt: nil)
        #expect(!first.needsOnboarding)
        #expect(store.settings.difficulty == .gre)
        #expect(!AppModel(store: store).needsOnboarding)

        first.resetProgress()
        #expect(!first.needsOnboarding, "not in the middle of Settings")
        #expect(AppModel(store: store).needsOnboarding, "back on the next launch")
    }
}
