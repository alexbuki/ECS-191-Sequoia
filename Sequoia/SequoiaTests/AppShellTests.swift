import Testing
@testable import Sequoia

struct AppShellTests {
    @Test func hasFourTabsWithTodayFirst() {
        #expect(AppTab.allCases == [.today, .library, .practice, .forest])
    }
}
