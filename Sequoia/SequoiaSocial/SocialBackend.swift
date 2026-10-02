import Foundation

// The interface between the app and its Game Center backend. It lives in its own
// small framework so the GameKit implementation (`SequoiaGameCenter`) can be
// loaded after launch: linking GameKit into the app adds over a second to cold
// launch on the simulator.

/// The three leaderboards. Their IDs must match the leaderboards configured in
/// App Store Connect for the app.
public enum LeaderboardKind: String, CaseIterable, Identifiable, Sendable {
    case streak, trees, rings

    public var id: String { rawValue }
    public var leaderboardID: String { "app.sequoia.Sequoia.leaderboard.\(rawValue)" }
}

public struct LeaderboardEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let rank: Int
    public let name: String
    public let score: Int
    public let isLocalPlayer: Bool

    public init(id: String, rank: Int, name: String, score: Int, isLocalPlayer: Bool) {
        self.id = id
        self.rank = rank
        self.name = name
        self.score = score
        self.isLocalPlayer = isLocalPlayer
    }
}

public enum SocialStatus: Equatable, Sendable {
    case checking
    case signedOut
    case signedIn(name: String)
    /// Game Center is restricted or unavailable on this device.
    case unavailable
}

@MainActor
public protocol SocialBackend: AnyObject {
    /// Called whenever sign-in state changes after the first check.
    var onStatusChange: ((SocialStatus) -> Void)? { get set }
    /// Checks sign-in without showing any UI.
    func authenticateQuietly() async -> SocialStatus
    /// Shows the sign-in flow, if the system offers one.
    func presentSignIn()
    func submit(_ scores: [LeaderboardKind: Int]) async
    /// Friends' entries (including the local player) for a board, best first.
    func friendsEntries(for kind: LeaderboardKind) async -> [LeaderboardEntry]
    func showLeaderboards()
    func showFriends()
}
