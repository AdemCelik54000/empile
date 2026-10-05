import GameKit
import Observation
import UIKit

/// Signs the player in to Game Center and keeps the leaderboard up to date with their record.
@MainActor
@Observable
final class GameCenterManager {
    /// The leaderboard id, to create with the same id in App Store Connect (Game Center > Leaderboards).
    static let leaderboardID = "app.empile.Empile.highscore"

    private(set) var isAuthenticated = false
    /// The record last sent, so it is never sent twice.
    @ObservationIgnored private var lastSubmitted = 0
    @ObservationIgnored private var pendingScore = 0

    /// Call once, when the app opens. Game Center may show its own sign in sheet.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated { self.flush() }
            }
        }
    }

    /// Sends `score` to the leaderboard, now if the player is signed in, or as soon as they are.
    func submit(_ score: Int) {
        guard score > lastSubmitted else { return }
        pendingScore = max(pendingScore, score)
        flush()
    }

    /// Opens Game Center on this game's leaderboard.
    func showLeaderboard() {
        GKAccessPoint.shared.trigger(
            leaderboardID: Self.leaderboardID, playerScope: .global, timeScope: .allTime
        ) {}
    }

    private func flush() {
        guard isAuthenticated, pendingScore > lastSubmitted else { return }
        let score = pendingScore
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardID]
                )
                lastSubmitted = max(lastSubmitted, score)
            } catch {
                // Offline or not set up yet: the next submission tries again.
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
