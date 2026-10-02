import SwiftUI
import DesignSystem
import SequoiaCore

/// First launch only: welcome → difficulty → reminder time → home.
/// Every step is a single tap, and every step can be skipped.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var difficulty: Difficulty?

    enum Step: Int, CaseIterable { case welcome, difficulty, reminder }

    struct ReminderOption: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let systemImage: String
        let time: DateComponents?
    }

    private let reminderOptions = [
        ReminderOption(id: "morning", title: "Morning · 8:00", systemImage: "sunrise", time: DateComponents(hour: 8, minute: 0)),
        ReminderOption(id: "midday", title: "Midday · 12:30", systemImage: "sun.max", time: DateComponents(hour: 12, minute: 30)),
        ReminderOption(id: "evening", title: "Evening · 19:00", systemImage: "sunset", time: DateComponents(hour: 19, minute: 0)),
        ReminderOption(id: "none", title: "No reminder", systemImage: "bell.slash", time: nil),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ProgressDots(count: Step.allCases.count, current: step.rawValue)
                Spacer()
                Button("Skip") { finish(reminder: nil, wantsReminder: true) }
                    .font(Typography.callout.weight(.semibold))
                    .foregroundStyle(Theme.Palette.bark)
                    .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("onboardingSkip")
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)

            ScrollView {
                Group {
                    switch step {
                    case .welcome: welcome
                    case .difficulty: difficultyStep
                    case .reminder: reminderStep
                    }
                }
                .padding(Theme.Spacing.l)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                   removal: .opacity))
                .id(step)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .sequoiaScreen()
    }

    private var welcome: some View {
        VStack(spacing: Theme.Spacing.l) {
            TreeView(stage: .seed)
                .frame(height: 160)
                .padding(.top, Theme.Spacing.xl)
            Text("Sequoia")
                .font(Typography.wordHero)
            Text("Named for Sequoyah, a Cherokee linguist who developed the language's syllabary, and the tree that never ceases to grow.")
                .font(Typography.body)
                .foregroundStyle(Theme.Palette.soilSecondary)
                .multilineTextAlignment(.center)
            Text("One word a day. Each one grows your tree.")
                .font(Typography.headline)
                .multilineTextAlignment(.center)
            Button("Begin") { advance(to: .difficulty) }
                .buttonStyle(.sequoiaPrimary)
                .padding(.top, Theme.Spacing.m)
                .accessibilityIdentifier("onboardingBegin")
        }
    }

    private var difficultyStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("How challenging should your words be?")
                .font(Typography.title)
                .padding(.top, Theme.Spacing.l)
            ForEach(Difficulty.allCases) { level in
                ChoiceRow(title: level.title, subtitle: level.subtitle, systemImage: icon(for: level),
                          isSelected: difficulty == level) {
                    difficulty = level
                    advance(to: .reminder)
                }
                .accessibilityIdentifier("difficulty-\(level.rawValue)")
            }
            Text("You can change this anytime in Settings.")
                .font(Typography.caption)
                .foregroundStyle(Theme.Palette.soilSecondary)
        }
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("When should your word arrive?")
                .font(Typography.title)
                .padding(.top, Theme.Spacing.l)
            Text("We'll send a gentle reminder. The word stays a surprise until you open the app.")
                .font(Typography.callout)
                .foregroundStyle(Theme.Palette.soilSecondary)
            ForEach(reminderOptions) { option in
                ChoiceRow(title: option.title, subtitle: nil, systemImage: option.systemImage, isSelected: false) {
                    finish(reminder: option.time, wantsReminder: option.time != nil)
                }
                .accessibilityIdentifier("reminder-\(option.id)")
            }
        }
    }

    private func icon(for level: Difficulty) -> String {
        switch level {
        case .everyday: "leaf"
        case .elevated: "tree"
        case .erudite: "mountain.2"
        }
    }

    private func advance(to next: Step) {
        withAnimation(Theme.Motion.growth(reduceMotion: reduceMotion)) { step = next }
    }

    private func finish(reminder: DateComponents?, wantsReminder: Bool) {
        Task {
            await app.completeOnboarding(difficulty: difficulty, reminder: reminder, wantsReminder: wantsReminder)
        }
    }
}

/// A large, single-tap choice.
struct ChoiceRow: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    init(title: String, subtitle: String?, systemImage: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: LocalizedStringKey(title), subtitle: subtitle, systemImage: systemImage, isSelected: isSelected, action: action)
    }

    init(title: LocalizedStringKey, subtitle: String?, systemImage: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: systemImage)
                    .font(Typography.headline)
                    .foregroundStyle(Theme.Palette.canopy)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.headline).foregroundStyle(Theme.Palette.soil)
                    if let subtitle {
                        Text(subtitle).font(Typography.callout).foregroundStyle(Theme.Palette.soilSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.soilSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .stroke(isSelected ? Theme.Palette.bark : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

/// Small step indicator.
struct ProgressDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.Palette.bark : Theme.Palette.moss)
                    .frame(width: index == current ? 20 : 8, height: 8)
            }
        }
        .frame(minHeight: Theme.Size.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
    }
}

#Preview("Onboarding") {
    OnboardingView().environment(AppModel.preview)
}

#Preview("Onboarding – dark") {
    OnboardingView().environment(AppModel.preview).preferredColorScheme(.dark)
}
