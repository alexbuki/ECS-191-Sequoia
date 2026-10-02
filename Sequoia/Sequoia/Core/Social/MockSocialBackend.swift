#if SEQUOIA_DEV
import Foundation
import SequoiaSocial

/// Mock friends and leaderboard data for developer mode, so the social UI can
/// be exercised without an Apple ID or App Store Connect setup.
/// Compiled only in `SEQUOIA_DEV` builds.
@MainActor
final class MockSocialBackend: SocialBackend {
    enum Scenario: String, CaseIterable, Identifiable {
        /// Use the real Game Center.
        case off
        case signedOut
        case signedInNoFriends
        case signedInWithFriends

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: "Real Game Center"
            case .signedOut: "Mock: signed out"
            case .signedInNoFriends: "Mock: signed in, no friends"
            case .signedInWithFriends: "Mock: signed in with friends"
            }
        }

        private static let key = "dev.mockSocial"

        /// The chosen scenario: `-devMockSocial <scenario>` wins over the dev panel setting.
        static var current: Scenario {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-devMockSocial"), arguments.indices.contains(index + 1),
               let scenario = Scenario(rawValue: arguments[index + 1]) {
                return scenario
            }
            return UserDefaults.standard.string(forKey: key).flatMap(Scenario.init) ?? .off
        }

        static func save(_ scenario: Scenario) {
            UserDefaults.standard.set(scenario.rawValue, forKey: key)
        }
    }

    var onStatusChange: ((SocialStatus) -> Void)?
    private var scenario: Scenario
    /// Scores the app submitted, which is what "You" shows on each board.
    private(set) var submitted: [LeaderboardKind: Int] = [:]

    private static let friends: [(name: String, scores: [LeaderboardKind: Int])] = [
        ("Maya", [.streak: 21, .trees: 3, .rings: 980]),
        ("Jonah", [.streak: 6, .trees: 1, .rings: 310]),
        ("Priya", [.streak: 44, .trees: 5, .rings: 1_720]),
        ("Sam", [.streak: 2, .trees: 0, .rings: 90]),
    ]

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func authenticateQuietly() async -> SocialStatus {
        scenario == .signedOut ? .signedOut : .signedIn(name: "You")
    }

    func presentSignIn() {
        // Signing in from the mock opt-in skips straight to the friends scenario.
        scenario = .signedInWithFriends
        onStatusChange?(.signedIn(name: "You"))
    }

    func submit(_ scores: [LeaderboardKind: Int]) async {
        submitted.merge(scores) { _, new in new }
    }

    func friendsEntries(for kind: LeaderboardKind) async -> [LeaderboardEntry] {
        var rows = [(id: "local", name: String(localized: "You"), score: submitted[kind] ?? 0, isLocal: true)]
        if scenario == .signedInWithFriends {
            rows += Self.friends.map { (id: $0.name, name: $0.name, score: $0.scores[kind] ?? 0, isLocal: false) }
        }
        return rows.sorted { $0.score > $1.score }.enumerated().map { index, row in
            LeaderboardEntry(id: row.id, rank: index + 1, name: row.name, score: row.score, isLocalPlayer: row.isLocal)
        }
    }

    func showLeaderboards() {}
    func showFriends() {}
}
#endif
