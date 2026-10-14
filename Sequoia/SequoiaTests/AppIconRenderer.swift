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
            ZStack(alignment: .bottom) {
                background
                if variant != .tinted {
                    // Late light behind the crown, and a quiet grove on the hills.
                    Circle()
                        .fill(Theme.Palette.sunlight.opacity(variant == .light ? 0.35 : 0.22))
                        .frame(width: 620)
                        .blur(radius: 70)
                        .offset(x: 170, y: -560)
                    hills
                }
                grove
                tree(height: 960, variant: 2)
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

        private var hills: some View {
            Ellipse()
                .fill(Theme.Palette.moss.opacity(variant == .light ? 0.7 : 0.35))
                .frame(width: 1500, height: 520)
                .offset(x: -120, y: 300)
        }

        /// Two smaller giants behind, faded into the fog, for depth.
        private var grove: some View {
            ZStack(alignment: .bottom) {
                tree(height: 600, variant: 5).offset(x: -320, y: -60)
                tree(height: 500, variant: 9).offset(x: 330, y: -85)
            }
            .opacity(variant == .tinted ? 0.4 : 0.45)
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
