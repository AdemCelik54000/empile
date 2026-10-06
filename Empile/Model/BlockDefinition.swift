/// What a piece is made of. Rules read its definition; the visual layer maps it to a look and a sound.
enum BlockKind: Hashable, Sendable, CaseIterable {
    case stone
    case spring
    case glass
    case gold

    /// The materials the game deals and the dice can give. Glass is out of the game for now: its rules and
    /// look stay in place, so putting it back is just adding it here.
    static let inPlay: [BlockKind] = [.stone, .spring, .gold]
}

/// What a piece does beyond being stacked.
enum BlockPower: Equatable, Sendable {
    case none
    /// The next piece to land on top of it is launched upward. Works once.
    case bounceNextBlock
    /// Breaks once too many pieces rest on it.
    case shattersUnderLoad
}

/// Everything that describes a material, as plain data.
/// Adding a material means adding a definition here, never touching the scene.
struct BlockDefinition: Equatable, Sendable {
    let kind: BlockKind
    let name: String
    /// SF Symbol shown in the hand under the piece.
    let symbol: String
    /// One sentence for the rules screen and VoiceOver.
    let summary: String
    let material: Material
    /// Points for each square of the piece, once it is placed.
    let pointsPerCell: Int
    let power: BlockPower
}

enum BlockCatalog {
    static let stone = BlockDefinition(
        kind: .stone,
        name: String(localized: "Pierre"),
        symbol: "square.fill",
        summary: String(localized: "Lourde et stable : la base de toute tour."),
        material: Tuning.Materials.stone,
        pointsPerCell: Tuning.Score.stonePerCell,
        power: .none
    )

    static let spring = BlockDefinition(
        kind: .spring,
        name: String(localized: "Ressort"),
        symbol: "arrow.up",
        summary: String(localized: "Léger. La prochaine pièce posée dessus rebondit vers le haut."),
        material: Tuning.Materials.spring,
        pointsPerCell: Tuning.Score.springPerCell,
        power: .bounceNextBlock
    )

    static let glass = BlockDefinition(
        kind: .glass,
        name: String(localized: "Verre"),
        symbol: "exclamationmark.triangle.fill",
        summary: String(localized: """
            Glissant et fragile : se brise si plus de \(Tuning.Powers.glassMaxLoad) pièces s'empilent dessus \
            avant qu'il ne sorte de l'écran.
            """),
        material: Tuning.Materials.glass,
        pointsPerCell: Tuning.Score.glassPerCell,
        power: .shattersUnderLoad
    )

    static let gold = BlockDefinition(
        kind: .gold,
        name: String(localized: "Or"),
        symbol: "scalemass.fill",
        summary: String(localized: "Très lourd et collant : rien ne glisse dessus. Le meilleur appui, à acheter en boutique."),
        material: Tuning.Materials.gold,
        pointsPerCell: Tuning.Score.goldPerCell,
        power: .none
    )

    static let all = [stone, spring, glass, gold]

    static func definition(for kind: BlockKind) -> BlockDefinition {
        switch kind {
        case .stone: stone
        case .spring: spring
        case .glass: glass
        case .gold: gold
        }
    }
}
