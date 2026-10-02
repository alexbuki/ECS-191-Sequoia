import SwiftUI
import DesignSystem
import SequoiaCore

/// Renders shareable images with `ImageRenderer`.
@MainActor
enum ShareRenderer {
    static func wordCard(word: Word, stage: TreeStage, streak: Int) -> UIImage? {
        render(WordShareCard(word: word, stage: stage, streak: streak))
    }

    static func render<Content: View>(_ view: Content) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage
    }
}
