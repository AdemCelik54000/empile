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

    /// One line of the global leaderboard.
    struct Row: Identifiable, Sendable {
        let rank: Int
        let name: String
        let score: String
        let isMe: Bool
        var id: Int { rank }
    }

    /// The player's own best score on the leaderboard, to get the record back after a reinstall.
    /// - Returns: `nil` when the player has no score yet, or the leaderboard cannot be reached.
    func loadMyScore() async -> Int? {
        guard isAuthenticated,
              let board = try? await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID]).first,
              let (me, _, _) = try? await board.loadEntries(
                  for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1))
        else { return nil }
        return me?.score
    }

    /// The best players of all time, the player's own line included even when outside the top.
    func loadTop(count: Int = 25) async throws -> [Row] {
        guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID]).first else {
            return []
        }
        let (me, entries, _) = try await board.loadEntries(
            for: .global, timeScope: .allTime, range: NSRange(location: 1, length: count)
        )
        func row(_ entry: GKLeaderboard.Entry) -> Row {
            Row(
                rank: entry.rank,
                name: entry.player.displayName,
                score: entry.formattedScore,
                isMe: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
            )
        }
        var rows = entries.map(row)
        if let me, !rows.contains(where: { $0.rank == me.rank }) { rows.append(row(me)) }
        return rows
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
