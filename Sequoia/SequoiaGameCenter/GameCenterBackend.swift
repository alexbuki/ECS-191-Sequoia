import GameKit
import SequoiaSocial
import UIKit

/// The real Game Center backend. The app loads this framework on demand (see
/// `DeferredGameCenterBackend`) and finds the class by its Objective-C name.
///
/// Authentication is quiet: the system's sign-in screen is kept, not shown,
/// until the user chooses "Connect Game Center" in Forest.
@MainActor
@objc(SequoiaGameCenterBackend)
public final class GameCenterBackend: NSObject, SocialBackend, GKGameCenterControllerDelegate {
    public var onStatusChange: ((SocialStatus) -> Void)?
    private var signInController: UIViewController?

    override public init() {
        super.init()
    }

    public func authenticateQuietly() async -> SocialStatus {
        await withCheckedContinuation { continuation in
            var resumed = false
            // GameKit calls this again whenever the player's state changes.
            GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
                let notSupported = (error as? GKError)?.code == .notSupported
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.signInController = controller
                    let status = self.currentStatus(notSupported: notSupported)
                    if resumed {
                        self.onStatusChange?(status)
                    } else {
                        resumed = true
                        continuation.resume(returning: status)
                    }
                }
            }
        }
    }

    private func currentStatus(notSupported: Bool) -> SocialStatus {
        let player = GKLocalPlayer.local
        if player.isAuthenticated { return .signedIn(name: player.displayName) }
        return notSupported ? .unavailable : .signedOut
    }

    public func presentSignIn() {
        if let signInController {
            present(signInController)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            // No sign-in screen offered (for example, Game Center is off): the
            // Settings app is where the player turns it on.
            UIApplication.shared.open(url)
        }
    }

    public func submit(_ scores: [LeaderboardKind: Int]) async {
        for (kind, score) in scores {
            try? await GKLeaderboard.submitScore(
                score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [kind.leaderboardID]
            )
        }
    }

    public func friendsEntries(for kind: LeaderboardKind) async -> [LeaderboardEntry] {
        guard let board = try? await GKLeaderboard.loadLeaderboards(IDs: [kind.leaderboardID]).first,
              let result = try? await board.loadEntries(for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 25))
        else { return [] }
        let localID = GKLocalPlayer.local.gamePlayerID
        var entries = result.1.map { entry in
            LeaderboardEntry(id: entry.player.gamePlayerID, rank: entry.rank, name: entry.player.displayName,
                             score: entry.score, isLocalPlayer: entry.player.gamePlayerID == localID)
        }
        if let local = result.0, !entries.contains(where: \.isLocalPlayer) {
            entries.append(LeaderboardEntry(id: localID, rank: local.rank, name: local.player.displayName,
                                            score: local.score, isLocalPlayer: true))
        }
        return entries.sorted { $0.rank < $1.rank }
    }

    public func showLeaderboards() {
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = self
        present(controller)
    }

    public func showFriends() {
        let controller = GKGameCenterViewController(state: .localPlayerFriendsList)
        controller.gameCenterDelegate = self
        present(controller)
    }

    public nonisolated func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
        MainActor.assumeIsolated { controller.dismiss(animated: true) }
    }

    private func present(_ controller: UIViewController) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(controller, animated: true)
    }
}
