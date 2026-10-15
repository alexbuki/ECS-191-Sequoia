import SwiftUI
import Testing
import DesignSystem
import SequoiaCore

/// Renders the app icon from the same `TreeView` the app draws, so the icon and
/// the in-app illustration always match. Runs only when SEQUOIA_ICON_DIR is set:
///   TEST_RUNNER_SEQUOIA_ICON_DIR=/path xcodebuild test ... -only-testing:SequoiaTests/AppIconRenderer
@MainActor
struct AppIconRenderer {
    enum Variant: String, CaseIterable { case light, dark, tinted, watch }

    struct IconView: View {
        let variant: Variant

        /// One grown sequoia on a plain background: no sun, hills or grove, so
        /// it stays legible at small sizes. The trunk stands on the icon's edge.
        var body: some View {
            ZStack(alignment: .bottom) {
                background
                tree(height: 1010, variant: 2)
                    .offset(y: 8)
            }
            .frame(width: 1024, height: 1024)
            .clipped()
            .environment(\.colorScheme, variant == .light ? .light : .dark)
        }

        @ViewBuilder private var background: some View {
            switch variant {
            case .light: Theme.Palette.fog
            case .dark, .watch: Theme.Palette.fog // resolves to the dark variant
            case .tinted: Color.black
            }
        }

        @ViewBuilder private func tree(height: CGFloat, variant seed: Int) -> some View {
            let view = TreeView(stage: .grownSequoia, showsGround: false, variant: seed)
                .frame(height: height)
            if variant == .tinted {
                // Tinted icons are grayscale; the system applies the tint.
                view.grayscale(1).brightness(0.35)
            } else {
                view
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["SEQUOIA_ICON_DIR"] != nil))
    func renderIcons() throws {
        let dir = try #require(ProcessInfo.processInfo.environment["SEQUOIA_ICON_DIR"].map { URL(filePath: $0) })
        for variant in Variant.allCases {
            let renderer = ImageRenderer(content: IconView(variant: variant))
            renderer.scale = 1
            renderer.isOpaque = true
            let image = try #require(renderer.uiImage)
            let data = try #require(image.pngData())
            try data.write(to: dir.appending(path: "AppIcon-\(variant.rawValue).png"))
        }
    }
}
