import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import DesignSystem
import SequoiaCore

/// Renders the App Store creative assets: the search results asset (3:2,
/// 3840x2560) and the product page header (21:9, 3840x1646).
/// Runs only when SEQUOIA_ART_DIR is set (prefix it with TEST_RUNNER_ for xcodebuild).
@MainActor
struct MarketingAssetRenderer {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SEQUOIA_ART_DIR"] != nil))
    func renderAssets() throws {
        let dir = try #require(ProcessInfo.processInfo.environment["SEQUOIA_ART_DIR"].map { URL(filePath: $0) })
        try write(SearchAsset(), scale: 4, to: dir.appending(path: "search-asset.png"))
        try write(HeaderAsset(), scale: 3, to: dir.appending(path: "header-asset.png"))
        // A text-free banner for web page covers (Notion crops covers wide).
        try write(ForestScene(planted: 160, currentStage: .youngSequoia, light: ForestLight(hour: 18.2),
                              undergrowth: Undergrowth(ferns: 14, flowers: 18))
                    .frame(width: 1500, height: 420).clipped(),
                  scale: 2, to: dir.appending(path: "notion/cover.png"))
        // Frames for the README GIFs, in the App Store screenshot style:
        // a background with the headline, and a phone bezel laid over the clip.
        for (name, headline, subline) in [
            ("got-it", "One word a day.", "Learn it, and your tree grows."),
            ("practice", "Practice makes\nit stick.", "Quick games with the words you've learned."),
            ("forest", "Grow a forest.", "Every 30 days plants a giant sequoia."),
            ("watch", "On your wrist.", "Today's word and Got it on Apple Watch."),
        ] {
            try write(GIFFrame(headline: headline, subline: subline, layer: .background),
                      scale: 1, to: dir.appending(path: "gif-frames/\(name)-bg.png"))
        }
        try write(GIFFrame(headline: "", subline: "", layer: .bezel), scale: 1,
                  to: dir.appending(path: "gif-frames/bezel.png"))
        try write(GIFFrame(headline: "", subline: "", layer: .watchBezel), scale: 1,
                  to: dir.appending(path: "gif-frames/watch-bezel.png"))
    }

    private func write(_ view: some View, scale: CGFloat, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}

private let cream = Color(red: 0.96, green: 0.94, blue: 0.88)

/// Search results (960 x 640 pt at 4x): the whole idea at a glance. Today's
/// word, and the tree it grows from day 1 to day 30.
private struct SearchAsset: View {
    /// Each stage with its day and drawn height. The sprout is drawn larger
    /// than to scale so it can be seen at search-result size.
    private let days: [(TreeStage, String, CGFloat)] = [
        (.sprout, "Day 1", 150), (.sapling, "Day 7", 140), (.youngSequoia, "Day 14", 230), (.grownSequoia, "Day 30", 380),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "One word\na day.")
                    .font(.system(size: 84, weight: .semibold, design: .serif))
                    .lineSpacing(-8)
                    .foregroundStyle(cream)
                Text(verbatim: "Each word grows your tree.")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(cream.opacity(0.85))
                    .padding(.top, 14)
                Spacer(minLength: 0)
                WordCard(word: .sample, style: .compact)
                    .frame(width: 300)
                    .scaleEffect(1.25, anchor: .bottomLeading)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
            }
            .padding(.leading, 56)
            .padding(.vertical, 56)
            .frame(width: 440, alignment: .leading)

            // Day 1 to day 30, standing on the forest floor under a light sky.
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Theme.Palette.fog, Theme.Palette.surface], startPoint: .top, endPoint: .bottom)
                ForestScene.floorColor(ForestLight(hour: 12.75)).frame(height: 84)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(days, id: \.1) { stage, day, height in
                        VStack(spacing: 16) {
                            TreeView(stage: stage, showsGround: false)
                                .frame(width: height * 0.5, height: height)
                                // The grown art leaves a little room under its roots.
                                .offset(y: stage == .grownSequoia ? height * 0.045 : 0)
                            Text(verbatim: day)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Palette.soil)
                                .fixedSize()
                                .frame(width: max(76, height * 0.5))
                        }
                    }
                }
                .fixedSize()
                .padding(.bottom, 26)
            }
            .frame(width: 480, height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.trailing, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 960, height: 640)
        .background(Theme.Palette.canopy)
    }
}

