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

    @Test func onlyAnOlderInstalledVersionMustUpdate() {
        let minimum = RequiredUpdate(minimumVersion: version("1.26"))
        #expect(minimum.isRequired(for: version("1.25")))
        #expect(minimum.isRequired(for: version("1.9")))
        #expect(!minimum.isRequired(for: version("1.26")))
        #expect(!minimum.isRequired(for: version("1.26.0")))
        // A build waiting for review is ahead of the minimum.
        #expect(!minimum.isRequired(for: version("1.27")))
        #expect(!minimum.isRequired(for: nil))
    }
}

@Suite("The version file on the game's site")
struct VersionFileTests {
    @Test func readsTheMinimumVersion() throws {
        let json = #"{ "minimumVersion": "1.26" }"#
        let update = try #require(RequiredUpdate(versionFile: Data(json.utf8)))
        #expect(update.minimumVersion == AppVersion("1.26"))
        #expect(update.storeURL.absoluteString == "itms-apps://apps.apple.com/app/id6819031558")
    }

    @Test func anUnreadableFileLetsThePlayerIn() {
        #expect(RequiredUpdate(versionFile: Data("<html>404</html>".utf8)) == nil)
        #expect(RequiredUpdate(versionFile: Data(#"{ "version": "1.26" }"#.utf8)) == nil)
        #expect(RequiredUpdate(versionFile: Data(#"{ "minimumVersion": "bêta" }"#.utf8)) == nil)
    }
}

@Suite("What keeps the player from starting a game")
struct PlayBlockerTests {
    private let update = RequiredUpdate(minimumVersion: AppVersion("9.0")!)

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
