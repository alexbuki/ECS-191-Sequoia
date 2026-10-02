import SwiftUI

/// The single primary action on a screen: a full-width redwood capsule.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(Theme.Palette.onBark)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Theme.Spacing.l)
            .background(Theme.Palette.bark.opacity(isEnabled ? 1 : 0.45), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.settle, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A quiet secondary action on a moss surface.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout.weight(.semibold))
            .foregroundStyle(Theme.Palette.soil)
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: 44)
            .background(Theme.Palette.moss, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// A round icon button (audio, favorite, share).
public struct IconButtonStyle: ButtonStyle {
    private let isActive: Bool

    public init(isActive: Bool = false) {
        self.isActive = isActive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(isActive ? Theme.Palette.onBark : Theme.Palette.bark)
            .frame(minWidth: 44, minHeight: 44)
            .background(isActive ? Theme.Palette.bark : Theme.Palette.moss, in: Circle())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Circle())
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var sequoiaPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var sequoiaSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview("Buttons") {
    VStack(spacing: Theme.Spacing.m) {
        Button("Got it") {}.buttonStyle(.sequoiaPrimary)
        Button("I already knew this") {}.buttonStyle(.sequoiaSecondary)
        HStack {
            Button {} label: { Image(systemName: "speaker.wave.2") }.buttonStyle(IconButtonStyle())
            Button {} label: { Image(systemName: "heart.fill") }.buttonStyle(IconButtonStyle(isActive: true))
        }
    }
    .padding()
    .sequoiaScreen()
}

#Preview("Buttons – dark") {
    VStack(spacing: Theme.Spacing.m) {
        Button("Got it") {}.buttonStyle(.sequoiaPrimary)
        Button("I already knew this") {}.buttonStyle(.sequoiaSecondary)
    }
    .padding()
    .sequoiaScreen()
    .preferredColorScheme(.dark)
}
