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

        var body: some View {
            ZStack {
                background
                tree
                    .frame(height: 900)
                    .offset(y: 20)
            }
            .frame(width: 1024, height: 1024)
            .environment(\.colorScheme, variant == .light ? .light : .dark)
        }

        @ViewBuilder private var background: some View {
            switch variant {
            case .light: Theme.Palette.fog
            case .dark, .watch: Theme.Palette.fog // resolves to the dark variant
            case .tinted: Color.black
            }
        }

        @ViewBuilder private var tree: some View {
            if variant == .tinted {
                // Tinted icons are grayscale; the system applies the tint.
                TreeView(stage: .grownSequoia, showsGround: true).grayscale(1).brightness(0.35)
            } else {
                TreeView(stage: .grownSequoia, showsGround: true)
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
