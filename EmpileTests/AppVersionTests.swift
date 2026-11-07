import Foundation
import Testing
@testable import Empile

@Suite("Versions are compared number by number")
struct AppVersionTests {
    private func version(_ text: String) -> AppVersion { AppVersion(text)! }

    @Test func readsDotSeparatedNumbers() {
        #expect(AppVersion("1.23")?.numbers == [1, 23])
        #expect(AppVersion(" 2.0.1\n")?.numbers == [2, 0, 1])
        #expect(AppVersion("7")?.numbers == [7])
    }

    @Test func refusesAnythingElse() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1.") == nil)
        #expect(AppVersion(".1") == nil)
        #expect(AppVersion("1..2") == nil)
        #expect(AppVersion("1.2b") == nil)
        #expect(AppVersion("1.-2") == nil)
        #expect(AppVersion("v1.2") == nil)
    }

    @Test func tenComesAfterNine() {
        #expect(version("1.10") > version("1.9"))
        #expect(version("1.9") < version("1.10"))
        #expect(version("2.0") > version("1.99"))
        #expect(version("1.23") > version("1.22"))
    }

    @Test func missingNumbersCountAsZeros() {
        #expect(version("1.2") == version("1.2.0"))
        #expect(!(version("1.2") < version("1.2.0")))
        #expect(version("1.2.1") > version("1.2"))
        #expect(version("1") < version("1.0.1"))
    }

    @Test func onlyAStrictlyNewerStoreVersionRequiresAnUpdate() {
        let store = AppStoreRelease(version: version("1.23"), trackID: 1)
        #expect(store.isNewer(than: version("1.22")))
        #expect(store.isNewer(than: version("1.9")))
        #expect(!store.isNewer(than: version("1.23")))
        #expect(!store.isNewer(than: version("1.23.0")))
        // A build waiting for review is ahead of the store.
        #expect(!store.isNewer(than: version("1.24")))
        #expect(!store.isNewer(than: nil))
    }
}

@Suite("The App Store lookup answer")
struct AppStoreLookupTests {
    @Test func readsTheVersionAndTheStoreID() throws {
        let json = #"{"resultCount":1,"results":[{"trackId":6819031558,"version":"1.24","trackName":"Empile"}]}"#
        let release = try #require(AppStoreRelease(lookupResponse: Data(json.utf8)))
        #expect(release.version == AppVersion("1.24"))
        #expect(release.trackID == 6819031558)
        #expect(release.storeURL.absoluteString == "itms-apps://apps.apple.com/app/id6819031558")
    }

    @Test func aGameNotPublishedYetIsNotFound() {
        let json = #"{"resultCount":0,"results":[]}"#
        #expect(AppStoreRelease(lookupResponse: Data(json.utf8)) == nil)
    }

    @Test func anUnreadableAnswerIsNotFound() {
        #expect(AppStoreRelease(lookupResponse: Data("<html>".utf8)) == nil)
        let json = #"{"results":[{"trackId":1,"version":"bêta"}]}"#
        #expect(AppStoreRelease(lookupResponse: Data(json.utf8)) == nil)
    }
}

@Suite("What keeps the player from starting a game")
struct PlayBlockerTests {
    private let update = AppStoreRelease(version: AppVersion("9.0")!, trackID: 1)

    @Test func nothingWhenOnlineAndUpToDate() {
        #expect(PlayBlocker.current(isOnline: true, requiredUpdate: nil, isInGame: false) == nil)
    }

    @Test func blocksTheHomeScreen() {
        #expect(PlayBlocker.current(isOnline: false, requiredUpdate: nil, isInGame: false) == .offline)
        #expect(PlayBlocker.current(isOnline: true, requiredUpdate: update, isInGame: false) == .updateRequired(update))
    }

    @Test func noConnectionComesFirst() {
        #expect(PlayBlocker.current(isOnline: false, requiredUpdate: update, isInGame: false) == .offline)
    }

    @Test func neverCutsAGameInProgress() {
        #expect(PlayBlocker.current(isOnline: false, requiredUpdate: update, isInGame: true) == nil)
    }
}

@Suite("The first look at the App Store")
@MainActor
struct UpdateCheckerTests {
    @Test func startsUnchecked() {
        #expect(!UpdateChecker().isFirstCheckDone)
    }

    /// An App Store that never answers holds the first game back for a moment only.
    @Test func waitingGivesUpAtTheLimit() async {
        let clock = ContinuousClock()
        let start = clock.now
        await UpdateChecker().waitForFirstCheck(upTo: .milliseconds(300))
        let waited = clock.now - start
        #expect(waited >= .milliseconds(300))
        #expect(waited < .seconds(2))
    }
}
