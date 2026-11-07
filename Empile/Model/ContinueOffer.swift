import Foundation

/// L'offre « Continuer » de l'écran de défaite : le bouton se remplit pendant `window` secondes, puis devient gris.
/// Il ne se touche que pendant ce temps, si la partie peut encore être continuée et qu'une pub est prête.
struct ContinueOffer: Equatable, Sendable {
    /// How long the button can be touched, from the moment the game over panel appears.
    var window: TimeInterval = Tuning.Continue.window

    /// How full the button is, from 0 when the panel appears to 1 when the time is up.
    func progress(elapsed: TimeInterval) -> Double {
        guard window > 0 else { return 1 }
        return min(max(elapsed / window, 0), 1)
    }

    /// The time to touch the button is not over yet.
    func isOpen(elapsed: TimeInterval) -> Bool {
        elapsed < window
    }

    /// The button can be touched now.
    /// - Parameters:
    ///   - canContinue: The game was lost and has not been continued yet (`GameSession.canContinue`).
    ///   - isAdReady: A rewarded ad is loaded (or ads are off, in the testers' version).
    ///   - isBusy: An ad is on screen, or the player is already leaving the panel.
    func isAvailable(elapsed: TimeInterval, canContinue: Bool, isAdReady: Bool, isBusy: Bool = false) -> Bool {
        canContinue && isAdReady && !isBusy && isOpen(elapsed: elapsed)
    }
}
