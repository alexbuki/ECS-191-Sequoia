import SwiftUI
import SequoiaCore

/// Every token and component in one scrollable page, for review and screenshots.
public struct DesignGalleryView: View {
    public init() {}

    private let swatches: [(String, Color)] = [
        ("bark", Theme.Palette.bark), ("canopy", Theme.Palette.canopy), ("moss", Theme.Palette.moss),
        ("fog", Theme.Palette.fog), ("soil", Theme.Palette.soil), ("soilSecondary", Theme.Palette.soilSecondary),
        ("surface", Theme.Palette.surface), ("sunlight", Theme.Palette.sunlight),
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                section("Trees · full size") {
                    HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                        ForEach(TreeStage.allCases) { TreeView(stage: $0).frame(height: 180) }
                    }
                }
                section("Trees · widget size") {
                    HStack(alignment: .bottom, spacing: Theme.Spacing.m) {
                        ForEach(TreeStage.allCases) { TreeView(stage: $0).frame(height: 56) }
                    }
                }
                section("Trees · watch complication size") {
                    HStack(alignment: .bottom, spacing: Theme.Spacing.m) {
                        ForEach(TreeStage.allCases) { TreeView(stage: $0, showsGround: false).frame(height: 22) }
                    }
                }

                section("Components") {
                    WordCard(word: .sample) {
                        Button {} label: { Image(systemName: "speaker.wave.2") }.buttonStyle(IconButtonStyle())
                    }
                    Button("Got it") {}.buttonStyle(.sequoiaPrimary)
                    Button("I already knew this") {}.buttonStyle(.sequoiaSecondary)
                    HStack {
                        StatTile(value: "12", label: "Day streak", systemImage: "flame")
                        StatTile(value: "340", label: "Rings", systemImage: "circle.circle")
                    }
                    StreakChip(stage: .sapling, day: 9)
                }
                section("Palette") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                        ForEach(swatches, id: \.0) { name, color in
                            VStack(spacing: Theme.Spacing.xxs) {
                                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                    .fill(color)
                                    .frame(height: 52)
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Palette.moss))
                                Text(verbatim: name).font(Typography.caption)
                            }
                        }
                    }
                }

                section("Typography") {
                    Text(verbatim: "Sonder").font(Typography.wordHero)
                    Text(verbatim: "Word title").font(Typography.wordTitle)
                    Text(verbatim: "/ˈsɑːndər/").font(Typography.ipa)
                    Text(verbatim: "Screen title").font(Typography.title)
                    Text(verbatim: "Headline").font(Typography.headline)
                    Text(verbatim: "Body text reads friendly and approachable.").font(Typography.body)
                    Text(verbatim: "An example sentence, set in serif italic.").font(Typography.quote)
                    Text(verbatim: "CAPTION LABEL").font(Typography.label)
                    Text(verbatim: "1,240").font(Typography.stat)
                }

                section("Spacing & radius") {
                    HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                        ForEach([Theme.Spacing.xxs, Theme.Spacing.xs, Theme.Spacing.s, Theme.Spacing.m,
                                 Theme.Spacing.l, Theme.Spacing.xl, Theme.Spacing.xxl], id: \.self) { value in
                            Rectangle().fill(Theme.Palette.moss).frame(width: value, height: value)
                        }
                    }
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach([Theme.Radius.small, Theme.Radius.medium, Theme.Radius.large, Theme.Radius.card], id: \.self) { radius in
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(Theme.Palette.surface)
                                .frame(width: 64, height: 64)
                        }
                    }
                }

            }
            .padding(Theme.Spacing.m)
        }
        .sequoiaScreen()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(verbatim: title).font(Typography.title)
            content()
        }
    }
}

#Preview("Gallery") { DesignGalleryView() }
#Preview("Gallery – dark") { DesignGalleryView().preferredColorScheme(.dark) }
