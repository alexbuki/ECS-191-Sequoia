import SwiftUI
import DesignSystem
import SequoiaCore

/// First launch only, two short pages: how Sequoia works (a word a day grows a
/// tree through its stages), then the two things worth asking: which words to
/// learn, and when to be reminded. Each page fits on screen; they scroll only
/// at accessibility text sizes.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var page = 0
    @State private var level: Difficulty = .elevated
    @State private var remind = true
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? .now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // A plain switch rather than a paged TabView, which ignores a programmatic
        // page change on iOS 18.
        ZStack {
            if page == 0 {
                OnboardingPage {
                    howItWorks
                } footer: {
                    Button("Continue") { go(to: 1) }
                        .buttonStyle(.sequoiaPrimary)
                        .accessibilityIdentifier("onboardingContinue")
                }
                .transition(pageTransition(leading: true))
            } else {
                OnboardingPage {
                    setup
                } footer: {
                    Button("Begin") {
                        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        app.completeOnboarding(level: level, reminderAt: remind ? time : nil)
                    }
                    .buttonStyle(.sequoiaPrimary)
                    .accessibilityIdentifier("onboardingBegin")
                }
                .overlay(alignment: .topLeading) {
                    Button { go(to: 0) } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(Typography.callout.weight(.semibold))
                            .foregroundStyle(Theme.Palette.bark)
                            .frame(minHeight: Theme.Size.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .accessibilityIdentifier("onboardingBack")
                }
                .transition(pageTransition(leading: false))
            }
        }
        .sequoiaScreen()
        .onAppear {
            reminderTime = Calendar.current.date(from: DateComponents(hour: app.store.settings.reminderHour,
                                                                      minute: app.store.settings.reminderMinute)) ?? reminderTime
        }
    }

    private func go(to newPage: Int) {
        withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { page = newPage }
    }

    private func pageTransition(leading: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: leading ? .leading : .trailing).combined(with: .opacity)
    }

    private var howItWorks: some View {
        let config = app.store.engine.config
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Sequoia")
                .font(Typography.wordHero)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Point(systemImage: "sun.horizon", title: "A new word every day",
                  detail: "Come back each day, learn the word, and tap Got it.")
            Point(systemImage: "leaf", title: "Each day grows your tree",
                  detail: "A sprout on day \(config.threshold(for: .sprout)), a sapling on day \(config.threshold(for: .sapling)), a young sequoia on day \(config.threshold(for: .youngSequoia)).")
            Point(systemImage: "tree", title: "Day \(config.daysToFullGrowth): a grown sequoia",
                  detail: "It joins your forest, and a new one sprouts.")
        }
        .accessibilityIdentifier("howItWorks")
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Choose your words")
                    .font(Typography.title)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Difficulty.allCases) { option in
                    LevelRow(level: option, isSelected: option == level) { level = option }
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                reminder
                Text("You can change both anytime in Settings.")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
            }
        }
    }

    /// One row: the switch, and the time beside it while it's on.
    private var reminder: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Daily reminder")
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.soil)
            Spacer(minLength: 0)
            if remind {
                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Toggle("Daily reminder", isOn: $remind.animation())
                .labelsHidden()
                .tint(Theme.Palette.bark)
                .accessibilityIdentifier("onboardingReminder")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

/// A page's content, centered, with its button pinned at the bottom.
private struct OnboardingPage<Content: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.m)
        }
    }
}

/// A line of the "how it works" page: a small symbol, a title and one sentence.
private struct Point: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.bark)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.headline).foregroundStyle(Theme.Palette.soil)
                Text(detail).font(Typography.callout).foregroundStyle(Theme.Palette.soilSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LevelRow: View {
    let level: Difficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title).font(Typography.headline).foregroundStyle(Theme.Palette.soil)
                    Text(level.subtitle).font(Typography.callout).foregroundStyle(Theme.Palette.soilSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(Typography.headline)
                    .foregroundStyle(isSelected ? Theme.Palette.bark : Theme.Palette.soilSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .stroke(isSelected ? Theme.Palette.bark : .clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("level-\(level.title)")
    }
}

#Preview("Onboarding") {
    OnboardingView().environment(AppModel.preview)
}

#Preview("Onboarding – dark") {
    OnboardingView().environment(AppModel.preview).preferredColorScheme(.dark)
}
