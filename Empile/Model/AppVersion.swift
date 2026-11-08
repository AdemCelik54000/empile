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

/// La version que le joueur doit avoir au minimum, lue dans le fichier de version du site du jeu.
struct RequiredUpdate: Equatable, Sendable {
    let minimumVersion: AppVersion

    /// L'identifiant d'Empile sur l'App Store, pour ouvrir sa page.
    static let appStoreID = 6819031558

    var storeURL: URL { URL(string: "itms-apps://apps.apple.com/app/id\(Self.appStoreID)")! }

    /// Lit `{ "minimumVersion": "1.26" }`. Nil quand le fichier ne peut pas être lu.
    init?(versionFile data: Data) {
        struct File: Decodable {
            let minimumVersion: String
        }
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              let version = AppVersion(file.minimumVersion) else { return nil }
        self.init(minimumVersion: version)
    }

    init(minimumVersion: AppVersion) {
        self.minimumVersion = minimumVersion
    }

    /// Vrai seulement quand la version installée est strictement plus ancienne que le minimum.
    func isRequired(for installed: AppVersion?) -> Bool {
        guard let installed else { return false }
        return installed < minimumVersion
    }
}

/// What keeps the player from starting a game, if anything.
enum PlayBlocker: Equatable {
    case offline
    case updateRequired(RequiredUpdate)

    /// A game already running is never cut: the block only applies away from the tower.
    /// Without a connection the store cannot be opened anyway, so that comes first.
    static func current(isOnline: Bool, requiredUpdate: RequiredUpdate?, isInGame: Bool) -> PlayBlocker? {
        guard !isInGame else { return nil }
        if !isOnline { return .offline }
        if let requiredUpdate { return .updateRequired(requiredUpdate) }
        return nil
    }
}
