import Foundation
import Observation

/// The player's preferences, kept between launches.
@MainActor
@Observable
final class GameSettings {
    private enum Key {
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let hasPlacedFirstBlock = "settings.hasPlacedFirstBlock"
        static let bestScore = "record.bestScore"
        static let gamesSinceAd = "ads.gamesSinceAd"
    }

    var isSoundOn: Bool {
        didSet { defaults.set(isSoundOn, forKey: Key.sound) }
    }

    var isHapticsOn: Bool {
        didSet { defaults.set(isHapticsOn, forKey: Key.haptics) }
    }

    /// Until the first block is placed, the game shows how to place one.
    var hasPlacedFirstBlock: Bool {
        didSet { defaults.set(hasPlacedFirstBlock, forKey: Key.hasPlacedFirstBlock) }
    }

    /// The best score ever, in points.
    private(set) var bestScore: Int {
        didSet { defaults.set(bestScore, forKey: Key.bestScore) }
    }

    /// Finished games since the last ad. Kept between launches.
    private(set) var adSchedule: AdSchedule {
        didSet { defaults.set(adSchedule.gamesSinceAd, forKey: Key.gamesSinceAd) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isSoundOn = defaults.object(forKey: Key.sound) as? Bool ?? true
        isHapticsOn = defaults.object(forKey: Key.haptics) as? Bool ?? true
        hasPlacedFirstBlock = defaults.bool(forKey: Key.hasPlacedFirstBlock)
        bestScore = defaults.integer(forKey: Key.bestScore)
        adSchedule = AdSchedule(gamesSinceAd: defaults.integer(forKey: Key.gamesSinceAd))
    }

    /// A game just ended: lost, or given up with "new game" or "quit".
    func registerFinishedGame() {
        adSchedule.finishGame()
    }

    /// An ad was shown to the player.
    func registerAdShown() {
        adSchedule.adWasShown()
    }

    /// - Returns: Whether `score` beats the record (which then becomes `score`).
    @discardableResult
    func recordScore(_ score: Int) -> Bool {
        guard score > bestScore else { return false }
        bestScore = score
        return true
    }
}
