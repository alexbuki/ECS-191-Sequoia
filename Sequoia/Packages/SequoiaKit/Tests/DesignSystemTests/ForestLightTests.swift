import Testing
@testable import DesignSystem

struct ForestLightTests {
    @Test func namesThePartOfTheDay() {
        #expect(ForestLight(hour: 6.5).phase == .dawn)
        #expect(ForestLight(hour: 12.75).phase == .day)
        #expect(ForestLight(hour: 18.8).phase == .goldenHour)
        #expect(ForestLight(hour: 23).phase == .night)
    }

    @Test func middayIsBrightNeutralAndHigh() {
        let light = ForestLight(hour: 12.75)
        #expect(light.night == 0)
        #expect(light.warmth == 0)
        #expect(light.orbY < 0.15)
        #expect(abs(light.orbX - 0.5) < 0.05)
    }

    @Test func sunriseIsMistyAndSunsetIsGolden() {
        let sunrise = ForestLight(hour: 6.2), sunset = ForestLight(hour: 19.2)
        #expect(sunrise.mist > 0.8 && sunset.mist == 0)
        #expect(sunset.warmth > 0.8 && sunrise.warmth < sunset.warmth)
        for light in [sunrise, sunset] {
            #expect(light.orbY > 0.3)
            #expect(light.night == 0)
        }
        #expect(sunrise.orbX < sunset.orbX)
        #expect(ForestLight(hour: 12.75).mist == 0)
    }

    @Test func deepNightIsDarkWithTheMoonUp() {
        let light = ForestLight(hour: 1)
        #expect(light.night == 1)
        #expect(light.warmth == 0)
    }

    @Test func duskEasesIntoNight() {
        let justAfterSunset = ForestLight(hour: 19.75)
        #expect(justAfterSunset.night > 0 && justAfterSunset.night < 1)
    }

    @Test func hoursWrapAround() {
        #expect(ForestLight(hour: 25) == ForestLight(hour: 1))
        #expect(ForestLight(hour: -1) == ForestLight(hour: 23))
    }

    @Test func undergrowthNeverGoesNegative() {
        #expect(Undergrowth(ferns: -3, flowers: -1) == .none)
    }
}
