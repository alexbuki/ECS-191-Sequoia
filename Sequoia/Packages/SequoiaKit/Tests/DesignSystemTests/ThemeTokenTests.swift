import Foundation
import Testing
@testable import DesignSystem

struct ThemeTokenTests {
    @Test func spacingScaleIncreases() {
        let scale = [Theme.Spacing.xxs, Theme.Spacing.xs, Theme.Spacing.s, Theme.Spacing.m, Theme.Spacing.l, Theme.Spacing.xl, Theme.Spacing.xxl]
        #expect(scale == scale.sorted())
    }
}
