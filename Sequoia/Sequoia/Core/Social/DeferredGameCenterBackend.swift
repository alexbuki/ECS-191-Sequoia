import Foundation
import SequoiaSocial

/// Stands in for the Game Center backend until it is needed.
///
/// GameKit is heavy: linking it into the app adds over a second to cold launch
/// on the simulator. The real backend lives in the embedded
/// `SequoiaGameCenter` framework, which the app does not link; this loads it in
/// the background on first use, so the word appears without waiting for GameKit.
@MainActor
final class DeferredGameCenterBackend: SocialBackend {
    var onStatusChange: ((SocialStatus) -> Void)? {
        didSet { loaded?.onStatusChange = onStatusChange }
    }

    private var loaded: SocialBackend?
    /// Loads the framework off the main thread; true once it is ready.
    private var loading: Task<Bool, Never>?

    func authenticateQuietly() async -> SocialStatus {
        await backend()?.authenticateQuietly() ?? .unavailable
    }

    func presentSignIn() {
        Task { await backend()?.presentSignIn() }
    }

    func submit(_ scores: [LeaderboardKind: Int]) async {
        await backend()?.submit(scores)
    }

    func friendsEntries(for kind: LeaderboardKind) async -> [LeaderboardEntry] {
        await backend()?.friendsEntries(for: kind) ?? []
    }

    func showLeaderboards() {
        Task { await backend()?.showLeaderboards() }
    }

    func showFriends() {
        Task { await backend()?.showFriends() }
    }

    private func backend() async -> SocialBackend? {
        if let loaded { return loaded }
        let task = loading ?? Task.detached(priority: .utility) { Self.loadFramework() }
        loading = task
        guard await task.value, loaded == nil,
              let type = NSClassFromString("SequoiaGameCenterBackend") as? NSObject.Type,
              let backend = type.init() as? SocialBackend
        else { return loaded }
        backend.onStatusChange = onStatusChange
        loaded = backend
        return backend
    }

    private nonisolated static func loadFramework() -> Bool {
        guard let url = Bundle.main.privateFrameworksURL?.appending(path: "SequoiaGameCenter.framework") else { return false }
        return Bundle(url: url)?.load() ?? false
    }
}
