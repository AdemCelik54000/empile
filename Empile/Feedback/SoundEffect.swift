/// Every sound the game can play.
enum SoundEffect: CaseIterable, Sendable {
    case stoneImpact
    case springImpact
    case glassImpact
    case goldImpact
    case springBoing
    case glassShatter
    case pickup
    case turn
    case ding
    case lifeLost
    case windGust
    case chirp
    case tensionDrone
    case gameOver

    /// The sound of a block of this kind hitting something.
    static func impact(of kind: BlockKind) -> SoundEffect {
        switch kind {
        case .stone: .stoneImpact
        case .spring: .springImpact
        case .glass: .glassImpact
        case .gold: .goldImpact
        }
    }

    var recipe: SoundRecipe {
        switch self {
        case .stoneImpact: Tuning.Sound.stoneImpact
        case .springImpact: Tuning.Sound.springImpact
        case .glassImpact: Tuning.Sound.glassImpact
        case .goldImpact: Tuning.Sound.goldImpact
        case .springBoing: Tuning.Sound.springBoing
        case .glassShatter: Tuning.Sound.glassShatter
        case .pickup: Tuning.Sound.pickup
        case .turn: Tuning.Sound.turn
        case .ding: Tuning.Sound.ding
        case .lifeLost: Tuning.Sound.lifeLost
        case .windGust: Tuning.Sound.windGust
        case .chirp: Tuning.Sound.chirp
        case .tensionDrone: Tuning.Sound.tensionDrone
        case .gameOver: Tuning.Sound.gameOver
        }
    }

    /// Played over and over at a volume set on the fly, rather than once.
    var loops: Bool { self == .tensionDrone }

    /// Fixed noise seed, so each sound is identical from one launch to the next.
    var seed: UInt64 {
        UInt64((SoundEffect.allCases.firstIndex(of: self) ?? 0) + 1)
    }
}
