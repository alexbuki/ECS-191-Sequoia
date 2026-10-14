import Foundation
import Testing
@testable import DesignSystem

/// Text on Today's forest floor (the rain note, the fresh-start message) must
/// stay readable in every light the forest takes, in light and dark mode.
struct ForestContrastTests {
    typealias RGB = ContrastTests.RGB

    /// Today lays a fog veil of this opacity over the scene and its floor (`TodayForest.veil`).
    static let todayVeil = 0.3

    static func over(_ top: RGB, _ alpha: Double, on base: RGB) -> RGB {
        RGB(r: base.r + (top.r - base.r) * alpha, g: base.g + (top.g - base.g) * alpha, b: base.b + (top.b - base.b) * alpha)
    }

    /// The floor as `ForestScene.floorColor` and Today's veil stack it.
    static func todayFloor(_ light: ForestLight, dark: Bool) throws -> RGB {
        let fog = try ContrastTests.color("fog", dark: dark)
        var floor = try ContrastTests.color("moss", dark: dark)
        floor = over(try ContrastTests.color("sunlight", dark: dark), ForestSceneRenderer.warmWash * light.warmth, on: floor)
        floor = over(RGB(r: 0, g: 0, b: 0), ForestSceneRenderer.nightDim * light.night, on: floor)
        floor = over(fog, ForestSceneRenderer.foregroundVeil, on: floor)
        return over(fog, todayVeil, on: floor)
    }

    @Test(arguments: [false, true], [6.6, 12.75, 18.4, 23.0])
    func textOnTheFloorMeetsAA(dark: Bool, hour: Double) throws {
        let floor = try Self.todayFloor(ForestLight(hour: hour), dark: dark)
        // Only `soil` is used on the floor; `soilSecondary` falls below AA at night.
        for text in ["soil"] {
            let ratio = ContrastTests.contrast(try ContrastTests.color(text, dark: dark), floor)
            #expect(ratio >= 4.5, "\(text) on the floor at \(hour)h (\(dark ? "dark" : "light")) is \(ratio)")
        }
    }
}
