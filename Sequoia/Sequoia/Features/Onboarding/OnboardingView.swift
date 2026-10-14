import SwiftUI
import DesignSystem
import SequoiaCore

/// First launch only: one screen, one tap to the first word. It opens on a
/// grown forest, what the user is about to start. Difficulty and reminders
/// aren't asked here: the first word offers a level change, and the reminder
/// is offered after the first "Got it".
struct OnboardingView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    ForestScene(planted: 9, currentStage: .sapling, light: app.store.forestLight)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Sequoia")
                        .font(Typography.wordHero)
                    Text("Named for Sequoyah, a Cherokee linguist who developed the language's syllabary, and the tree that never ceases to grow.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.Palette.soilSecondary)
                        .multilineTextAlignment(.center)
                    Text("One word a day. Each one grows your tree.")
                        .font(Typography.headline)
                        .multilineTextAlignment(.center)
                    Button("Begin") { app.completeOnboarding() }
                        .buttonStyle(.sequoiaPrimary)
                        .padding(.top, Theme.Spacing.m)
                        .accessibilityIdentifier("onboardingBegin")
                }
                .padding(Theme.Spacing.l)
                // Centered when it fits; scrolls at large text sizes.
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .sequoiaScreen()
    }
}

#Preview("Onboarding") {
    OnboardingView().environment(AppModel.preview)
}

#Preview("Onboarding – dark") {
    OnboardingView().environment(AppModel.preview).preferredColorScheme(.dark)
}
