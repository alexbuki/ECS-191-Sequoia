import SwiftUI
import SequoiaCore

/// A compact stat: a big number and a short label.
public struct StatTile: View {
    private let value: String
    private let label: LocalizedStringKey
    private let systemImage: String

    public init(value: String, label: LocalizedStringKey, systemImage: String) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(Typography.callout)
                .foregroundStyle(Theme.Palette.canopy)
                .accessibilityHidden(true)
            Text(value)
                .font(Typography.stat)
                .foregroundStyle(Theme.Palette.soil)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.Palette.soilSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}

/// The small, quiet streak indicator: a tiny tree next to "Day 12".
public struct StreakChip: View {
    private let stage: TreeStage
    private let day: Int

    public init(stage: TreeStage, day: Int) {
        self.stage = stage
        self.day = day
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TreeView(stage: stage, showsGround: false)
                .frame(height: 26)
            Text(day == 0 ? String(localized: "Plant a seed", bundle: .module) : String(localized: "Day \(day)", bundle: .module))
                .font(Typography.label)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(Theme.Palette.surface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day == 0
            ? String(localized: "No streak yet. \(stage.accessibilityDescription).", bundle: .module)
            : String(localized: "\(stage.title), day \(day) of your streak", bundle: .module))
    }
}

#Preview("Stats") {
    VStack {
        HStack { StatTile(value: "12", label: "Day streak", systemImage: "flame"); StatTile(value: "340", label: "Rings", systemImage: "circle.circle") }
        StreakChip(stage: .sapling, day: 9)
    }
    .padding()
    .sequoiaScreen()
}

#Preview("Stats – dark") {
    VStack {
        HStack { StatTile(value: "12", label: "Day streak", systemImage: "flame"); StatTile(value: "340", label: "Rings", systemImage: "circle.circle") }
        StreakChip(stage: .sapling, day: 9)
    }
    .padding()
    .sequoiaScreen()
    .preferredColorScheme(.dark)
}
