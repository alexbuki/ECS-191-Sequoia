#if SEQUOIA_DEV
import SwiftUI
import WidgetKit
import DesignSystem
import SequoiaCore

/// Developer controls for moving time forward and testing features.
/// Compiled only in `SEQUOIA_DEV` builds.
struct DeveloperPanelView: View {
    @Environment(AppModel.self) private var app
    @State private var dev = DevModeController.shared
    @State private var forestCount = 10
    @State private var customDays = 5
    @State private var exactDate = Date.now
    @State private var pending: [(id: String, title: String, date: Date?)] = []
    @State private var socialScenario = MockSocialBackend.Scenario.current

    var body: some View {
        List {
            Section {
                Toggle("Developer mode", isOn: Binding(get: { dev.isEnabled }, set: {
                    dev.setEnabled($0)
                    app.rebuildStore()
                }))
            } footer: {
                Text("While on, the app uses a simulated clock and a separate store.")
            }

            Section("Design") {
                NavigationLink("Design gallery") { DesignGalleryView().navigationTitle("Design gallery") }
            }

            Section {
                Button("Fire daily notification now") {
                    Task {
                        await app.notifications.fireNow(store: app.store)
                        await refreshPending()
                    }
                }
                Button("Set reminder to 1 minute from now") {
                    DevLaunchActions.setReminder(minutesFromNow: 1, store: app.store)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await refreshPending()
                    }
                }
                LabeledContent("Pending", value: "\(pending.count)")
                    .accessibilityIdentifier("pendingCount")
                ForEach(pending.prefix(3), id: \.id) { request in
                    LabeledContent(request.title, value: request.date?.formatted(date: .abbreviated, time: .shortened) ?? "–")
                        .accessibilityIdentifier("pending-\(request.id)")
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Fires today's reminder in 3 seconds. Leave the app to see it as a banner.")
            }

            Section {
                Button("Reload widget timelines") { WidgetCenter.shared.reloadAllTimelines() }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Widgets also reload after every check-in and day change.")
            }

            Section {
                Picker("Game Center", selection: $socialScenario) {
                    ForEach(MockSocialBackend.Scenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .onChange(of: socialScenario) { _, scenario in
                    MockSocialBackend.Scenario.save(scenario)
                    app.rebuildSocial()
                }
            } header: {
                Text("Friends")
            } footer: {
                Text("Mock friends and leaderboard data, for testing without an Apple ID.")
            }

            if dev.isEnabled {
                Section("Time") {
                    LabeledContent("Simulated date", value: dev.simulatedNow.formatted(date: .abbreviated, time: .shortened))
                    Button("Advance 1 day") { dev.advance(days: 1); app.store.refresh() }
                    Stepper("Advance \(customDays) days", value: $customDays, in: 1...365)
                    Button("Advance \(customDays) days") { dev.advance(days: customDays); app.store.refresh() }
                    DatePicker("Exact date", selection: $exactDate)
                    Button("Set exact date") { dev.set(date: exactDate); app.store.refresh() }
                    Button("Reset to real time", role: .destructive) { dev.resetClock(); app.store.refresh() }
                }

                Section("Growth") {
                    Button("Check in for the next \(customDays) days") {
                        DevLaunchActions.simulateCheckIns(days: customDays, store: app.store)
                    }
                    Button("Simulate a missed day") { dev.advance(days: 2); app.store.refresh() }
                    Menu("Jump to tree stage") {
                        ForEach(TreeStage.allCases) { stage in
                            Button(stage.title) { app.store.devJump(to: stage) }
                        }
                    }
                    Stepper("Trees to plant: \(forestCount)", value: $forestCount, in: 1...200)
                    Button("Fill forest with \(forestCount) trees") { app.store.devFillForest(adding: forestCount) }
                    LabeledContent("Streak", value: "\(app.store.growth.currentStreak)")
                    LabeledContent("Stage", value: app.store.stage.title)
                    LabeledContent("Rings", value: "\(app.store.growth.totalRings)")
                    Button("Reset all progress", role: .destructive) { app.store.resetProgress() }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sequoiaScreen()
        .navigationTitle("Developer")
        .task { await refreshPending() }
    }

    private func refreshPending() async {
        pending = await app.notifications.pendingRequests()
    }
}

#Preview { NavigationStack { DeveloperPanelView() }.environment(AppModel.preview) }
#Preview("Dark") { NavigationStack { DeveloperPanelView() }.environment(AppModel.preview).preferredColorScheme(.dark) }
#endif
