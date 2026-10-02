import SwiftUI

/// The Sequoia design language: palette, typography, spacing and shape tokens.
///
/// Nothing outside `DesignSystem` should hard-code a color or a font.
public enum Theme {
    /// Colors drawn from a sequoia grove. Each token has light and dark variants
    /// in the asset catalog.
    public enum Palette {
        /// Warm redwood red-brown. The primary brand and accent color.
        public static let bark = Color("bark", bundle: .module)
        /// Deep evergreen for growth, success and the forest.
        public static let canopy = Color("canopy", bundle: .module)
        /// Soft sage for secondary surfaces and progress fills.
        public static let moss = Color("moss", bundle: .module)
        /// The background: warm off-white, or deep charcoal-green in dark mode.
        public static let fog = Color("fog", bundle: .module)
        /// Primary text.
        public static let soil = Color("soil", bundle: .module)
        /// Secondary text.
        public static let soilSecondary = Color("soilSecondary", bundle: .module)
        /// Raised surfaces such as cards.
        public static let surface = Color("surface", bundle: .module)
        /// Muted amber, used sparingly for celebrations and milestones.
        public static let sunlight = Color("sunlight", bundle: .module)
        /// Text drawn on top of `sunlight`.
        public static let onSunlight = Color("onSunlight", bundle: .module)
        /// Text drawn on top of `bark` (the primary button).
        public static let onBark = Color("fog", bundle: .module)
    }

    /// Spacing scale, in points.
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let s: CGFloat = 12
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    /// Soft, generous corner radii.
    public enum Size {
        /// The smallest comfortable hit area (Apple's Human Interface Guidelines).
        public static let minTapTarget: CGFloat = 44
    }

    public enum Radius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let card: CGFloat = 28
    }

    /// Motion tokens. Every animation is short and organic.
    public enum Motion {
        public static let grow = Animation.spring(response: 0.6, dampingFraction: 0.72)
        public static let settle = Animation.easeOut(duration: 0.35)
        public static let fade = Animation.easeInOut(duration: 0.25)

        /// The growth animation, or a simple fade when Reduce Motion is on.
        public static func growth(reduceMotion: Bool) -> Animation {
            reduceMotion ? fade : grow
        }
    }
}

/// Typography. The word itself is set in the system serif (New York) for an
/// editorial feel; the interface uses SF Pro Rounded. All styles scale with
/// Dynamic Type.
public enum Typography {
    /// The hero word on the Today card.
    public static let wordHero = Font.system(.largeTitle, design: .serif).weight(.semibold)
    /// A word in a list or a smaller card.
    public static let wordTitle = Font.system(.title2, design: .serif).weight(.semibold)
    /// Example sentences and quoted text.
    public static let quote = Font.system(.body, design: .serif).italic()
    /// Screen and section titles.
    public static let title = Font.system(.title2, design: .rounded).weight(.bold)
    public static let headline = Font.system(.headline, design: .rounded)
    public static let body = Font.system(.body, design: .rounded)
    public static let callout = Font.system(.callout, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded)
    /// Small caps-style labels such as the part of speech.
    public static let label = Font.system(.footnote, design: .rounded).weight(.semibold)
    /// Large numerals for stats.
    public static let stat = Font.system(.title, design: .rounded).weight(.bold).monospacedDigit()
    /// The phonetic transcription.
    public static let ipa = Font.system(.callout, design: .serif)
    /// A large symbol heading an empty state or result.
    public static let icon = Font.system(.largeTitle, design: .rounded)
    /// A symbol in a card or list row.
    public static let iconSmall = Font.system(.title2, design: .rounded)
}
