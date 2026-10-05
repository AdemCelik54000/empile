/// One piece the player can place: its material and its shape (which the player may turn in the hand).
struct Card: Identifiable, Hashable, Sendable {
    let id: Int
    var kind: BlockKind
    var shape: BlockShape

    var definition: BlockDefinition { BlockCatalog.definition(for: kind) }
}

/// A shape the supply can deal, and how often: 4 shows up twice as often as 2.
struct WeightedShape: Sendable {
    let shape: BlockShape
    let weight: Int
}

/// How likely each material is at a given level of the climb.
struct MaterialOdds: Sendable {
    /// Chance of a tricky piece (spring or glass) at level 0.
    let hazard: Double
    /// Added to the hazard chance for every level reached.
    let hazardPerLevel: Double
    let maxHazard: Double
    /// Chance of a gold piece, whatever the level.
    let gold: Double

    func hazardChance(level: Int) -> Double {
        min(maxHazard, hazard + hazardPerLevel * Double(max(level, 0)))
    }
}

/// Deals pieces one at a time, forever. Never the same shape twice in a row, and more tricky materials
/// the higher the tower climbs.
struct PieceSupply: Sendable {
    let shapes: [WeightedShape]
    let odds: MaterialOdds
    private var nextID = 0
    private var lastFamily: ShapeFamily?

    init(shapes: [WeightedShape] = Tuning.Supply.shapes, odds: MaterialOdds = Tuning.Supply.odds) {
        self.shapes = shapes
        self.odds = odds
    }

    /// - Parameter level: Milestones reached so far; tricky pieces grow more common with it.
    mutating func next(level: Int, using generator: inout some RandomNumberGenerator) -> Card {
        let shape = pickShape(avoiding: lastFamily, using: &generator)
        lastFamily = shape.family
        let card = Card(id: nextID, kind: pickKind(level: level, using: &generator), shape: shape)
        nextID += 1
        return card
    }

    /// The same piece with another shape, never the one it had.
    func reshaped(_ card: Card, using generator: inout some RandomNumberGenerator) -> Card {
        var reshaped = card
        reshaped.shape = pickShape(avoiding: card.shape.family, using: &generator)
        return reshaped
    }

    /// The same piece in another material, picked at random, never the one it had.
    func rematerialized(_ card: Card, using generator: inout some RandomNumberGenerator) -> Card {
        var changed = card
        changed.kind = BlockKind.allCases.filter { $0 != card.kind }.randomElement(using: &generator) ?? card.kind
        return changed
    }

    private func pickKind(level: Int, using generator: inout some RandomNumberGenerator) -> BlockKind {
        let roll = Double.random(in: 0..<1, using: &generator)
        if roll < odds.gold {
            return .gold
        }
        if roll < odds.gold + odds.hazardChance(level: level) {
            return Bool.random(using: &generator) ? .spring : .glass
        }
        return .stone
    }

    /// A weighted random shape, from another family than `excluded` when there is one.
    private func pickShape(avoiding excluded: ShapeFamily?,
                           using generator: inout some RandomNumberGenerator) -> BlockShape {
        let allowed = shapes.filter { $0.shape.family != excluded && $0.weight > 0 }
        let pool = allowed.isEmpty ? shapes : allowed
        let total = pool.reduce(0) { $0 + max($1.weight, 0) }
        guard total > 0 else { return pool.first?.shape ?? .domino }
        var roll = Int.random(in: 0..<total, using: &generator)
        for entry in pool {
            roll -= max(entry.weight, 0)
            if roll < 0 {
                return entry.shape
            }
        }
        return pool[pool.count - 1].shape
    }
}
