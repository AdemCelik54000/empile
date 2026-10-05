/// A power the player can use at any time during a game: one of each to start, more from ads.
enum Ability: CaseIterable, Identifiable, Hashable, Sendable {
    /// The chosen piece takes another shape.
    case reshape
    /// The chosen piece takes another material, picked at random.
    case rematerial
    /// For a few seconds, a rope pulls any piece of the tower towards the finger.
    case pull
    /// One more life.
    case extraLife

    var id: Self { self }

    var title: String {
        switch self {
        case .reshape: "Forme"
        case .rematerial: "Matière"
        case .pull: "Grappin"
        case .extraLife: "Vie"
        }
    }

    var summary: String {
        switch self {
        case .reshape: "Change la forme d'une pièce"
        case .rematerial: "Donne une matière au hasard à une pièce"
        case .pull: "Tirez les pièces de la tour pendant \(Int(Tuning.Abilities.pullDuration)) secondes"
        case .extraLife: "Une vie de plus"
        }
    }

    var symbol: String {
        switch self {
        case .reshape: "arrow.triangle.2.circlepath"
        case .rematerial: "dice.fill"
        case .pull: "hand.draw.fill"
        case .extraLife: "heart.fill"
        }
    }

    /// The player picks a piece to change before it takes effect.
    var needsPiece: Bool { self == .reshape || self == .rematerial }
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
