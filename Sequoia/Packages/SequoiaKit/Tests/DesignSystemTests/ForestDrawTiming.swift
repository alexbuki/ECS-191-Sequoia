import Foundation
import SwiftUI
import Testing
@testable import DesignSystem

@MainActor
struct ForestDrawTiming {
    @Test func drawingAFullForestIsQuick() throws {
        for planted in [0, 30, 191] {
            // The renderer itself, not `ForestScene`, whose backdrop is cached.
            let renderer = ForestSceneRenderer(layout: ForestLayout(planted: planted), currentStage: .youngSequoia,
                                               light: ForestLight(hour: 18.4), undergrowth: Undergrowth(ferns: 14, flowers: 18))
            let scene = Canvas { context, size in renderer.draw(in: &context, size: size) }
                .frame(width: 440, height: 560)
            let start = Date()
            for _ in 0..<10 {
                let image = ImageRenderer(content: scene)
                image.scale = 3
                _ = image.cgImage
            }
            let perFrame = Date().timeIntervalSince(start) / 10
            print("forest-draw planted=\(planted) \(String(format: "%.1f", perFrame * 1000)) ms")
        }
    }
}
