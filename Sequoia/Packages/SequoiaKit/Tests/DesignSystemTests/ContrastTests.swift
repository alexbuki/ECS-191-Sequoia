import Foundation
import Testing

/// Verifies WCAG AA contrast (4.5:1) for every palette pairing used for text,
/// in both light and dark mode, by reading the asset-catalog color sets.
struct ContrastTests {
    /// (foreground, background) pairs that appear as text in the app.
    static let textPairings: [(String, String)] = [
        ("soil", "fog"), ("soil", "surface"), ("soil", "moss"),
        ("soilSecondary", "fog"), ("soilSecondary", "surface"), ("soilSecondary", "moss"),
        ("bark", "fog"), ("bark", "surface"), ("bark", "moss"),
        ("canopy", "fog"), ("canopy", "surface"), ("canopy", "moss"),
        ("fog", "bark"),          // primary button label (onBark)
        ("onSunlight", "sunlight"), // milestone badges
    ]

    static var catalog: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/DesignSystem/Resources/Colors.xcassets")
    }

    struct RGB { let r, g, b: Double }

    static func color(_ name: String, dark: Bool) throws -> RGB {
        let url = catalog.appending(path: "\(name).colorset/Contents.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let colors = try #require(json?["colors"] as? [[String: Any]])
        let entry = try #require(colors.first { ($0["appearances"] != nil) == dark })
        let components = try #require((entry["color"] as? [String: Any])?["components"] as? [String: String])
        func value(_ key: String) throws -> Double {
            let raw = try #require(components[key])
            let parsed = raw.hasPrefix("0x") ? Double(Int(raw.dropFirst(2), radix: 16) ?? 0) / 255 : Double(raw) ?? 0
            return parsed
        }
        return RGB(r: try value("red"), g: try value("green"), b: try value("blue"))
    }

    static func luminance(_ c: RGB) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: [false, true])
    func textPairingsMeetAA(dark: Bool) throws {
        for (fg, bg) in Self.textPairings {
            let ratio = Self.contrast(try Self.color(fg, dark: dark), try Self.color(bg, dark: dark))
            #expect(ratio >= 4.5, "\(fg) on \(bg) (\(dark ? "dark" : "light")) is \(ratio)")
        }
    }

    @Test func everyTokenHasLightAndDarkVariants() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.catalog.path())
            .filter { $0.hasSuffix(".colorset") }
            .map { String($0.dropLast(".colorset".count)) }
        #expect(Set(names).isSuperset(of: ["bark", "canopy", "moss", "fog", "soil", "sunlight"]))
        for name in names {
            _ = try Self.color(name, dark: false)
            _ = try Self.color(name, dark: true)
        }
    }
}