/// Product page header (1280 x 548.67 pt at 3x): a cinematic forest at golden
/// hour with one line, so the page opens on the reward.
private struct HeaderAsset: View {
    private let light = ForestLight(hour: 18.2)

    var body: some View {
        ZStack {
            ForestScene(planted: 160, currentStage: .youngSequoia, light: light,
                        undergrowth: Undergrowth(ferns: 14, flowers: 18))
            // A soft pool of shade in the middle keeps the words readable,
            // and keeps them in the center safe area on every device.
            Ellipse()
                .fill(Theme.Palette.canopy.opacity(0.78))
                .frame(width: 980, height: 300)
                .blur(radius: 70)
            VStack(spacing: 14) {
                Text(verbatim: "Every word grows a forest.")
                    .font(.system(size: 70, weight: .semibold, design: .serif))
                Text(verbatim: "Learn one a day, and watch it rise.")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .opacity(0.9)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(cream)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 2)
        }
        .frame(width: 1280, height: 548.5)
        .clipped()
    }
}

/// A 600 x 1304 frame matching the App Store screenshots. The clip is placed
/// at x 76, y 324, 448 wide, between the background and the bezel layers.
private struct GIFFrame: View {
    enum Layer { case background, bezel, watchBezel }
    let headline: String
    let subline: String
    let layer: Layer

    var body: some View {
        ZStack(alignment: .top) {
            switch layer {
            case .background:
                Color(red: 0x25 / 255, green: 0x50 / 255, blue: 0x3a / 255)
                VStack(spacing: 14) {
                    Text(verbatim: headline)
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .lineSpacing(-4)
                    Text(verbatim: subline)
                        .font(.system(size: 23, weight: .regular, design: .default))
                        .opacity(0.85)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(cream)
                .frame(height: 200)
                .padding(.top, 70)
            case .bezel:
                // The bezel ring: a rounded phone body with the screen cut out.
                Path { path in
                    path.addRoundedRect(in: CGRect(x: 62, y: 310, width: 476, height: 1200),
                                        cornerSize: CGSize(width: 66, height: 66), style: .continuous)
                    path.addRoundedRect(in: CGRect(x: 76, y: 324, width: 448, height: 1180),
                                        cornerSize: CGSize(width: 52, height: 52), style: .continuous)
                }
                .fill(Color(white: 0.07), style: FillStyle(eoFill: true))
            case .watchBezel:
                // A watch case around a 480 x 572 screen at x 60, y 420, with its
                // crown. Green fills outside the case hide the screenshot's corners.
                let outer = CGRect(x: 40, y: 400, width: 520, height: 612)
                let screen = CGRect(x: 60, y: 420, width: 480, height: 572)
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.addRect(outer.insetBy(dx: -4, dy: -4))
                        path.addRoundedRect(in: outer, cornerSize: CGSize(width: 140, height: 140), style: .continuous)
                    }
                    .fill(Color(red: 0x25 / 255, green: 0x50 / 255, blue: 0x3a / 255), style: FillStyle(eoFill: true))
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(white: 0.16))
                        .frame(width: 24, height: 100)
                        .offset(x: 550, y: 590)
                    Path { path in
                        path.addRoundedRect(in: outer, cornerSize: CGSize(width: 140, height: 140), style: .continuous)
                        path.addRoundedRect(in: screen, cornerSize: CGSize(width: 120, height: 120), style: .continuous)
                    }
                    .fill(Color(white: 0.07), style: FillStyle(eoFill: true))
                }
            }
        }
        .frame(width: 600, height: 1304, alignment: .top)
        .clipped()
    }
}
