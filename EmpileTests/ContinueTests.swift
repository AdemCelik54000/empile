import Foundation
import Testing
@testable import Empile

@MainActor
@Suite("Continuer une partie perdue après une pub")
struct ContinueTests {
    private func lostGame(lives: Int = 2) -> GameSession {
        let session = GameSession(seed: 7, handSize: 3, lives: lives)
        for _ in 0..<lives {
            session.loseLife()
        }
        return session
    }

    // MARK: - La partie

    @Test func aGameInProgressCannotBeContinued() {
        let session = GameSession(seed: 7)
        #expect(!session.canContinue)
        #expect(!session.continueAfterLoss())
        #expect(session.lives == Tuning.Climb.lives)
    }

    @Test func continuingALostGameBringsItBackWithTheScoreAndHandKept() {
        let session = lostGame()
        let hand = session.hand.map(\.id)
        let score = session.score
        #expect(session.phase == .gameOver)
        #expect(session.canContinue)

        #expect(session.continueAfterLoss())
        #expect(session.phase == .playing)
        #expect(session.lives == Tuning.Continue.lives)
        #expect(session.hand.map(\.id) == hand)
        #expect(session.score == score)
        #expect(session.hasContinued)
    }

    @Test func aGameCanOnlyBeContinuedOnce() {
        let session = lostGame()
        #expect(session.continueAfterLoss())
        for _ in 0..<session.lives {
            session.loseLife()
        }
        #expect(session.phase == .gameOver)
        #expect(!session.canContinue)
        #expect(!session.continueAfterLoss())
        #expect(session.phase == .gameOver)
    }

    @Test func aNewGameCanBeContinuedAgain() {
        let session = lostGame()
        #expect(session.continueAfterLoss())
        session.startNewGame()
        #expect(!session.hasContinued)
        for _ in 0..<session.lives {
            session.loseLife()
        }
        #expect(session.canContinue)
    }

    // MARK: - Le bouton

    @Test func theButtonFillsUpOverTheWindow() {
        let offer = ContinueOffer(window: 5)
        #expect(offer.progress(elapsed: 0) == 0)
        #expect(offer.progress(elapsed: 2.5) == 0.5)
        #expect(offer.progress(elapsed: 5) == 1)
        #expect(offer.progress(elapsed: 12) == 1)
        #expect(offer.progress(elapsed: -1) == 0)
    }

    @Test func theWindowLastsWhatTuningSays() {
        #expect(ContinueOffer().window == Tuning.Continue.window)
        #expect(Tuning.Continue.window == 5)
    }

    @Test func theButtonCanBeTouchedDuringTheWindowOnly() {
        let offer = ContinueOffer(window: 5)
        #expect(offer.isAvailable(elapsed: 0, canContinue: true, isAdReady: true))
        #expect(offer.isAvailable(elapsed: 4.9, canContinue: true, isAdReady: true))
        #expect(!offer.isAvailable(elapsed: 5, canContinue: true, isAdReady: true))
        #expect(!offer.isAvailable(elapsed: 30, canContinue: true, isAdReady: true))
    }

    @Test func theButtonIsGreyWithoutAnAdReady() {
        let offer = ContinueOffer(window: 5)
        #expect(!offer.isAvailable(elapsed: 0, canContinue: true, isAdReady: false))
    }

    @Test func theButtonIsGreyOnceTheGameWasContinued() {
        let offer = ContinueOffer(window: 5)
        let session = lostGame()
        session.continueAfterLoss()
        session.loseLife()
        #expect(!offer.isAvailable(elapsed: 0, canContinue: session.canContinue, isAdReady: true))
    }

    @Test func theButtonWaitsWhileAnAdIsOnScreen() {
        let offer = ContinueOffer(window: 5)
        #expect(!offer.isAvailable(elapsed: 1, canContinue: true, isAdReady: true, isBusy: true))
    }
}
