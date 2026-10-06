import Foundation
import Testing
@testable import Empile

@MainActor
@Suite("Settings, record and selection")
struct InterfaceStateTests {
    private func freshDefaults() -> UserDefaults {
        let name = "EmpileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func soundAndVibrationsAreOnByDefault() {
        let settings = GameSettings(defaults: freshDefaults())
        #expect(settings.isSoundOn)
        #expect(settings.isHapticsOn)
    }

    @Test func settingsSurviveARelaunch() {
        let defaults = freshDefaults()
        let settings = GameSettings(defaults: defaults)
        settings.isSoundOn = false
        settings.isHapticsOn = false
        let relaunched = GameSettings(defaults: defaults)
        #expect(!relaunched.isSoundOn)
        #expect(!relaunched.isHapticsOn)
    }

    @Test func theRecordOnlyRisesAndSurvivesARelaunch() {
        let defaults = freshDefaults()
        let settings = GameSettings(defaults: defaults)
        #expect(settings.bestScore == 0)
        #expect(settings.recordScore(1200))
        #expect(!settings.recordScore(800))
        #expect(GameSettings(defaults: defaults).bestScore == 1200)
    }

    @Test func onlyThePieceToPlaceCanBePickedUp() {
        let session = GameSession(seed: 3)
        let first = session.hand[0].id
        #expect(session.pickUp(session.hand[1].id) == nil)
        #expect(session.pickUp(first)?.id == first)
    }
}

@Suite("Ads: every fifth game, even across launches")
struct AdScheduleTests {
    @Test func anAdIsDueAfterEveryFifthGame() {
        var schedule = AdSchedule(gamesPerAd: 5)
        for _ in 0..<4 {
            schedule.finishGame()
            #expect(!schedule.isDue)
        }
        schedule.finishGame()
        #expect(schedule.isDue)
    }

    @Test func showingTheAdStartsTheCountOver() {
        var schedule = AdSchedule(gamesPerAd: 2)
        schedule.finishGame()
        schedule.finishGame()
        schedule.adWasShown()
        #expect(!schedule.isDue)
        #expect(schedule.gamesSinceAd == 0)
    }

    @Test func anAdThatCouldNotBeShownIsStillDueAtTheNextGame() {
        var schedule = AdSchedule(gamesPerAd: 2)
        schedule.finishGame()
        schedule.finishGame()
        schedule.finishGame()
        #expect(schedule.isDue)
    }

    @MainActor
    @Test func theCountSurvivesARelaunch() {
        let name = "EmpileTests.ads.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = GameSettings(defaults: defaults)
        for _ in 0..<3 {
            settings.registerFinishedGame()
        }
        let relaunched = GameSettings(defaults: defaults)
        #expect(relaunched.adSchedule.gamesSinceAd == 3)
        for _ in 0..<(Tuning.Ads.gamesPerAd - 3) {
            relaunched.registerFinishedGame()
        }
        #expect(relaunched.adSchedule.isDue)
        relaunched.registerAdShown()
        #expect(GameSettings(defaults: defaults).adSchedule.gamesSinceAd == 0)
    }
}

@Suite("Ad units")
struct AdUnitsTests {
    @Test func testBuildsNeverUseTheRealAdUnit() async {
        #expect(await !AdUnits.isAppStoreBuild)
        #expect(await AdUnits.interstitialID() == Tuning.Ads.testInterstitialUnitID)
    }

    @Test func theRealAndTestUnitsAreDifferent() {
        #expect(Tuning.Ads.liveInterstitialUnitID != Tuning.Ads.testInterstitialUnitID)
        #expect(Tuning.Ads.liveInterstitialUnitID.hasPrefix("ca-app-pub-"))
    }
}
