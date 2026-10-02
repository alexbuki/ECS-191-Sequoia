import Foundation
import Observation
import SequoiaCore
import SequoiaSocial

extension LeaderboardKind {
    var title: String {
        switch self {
        case .streak: String(localized: "Streak")
        case .trees: String(localized: "Trees")
        case .rings: String(localized: "Rings")
        }
    }

    /// The score to submit. Game Center keeps each player's best, so the
    /// streak board effectively ranks longest streaks.
    func score(from growth: GrowthState) -> Int {
        switch self {
        case .streak: growth.currentStreak
        case .trees: growth.plantedTrees
        case .rings: growth.totalRings
        }
    }
}

@MainActor
@Observable
final class SocialModel {
    private(set) var status: SocialStatus = .checking
    private(set) var entries: [LeaderboardKind: [LeaderboardEntry]] = [:]
    var selectedKind: LeaderboardKind = .streak
    private(set) var lastSubmitted: [LeaderboardKind: Int] = [:]

    @ObservationIgnored private let backend: SocialBackend
    @ObservationIgnored private var started = false

    init(backend: SocialBackend) {
        self.backend = backend
        backend.onStatusChange = { [weak self] status in
            self?.status = status
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = status { return true }
        return false
    }

    /// Friends other than the local player on the selected board.
    var hasFriends: Bool {
        (entries[selectedKind] ?? []).contains { !$0.isLocalPlayer }
    }

    func start() async {
        guard !started else { return }
        started = true
        status = await backend.authenticateQuietly()
    }

    func signIn() { backend.presentSignIn() }
    func showLeaderboards() { backend.showLeaderboards() }
    func showFriends() { backend.showFriends() }

    /// Submits any scores that changed since the last submission.
    func submitScores(from growth: GrowthState) async {
        guard isSignedIn else { return }
        let scores = Dictionary(uniqueKeysWithValues: LeaderboardKind.allCases.map { ($0, $0.score(from: growth)) })
        let changed = scores.filter { lastSubmitted[$0.key] != $0.value }
        guard !changed.isEmpty else { return }
        await backend.submit(changed)
        lastSubmitted.merge(changed) { _, new in new }
    }

    func loadEntries() async {
        guard isSignedIn else { return }
        let kind = selectedKind
        entries[kind] = await backend.friendsEntries(for: kind)
    }
}
