import Foundation

/// The App Group shared by the app, widgets and watch extensions.
public enum AppGroup {
    public static let identifier = "group.app.sequoia.Sequoia"

    /// The shared container, falling back to Application Support when the
    /// entitlement is unavailable (for example in unit tests).
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        let fallback = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    /// Defaults shared across targets. Falls back to the standard defaults.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
