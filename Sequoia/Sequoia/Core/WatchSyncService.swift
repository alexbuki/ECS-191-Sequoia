import Foundation
import WatchConnectivity
import SequoiaCore

/// Keeps the watch in step with the phone: sends the current snapshot whenever
/// state changes, and applies "Got it" from the watch through the store.
@MainActor
final class WatchSyncService: NSObject, WCSessionDelegate {
    weak var app: AppModel?
    private var lastSent: WatchSnapshot?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snapshot: WatchSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              snapshot != lastSent, let data = snapshot.encoded() else { return }
        do {
            try session.updateApplicationContext([WatchSnapshot.contextKey: data])
            lastSent = snapshot
        } catch {
            lastSent = nil
        }
    }

    /// Checks in for `dayNumber` if it is still today, and returns the result.
    private func handleGotIt(dayNumber: Int?) -> WatchSnapshot? {
        guard let app else { return nil }
        app.store.reloadFromDisk()
        if dayNumber == app.store.today.dayNumber {
            app.store.checkIn()
        }
        return app.store.watchSnapshot
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let snapshot = self.app?.store.watchSnapshot { self.send(snapshot) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate() // the user switched watches
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.lastSent = nil
            if let snapshot = self.app?.store.watchSnapshot { self.send(snapshot) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let day = message[WatchSnapshot.gotItKey] as? Int
        let reply = UncheckedReply(handler: replyHandler)
        Task { @MainActor in
            let data = self.handleGotIt(dayNumber: day)?.encoded()
            reply.handler(data.map { [WatchSnapshot.contextKey: $0] } ?? [:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let day = userInfo[WatchSnapshot.gotItKey] as? Int
        Task { @MainActor in _ = self.handleGotIt(dayNumber: day) }
    }
}

/// WatchConnectivity's reply handler isn't marked Sendable; it is safe to call
/// from any thread.
private nonisolated struct UncheckedReply: @unchecked Sendable {
    let handler: ([String: Any]) -> Void
}
