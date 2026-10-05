/// When an ad is due: after every `gamesPerAd` finished games (lost, or given up with "new game" or "quit"). The count is saved between launches
/// (see `GameSettings`), so quitting and relaunching the app never gives the player a fresh start.
struct AdSchedule: Equatable, Sendable {
    /// Finished games between two ads.
    let gamesPerAd: Int
    /// Games finished since the last ad was shown.
    private(set) var gamesSinceAd: Int

    init(gamesPerAd: Int = Tuning.Ads.gamesPerAd, gamesSinceAd: Int = 0) {
        self.gamesPerAd = max(1, gamesPerAd)
        self.gamesSinceAd = max(0, gamesSinceAd)
    }

    var isDue: Bool { gamesSinceAd >= gamesPerAd }

    mutating func finishGame() {
        gamesSinceAd += 1
    }

    /// The ad was shown: the count starts over. An ad that could not be shown leaves it alone, so the next
    /// game over tries again.
    mutating func adWasShown() {
        gamesSinceAd = 0
    }
}
