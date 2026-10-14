import Testing
@testable import Sequoia

struct AppShellTests {
    @Test func hasThreeTabsWithTodayFirst() {
        #expect(AppTab.allCases == [.today, .library, .forest])
    }
}
