#if SEQUOIA_DEV
import SwiftUI
import DesignSystem
import SequoiaCore

/// A small, persistent badge showing the simulated date while dev mode is on,
/// so simulated progress is never confused with real use.
struct DevModeBadge: View {
    @State private var dev = DevModeController.shared

    var body: some View {
        if dev.isEnabled {
            let _ = dev.timeOffset
            Text("DEV · \(dev.simulatedNow.formatted(date: .abbreviated, time: .omitted))")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.onSunlight)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(Theme.Palette.sunlight, in: Capsule())
                .dynamicTypeSize(...DynamicTypeSize.large)
                .allowsHitTesting(false)
                .accessibilityLabel("Developer mode, simulated date \(dev.simulatedNow.formatted(date: .long, time: .omitted))")
        }
    }
}

#Preview { DevModeBadge().padding().sequoiaScreen() }
#Preview("Dark") { DevModeBadge().padding().sequoiaScreen().preferredColorScheme(.dark) }
#endif
