import CoreGraphics

/// The forest's light at a time of day: where the sun (or moon) sits, and how
/// warm or dark the scene is. Pure, so it can be tested.
public struct ForestLight: Hashable, Sendable {
    /// The sun's or moon's centre, in scene fractions.
    public var orbX: CGFloat
    public var orbY: CGFloat
    /// 0 at midday, up to 1 at sunrise and sunset: how golden the light is.
    public var warmth: CGFloat
    /// 0 by day, up to 1 in the depth of night.
    public var night: CGFloat
    /// Morning mist lying in the valleys, strongest at sunrise.
    public var mist: CGFloat

    /// The light at an hour of the day (0..<24, fractions allowed).
    public init(hour: Double) {
        let hour = (hour.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
        let sunrise = 6.0, sunset = 19.5
        if hour >= sunrise && hour <= sunset {
            // Day: the sun arcs from the left at sunrise to the right at sunset.
            let t = CGFloat((hour - sunrise) / (sunset - sunrise))
            orbX = 0.12 + t * 0.76
            orbY = 0.42 - sin(t * .pi) * 0.3
            // Golden for about two hours before sunset; mornings are paler and misty.
            let edge = min(hour - sunrise, sunset - hour)
            let golden = CGFloat(max(0, 1 - edge / 2))
            let isMorning = hour < 12
            warmth = isMorning ? golden * 0.45 : golden
            mist = isMorning ? CGFloat(max(0, 1 - (hour - sunrise) / 3)) : 0
            night = 0
        } else {
            // Night: a moon crosses the other way; dusk and dawn ease in and out.
            let sinceSunset = hour > sunset ? hour - sunset : hour + 24 - sunset
            let length = 24 - sunset + sunrise
            let t = CGFloat(sinceSunset / length)
            orbX = 0.85 - t * 0.7
            orbY = 0.36 - sin(t * .pi) * 0.22
            warmth = 0
            mist = 0
            night = CGFloat(min(1, min(sinceSunset, length - sinceSunset) / 1.0))
        }
    }

    public static let midday = ForestLight(hour: 12.75)

    /// The part of the day the light shows, for VoiceOver.
    public enum Phase: Equatable, Sendable { case dawn, day, goldenHour, night }

    public var phase: Phase {
        if night > 0.5 { return .night }
        if mist > 0.3 { return .dawn }
        if warmth > 0.5 { return .goldenHour }
        return .day
    }
}

/// Small growth on the forest floor, earned through other habits: ferns from
/// practice rounds and wildflowers from favorite words.
public struct Undergrowth: Hashable, Sendable {
    public var ferns: Int
    public var flowers: Int

    public init(ferns: Int = 0, flowers: Int = 0) {
        self.ferns = max(0, ferns)
        self.flowers = max(0, flowers)
    }

    public static let none = Undergrowth()

    /// At most this many of each are drawn, so the floor stays calm.
    static let maxFerns = 14
    static let maxFlowers = 18
}
