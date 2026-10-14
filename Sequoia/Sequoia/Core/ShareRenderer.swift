import SwiftUI
import DesignSystem
import SequoiaCore

/// Renders shareable images with `ImageRenderer`.
@MainActor
enum ShareRenderer {
    /// The word card standing in front of the sharer's forest, in today's light.
    static func wordCard(word: Word, store: SequoiaStore) -> UIImage? {
        render(WordShareCard(word: word, stage: store.stage, streak: store.growth.currentStreak,
                             planted: store.growth.plantedTrees, light: light(for: store)))
    }

    /// Shared images take today's light by day; at night, when a dark image
    /// wouldn't share well, they show the forest at midday.
    static func light(for store: SequoiaStore) -> ForestLight {
        store.forestLight.night > 0 ? .midday : store.forestLight
    }

    static func render<Content: View>(_ view: Content) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 3
        // A finished bitmap rather than `uiImage`, which defers drawing the
        // whole forest until the image is first used.
        return renderer.cgImage.map { UIImage(cgImage: $0, scale: 3, orientation: .up) }
    }
}
