import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import DesignSystem

/// Renders the tree art and forest scene review sheets to PNGs. Runs only when
/// SEQUOIA_ART_DIR is set (prefix it with TEST_RUNNER_ for xcodebuild).
@MainActor
struct TreeArtRenderer {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SEQUOIA_ART_DIR"] != nil))
    func renderReviewSheets() throws {
        let dir = try #require(ProcessInfo.processInfo.environment["SEQUOIA_ART_DIR"].map { URL(filePath: $0) })
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "light" : "dark"
            try write(TreeArtSheet().environment(\.colorScheme, scheme), to: dir.appending(path: "trees-\(suffix).png"))
            try write(ForestSceneSheet().environment(\.colorScheme, scheme), to: dir.appending(path: "forest-\(suffix).png"))
        }
    }

    private func write(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
