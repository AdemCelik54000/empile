/// A power the player can use at any time during a game: one of each to start, more from ads.
enum Ability: CaseIterable, Identifiable, Hashable, Sendable {
    /// The chosen piece takes another shape.
    case reshape
    /// Everything in the tower stops dead and stays put for good, as solid as the platform.
    case freeze
    /// For a few seconds, a rope pulls any piece of the tower towards the finger.
    case pull
    /// One more life.
    case extraLife

    var id: Self { self }

    var title: String {
        switch self {
        case .reshape: "Forme"
        case .freeze: "Gel"
        case .pull: "Grappin"
        case .extraLife: "Vie"
        }
    }

    var summary: String {
        switch self {
        case .reshape: "Nouvelle forme"
        case .freeze: "Fige toute la tour"
        case .pull: "Tirez les pièces"
        case .extraLife: "+1 vie"
        }
    }

    var symbol: String {
        switch self {
        case .reshape: "arrow.triangle.2.circlepath"
        case .freeze: "snowflake"
        case .pull: "hand.draw.fill"
        case .extraLife: "heart.fill"
        }
    }

    /// The player picks a piece to change before it takes effect.
    var needsPiece: Bool { self == .reshape }
}

/// How many of each power the player holds.
struct AbilityStock: Equatable, Sendable {
    private var counts: [Ability: Int]

    init(each count: Int) {
        counts = Dictionary(uniqueKeysWithValues: Ability.allCases.map { ($0, max(0, count)) })
    }

    func count(of ability: Ability) -> Int { counts[ability] ?? 0 }

    mutating func add(_ ability: Ability) {
        counts[ability, default: 0] += 1
    }

    /// - Returns: Whether one was left to use.
    mutating func use(_ ability: Ability) -> Bool {
        guard count(of: ability) > 0 else { return false }
        counts[ability, default: 0] -= 1
        return true
    }
}
