import Foundation
import Observation
import WidgetKit
import SequoiaCore
import SequoiaSocial

/// App-wide state: the active store and the selected tab.
@MainActor
@Observable
final class AppModel {
    private(set) var store: SequoiaStore
    var selectedTab: AppTab = .today
    let notifications = NotificationService()
    let watchSync = WatchSyncService()
    private(set) var social: SocialModel
    private var rescheduleTask: Task<Void, Never>?

    /// Onboarding shows only until it is finished or skipped once.
    var needsOnboarding: Bool {
        !store.settings.hasCompletedOnboarding && !ProcessInfo.processInfo.arguments.contains("-uiTestingSkipOnboarding")
    }

    init(store: SequoiaStore? = nil) {
        #if SEQUOIA_DEV
        LaunchTiming.mark("appmodel-init")
        if store == nil { DevLaunchActions.applyBeforeLaunch() }
        #endif
        let container = store == nil ? Persistence.makeContainerOrFallback() : nil
        #if SEQUOIA_DEV
        LaunchTiming.mark("container")
        #endif
        self.store = store ?? SequoiaStore(container: container ?? Persistence.makeContainerOrFallback())
        #if SEQUOIA_DEV
        LaunchTiming.mark("store")
        #endif
        social = SocialModel(backend: Self.makeSocialBackend())
        #if SEQUOIA_DEV
        LaunchTiming.mark("social")
        #endif
        connectStore()
        #if SEQUOIA_DEV
        if store == nil {
            DevLaunchActions.apply(to: self.store)
            if let tab = DevLaunchActions.initialTab { selectedTab = tab }
        }
        #endif
        notifications.app = self
        notifications.configure()
        #if SEQUOIA_DEV
        LaunchTiming.mark("notifications")
        #endif
        storeDidChange()
        if store == nil {
            startSocial()
            watchSync.app = self
            watchSync.activate()
        }
        #if SEQUOIA_DEV
        LaunchTiming.mark("appmodel-done")
        #endif
    }

    private static func makeSocialBackend() -> SocialBackend {
        #if SEQUOIA_DEV
        let scenario = MockSocialBackend.Scenario.current
        if scenario != .off { return MockSocialBackend(scenario: scenario) }
        #endif
        return DeferredGameCenterBackend()
    }

    private func startSocial() {
        Task {
            await social.start()
            await social.submitScores(from: store.growth)
        }
    }

    #if SEQUOIA_DEV
    /// Switches between real Game Center and the mock scenarios (developer tool).
    func rebuildSocial() {
        social = SocialModel(backend: Self.makeSocialBackend())
        startSocial()
    }
    #endif

    /// Re-opens the store for the current location (used when dev mode toggles,
    /// which switches between the real and the simulated store).
    func rebuildStore() {
        store = SequoiaStore(container: Persistence.makeContainerOrFallback())
        connectStore()
        storeDidChange()
    }

    /// Called when the app returns to the foreground: picks up changes from the
    /// widget, the watch or a notification action, and a new day if one began.
    func sceneDidBecomeActive() {
        store.reloadFromDisk()
        storeDidChange()
    }

    /// Finishes onboarding with the chosen (or default) settings.
    func completeOnboarding(difficulty: Difficulty?, reminder: DateComponents?, wantsReminder: Bool) async {
        store.updateSettings { settings in
            if let difficulty { settings.difficulty = difficulty }
            if let hour = reminder?.hour, let minute = reminder?.minute {
                settings.reminderHour = hour
                settings.reminderMinute = minute
            }
            settings.notificationsEnabled = wantsReminder
            settings.hasCompletedOnboarding = true
        }
        if wantsReminder {
            await notifications.requestPermissionIfNeeded(store: store)
        }
    }

    /// Handles `sequoia://` deep links from widgets and notifications.
    func handle(url: URL) {
        guard url.scheme == "sequoia" else { return }
        switch url.host() {
        case "library": selectedTab = .library
        case "practice": selectedTab = .practice
        case "forest": selectedTab = .forest
        default: selectedTab = .today
        }
    }

    private func connectStore() {
        store.onChange = { [weak self] in self?.storeDidChange() }
    }

    /// Side effects after any change to user state, coalesced.
    private func storeDidChange() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            self.watchSync.send(self.store.watchSnapshot)
            await self.notifications.reschedule(store: self.store)
            await self.social.submitScores(from: self.store.growth)
        }
    }
}
