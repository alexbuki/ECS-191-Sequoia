#if canImport(UIKit) && !os(watchOS)
import UIKit

public extension Theme {
    /// Styles UIKit-backed navigation bars with the rounded interface face and palette.
    @MainActor
    static func applyNavigationAppearance() {
        func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let weighted = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
            let descriptor = weighted.fontDescriptor.withDesign(.rounded) ?? weighted.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
        }
        let soil = UIColor(named: "soil", in: .module, compatibleWith: nil) ?? .label
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: rounded(.largeTitle, weight: .bold), .foregroundColor: soil]
        appearance.titleTextAttributes = [.font: rounded(.headline, weight: .semibold), .foregroundColor: soil]
    }
}
#endif
