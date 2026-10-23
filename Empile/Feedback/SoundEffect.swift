/// Every sound the game can play.
enum SoundEffect: CaseIterable, Sendable {
    case stoneImpact
    case springImpact
    case glassImpact
    case goldImpact
    case springBoing
    case glassShatter
    case turn
    case perfect
    case ding
    case record
    case lifeLost
    case windGust
    case chirp
    case tensionDrone
    case gameOver

    /// Where a sound comes from: a recorded file in the app, or synthesized at launch.
    enum Source: Sendable {
        /// File name in the `Sounds` folder, without its `.wav` extension.
        case file(String)
        case synth(SoundRecipe)
    }

    /// The sound of a block of this kind hitting something.
    static func impact(of kind: BlockKind) -> SoundEffect {
        switch kind {
        case .stone: .stoneImpact
        case .spring: .springImpact
        case .glass: .glassImpact
        case .gold: .goldImpact
        }
    }

    var source: Source {
        switch self {
        case .stoneImpact: .file("pose")
        case .springImpact: .file("ressort")
        case .glassImpact: .file("verre")
        case .goldImpact: .file("or")
        case .perfect: .file("parfait")
        case .record: .file("record")
        case .lifeLost: .file("vie")
        case .springBoing: .synth(Tuning.Sound.springBoing)
        case .glassShatter: .synth(Tuning.Sound.glassShatter)
        case .turn: .synth(Tuning.Sound.turn)
        case .ding: .synth(Tuning.Sound.ding)
        case .windGust: .synth(Tuning.Sound.windGust)
        case .chirp: .synth(Tuning.Sound.chirp)
        case .tensionDrone: .synth(Tuning.Sound.tensionDrone)
        case .gameOver: .synth(Tuning.Sound.gameOver)
        }
    }

    /// The synthesis recipe, for sounds made in code.
    var recipe: SoundRecipe? {
        if case .synth(let recipe) = source { recipe } else { nil }
    }

    /// Played over and over at a volume set on the fly, rather than once.
    var loops: Bool { self == .tensionDrone }

    /// Fixed noise seed, so each sound is identical from one launch to the next.
    var seed: UInt64 {
        UInt64((SoundEffect.allCases.firstIndex(of: self) ?? 0) + 1)
    }
}
