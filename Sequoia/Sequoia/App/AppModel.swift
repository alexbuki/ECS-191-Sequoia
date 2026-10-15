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
    /// Set to open Practice inside Library (a deep link or `-tab practice`);
    /// Library clears it once shown.
    var opensPractice = false
    /// The planting ceremony on screen. Every planted tree gets one, wherever
    /// it was planted, the next time the app is open.
    var ceremony: PlantedTreeMoment?
    let notifications = NotificationService()
    let watchSync = WatchSyncService()
    let cloudBackup = CloudBackupService()
    private(set) var social: SocialModel
    private var rescheduleTask: Task<Void, Never>?
    /// Set when the saved store wouldn't open and a throwaway one is in use,
    /// so nothing done now is saved. Retried each time the app becomes active.
    private(set) var storeError: (any Error)?
    /// The user chose to carry on without saving; asked again on the next failed retry.
    var storeErrorAcknowledged = false
    var showsStoreError: Bool { storeError != nil && !storeErrorAcknowledged }
    var hasStoreError: Bool { storeError != nil }

    /// Whether onboarding shows, decided at launch (so a reset brings it back on
    /// the next launch, not in the middle of Settings).
    private(set) var needsOnboarding = false

    /// The full-screen "Practice is unlocked" page (set by Today on day four).
    var showsPracticeUnlocked = false

    init(store: SequoiaStore? = nil) {
        #if SEQUOIA_DEV
        LaunchTiming.mark("appmodel-init")
        if store == nil { DevLaunchActions.applyBeforeLaunch() }
        #endif
        let opened = store == nil ? Persistence.openContainer() : nil
        #if SEQUOIA_DEV
        LaunchTiming.mark("container")
        #endif
        self.store = store ?? SequoiaStore(container: opened?.container ?? Persistence.makeContainerOrFallback())
        #if SEQUOIA_DEV
        LaunchTiming.mark("store")
        #endif
        social = SocialModel(backend: Self.makeSocialBackend())
        storeError = opened?.error
        // Before the developer launch tools, which may change these settings.
        setUpFirstLaunch()
        #if SEQUOIA_DEV
        LaunchTiming.mark("social")
        #endif
        #if SEQUOIA_DEV
        if store == nil {
            DevLaunchActions.apply(to: self.store)
            if DevLaunchActions.showsCeremony { ceremony = .preview(in: self.store) }
            if let tab = DevLaunchActions.initialTab { selectedTab = tab }
            if DevLaunchActions.opensPractice { selectedTab = .library; opensPractice = true }
        }
        #endif
        decideOnboarding()
        // Connected after the launch tools run; `storeDidChange` below covers their changes.
        connectStore()
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
            cloudBackup.app = self
            cloudBackup.activate()
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
        let opened = Persistence.openContainer()
        storeError = opened.error
        storeErrorAcknowledged = false
        store = SequoiaStore(container: opened.container)
        setUpFirstLaunch()
        decideOnboarding()
        connectStore()
        storeDidChange()
    }

    /// Called when the app returns to the foreground: picks up changes from the
    /// widget, the watch or a notification action, and a new day if one began.
    func sceneDidBecomeActive() {
        if storeError != nil { return rebuildStore() }
        store.reloadFromDisk()
        cloudBackup.restoreIfRicher()
        storeDidChange()
    }

    /// Erases progress here and in the iCloud backup, so it isn't restored.
    /// Onboarding comes back on the next launch.
    func resetProgress() {
        cloudBackup.clear()
        store.resetProgress()
        store.updateSettings { $0.hasCompletedOnboarding = false }
    }

    /// Onboarding shows until it's finished. Anyone who has already learned a
    /// word (restored from iCloud, or from the watch) skips it.
    private func decideOnboarding() {
        guard storeError == nil else { return needsOnboarding = false }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingSkipOnboarding"), !store.settings.hasCompletedOnboarding {
            // As if Begin were tapped with the defaults, so later launches aren't first launches.
            store.updateSettings { $0.hasCompletedOnboarding = true }
        }
        needsOnboarding = !store.settings.hasCompletedOnboarding && store.growth.totalCheckIns == 0
    }

    /// Shows the ceremony for any tree planted since the last one played.
    func presentPendingCeremony() {
        guard ceremony == nil, !needsOnboarding, let moment = PlantedTreeMoment.pending(in: store) else { return }
        ceremony = moment
        store.markCeremoniesShown()
    }

    /// First-launch defaults, applied before onboarding: reminders stay off until
    /// onboarding turns them on. If onboarding is skipped (an existing tree), the
    /// reminder is offered after the next "Got it".
    private func setUpFirstLaunch() {
        guard storeError == nil, !store.settings.hasCompletedOnboarding else { return }
        UserDefaults.standard.removeObject(forKey: Self.reminderOfferDismissedKey)
        UserDefaults.standard.removeObject(forKey: Self.practiceNudgeDismissedKey)
        store.updateSettings { $0.notificationsEnabled = false }
    }

    /// Finishes the one-screen onboarding with the chosen word level, and turns
    /// on the daily reminder (asking for permission) if the user wants one.
    /// The reminder was asked here, so it isn't offered again after the first "Got it".
    func completeOnboarding(level: Difficulty, reminderAt time: DateComponents?) {
        UserDefaults.standard.set(true, forKey: Self.reminderOfferDismissedKey)
        store.updateSettings { settings in
            settings.difficulty = level
            settings.hasCompletedOnboarding = true
        }
        needsOnboarding = false
        if let time { Task { await enableReminder(at: time) } }
    }

    /// Set when the user answers "Not now" to the reminder offer.
    static let reminderOfferDismissedKey = "reminderOfferDismissed"

    /// Set once the "Practice is unlocked" page has been closed.
    static let practiceNudgeDismissedKey = "practiceNudgeDismissed"

    /// Turns on the daily reminder at `time` and asks for permission if needed.
    func enableReminder(at time: DateComponents) async {
        store.updateSettings { settings in
            settings.reminderHour = time.hour ?? settings.reminderHour
            settings.reminderMinute = time.minute ?? settings.reminderMinute
            settings.notificationsEnabled = true
        }
        await notifications.requestPermissionIfNeeded(store: store)
    }

    /// Handles `sequoia://` deep links from widgets and notifications.
    func handle(url: URL) {
        guard url.scheme == "sequoia" else { return }
        switch url.host() {
        case "library": selectedTab = .library
        case "practice": selectedTab = .library; opensPractice = true
        case "forest": selectedTab = .forest
        default: selectedTab = .today
        }
    }

    private func connectStore() {
        store.onChange = { [weak self] in self?.storeDidChange() }
    }

    /// Side effects after any change to user state, coalesced.
    func storeDidChange() {
        presentPendingCeremony()
        rescheduleTask?.cancel()
        rescheduleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            // A throwaway store would overwrite the watch's copy with empty progress.
            if self.storeError == nil { self.watchSync.send(self.store.watchSnapshot) }
            self.cloudBackup.save()
            await self.notifications.reschedule(store: self.store)
            await self.social.submitScores(from: self.store.growth)
        }
    }
}
