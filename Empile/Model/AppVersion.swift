import Foundation

/// A version number like "1.23" or "2.0.1", compared number by number: 1.10 comes after 1.9, and 1.2 equals 1.2.0.
struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    let numbers: [Int]

    /// Nil when the text is not dot separated numbers.
    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        guard !numbers.isEmpty else { return nil }
        self.numbers = numbers
    }

    var description: String { numbers.map(String.init).joined(separator: ".") }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) == 0
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) < 0
    }

    /// Missing numbers count as zeros.
    private static func compare(_ lhs: AppVersion, _ rhs: AppVersion) -> Int {
        for index in 0..<max(lhs.numbers.count, rhs.numbers.count) {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }
}

/// The game as it is published on the App Store, read from the iTunes lookup service.
struct AppStoreRelease: Equatable, Sendable {
    let version: AppVersion
    /// The App Store id of the game, to open its page.
    let trackID: Int

    var storeURL: URL { URL(string: "itms-apps://apps.apple.com/app/id\(trackID)")! }

    /// Reads the first result of a lookup answer. Nil when the game is not found or the answer cannot be read.
    init?(lookupResponse data: Data) {
        struct Response: Decodable {
            struct Result: Decodable {
                let version: String
                let trackId: Int
            }
            let results: [Result]
        }
        guard let result = (try? JSONDecoder().decode(Response.self, from: data))?.results.first,
              let version = AppVersion(result.version) else { return nil }
        self.init(version: version, trackID: result.trackId)
    }

    init(version: AppVersion, trackID: Int) {
        self.version = version
        self.trackID = trackID
    }

    /// True only when the store has a strictly newer version than the one installed.
    func isNewer(than installed: AppVersion?) -> Bool {
        guard let installed else { return false }
        return version > installed
    }
}

/// What keeps the player from starting a game, if anything.
enum PlayBlocker: Equatable {
    case offline
    case updateRequired(AppStoreRelease)

    /// A game already running is never cut: the block only applies away from the tower.
    /// Without a connection the store cannot be opened anyway, so that comes first.
    static func current(isOnline: Bool, requiredUpdate: AppStoreRelease?, isInGame: Bool) -> PlayBlocker? {
        guard !isInGame else { return nil }
        if !isOnline { return .offline }
        if let requiredUpdate { return .updateRequired(requiredUpdate) }
        return nil
    }
}
