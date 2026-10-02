import SwiftUI

public extension View {
    /// Applies the Sequoia background and the rounded interface typeface.
    ///
    /// Uses a default `font` rather than `fontDesign`, because an environment
    /// font design would override the serif used for the word itself.
    func sequoiaScreen() -> some View {
        self
            .font(Typography.body)
            .foregroundStyle(Theme.Palette.soil)
            .background(Theme.Palette.fog.ignoresSafeArea())
    }
}

/// A calm, intentional empty/placeholder state.
public struct CalmEmptyState<Accessory: View>: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let systemImage: String
    private let accessory: Accessory

    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(Typography.icon)
                .foregroundStyle(Theme.Palette.canopy)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.soil)
            Text(message)
                .font(Typography.callout)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .multilineTextAlignment(.center)
            accessory
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

public extension CalmEmptyState where Accessory == EmptyView {
    init(_ title: LocalizedStringKey, message: LocalizedStringKey, systemImage: String) {
        self.init(title, message: message, systemImage: systemImage) { EmptyView() }
    }
}

#Preview("Empty state") {
    CalmEmptyState("Nothing here yet", message: "Your words will gather here.", systemImage: "leaf")
        .sequoiaScreen()
}

#Preview("Empty state – dark") {
    CalmEmptyState("Nothing here yet", message: "Your words will gather here.", systemImage: "leaf")
        .sequoiaScreen()
        .preferredColorScheme(.dark)
}
