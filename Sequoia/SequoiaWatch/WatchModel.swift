import Foundation
import Observation
import WatchConnectivity
import WidgetKit
import SequoiaCore

/// The watch's view of today: the latest snapshot from the phone, rolled over
/// locally at midnight. "Got it" applies instantly and is sent to the phone,
/// which records it and syncs back.
@MainActor
@Observable
final class WatchModel: NSObject, WCSessionDelegate {
    private(set) var snapshot: WatchSnapshot
    /// Incremented on each check-in, to trigger a haptic.
    private(set) var checkInCount = 0

    override init() {
        snapshot = WatchSnapshotStore.current()
        super.init()
    }

    var word: Word { snapshot.word() }
    var stage: TreeStage { snapshot.stage() }
    var streak: Int { snapshot.growth.currentStreak }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Re-reads the saved snapshot (for example after midnight).
    func refresh() {
        snapshot = WatchSnapshotStore.current()
    }

    func gotIt() {
        guard let next = snapshot.checkingIn() else { return }
        apply(next)
        checkInCount += 1
        let message: [String: Any] = [WatchSnapshot.gotItKey: next.day.dayNumber]
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                let data = reply[WatchSnapshot.contextKey] as? Data
                Task { @MainActor in self?.receive(data) }
            }, errorHandler: { _ in
                // Not delivered right now: queue it; the phone applies it later.
                session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    private func apply(_ next: WatchSnapshot) {
        snapshot = next
        WatchSnapshotStore.save(next)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func receive(_ data: Data?) {
        guard let incoming = WatchSnapshot.decoded(from: data) else { return }
        apply(incoming.current(today: AppClock.live.today()))
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WatchSnapshot.contextKey] as? Data
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchSnapshot.contextKey] as? Data
        Task { @MainActor in self.receive(data) }
    }
}
