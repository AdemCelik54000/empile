import CoreGraphics
import Foundation

/// What the wind is doing at one moment of the game.
struct WindState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case calm
        /// A gust is coming: the player sees and hears it before it pushes anything.
        case warning
        case blowing
    }

    static let calm = WindState(phase: .calm, direction: 1, strength: 0)

    var phase: Phase
    /// 1 blows towards the right, -1 towards the left.
    var direction: CGFloat
    /// Share of the full gust, 0...1: it rises smoothly, then dies down.
    var strength: CGFloat
}

/// The wind as the interface shows it: only what changes rarely, never the strength of every frame.
struct WindAlert: Equatable, Sendable {
    let isBlowing: Bool
    /// 1 blows towards the right, -1 towards the left.
    let direction: CGFloat

    /// `nil` while the air is calm.
    init?(_ state: WindState) {
        guard state.phase != .calm else { return nil }
        isBlowing = state.phase == .blowing
        direction = state.direction
    }
}

/// When gusts come: a calm spell of random length, a short warning, then a gust that swells and fades,
/// each time from a random side.
struct WindSchedule: Sendable {
    /// Calm time between two gusts.
    let pause: ClosedRange<TimeInterval>
    let warning: TimeInterval
    let gust: ClosedRange<TimeInterval>
    private(set) var state = WindState.calm
    /// Time spent in the current phase.
    private var elapsed: TimeInterval = 0
    /// How long the current phase lasts.
    private var phaseDuration: TimeInterval = 0
    private var generator: SeededGenerator
    /// The gust curve is a sine scaled by this, then capped at 1: the larger, the longer it stays at full strength.
    static let plateau: CGFloat = 1.6

    init(pause: ClosedRange<TimeInterval>, warning: TimeInterval, gust: ClosedRange<TimeInterval>, seed: UInt64) {
        self.pause = pause
        self.warning = warning
        self.gust = gust
        generator = SeededGenerator(seed: seed)
        phaseDuration = TimeInterval.random(in: pause, using: &generator)
    }

    /// - Parameter isActive: While false (tower too low, game over), the air stays calm and no gust is on its way.
    /// - Returns: The wind after `deltaTime` more seconds.
    @discardableResult
    mutating func advance(by deltaTime: TimeInterval, isActive: Bool) -> WindState {
        guard isActive else {
            if state.phase != .calm {
                startCalm()
            }
            return state
        }
        elapsed += max(0, deltaTime)
        while elapsed >= phaseDuration {
            elapsed -= phaseDuration
            switch state.phase {
            case .calm:
                state = WindState(phase: .warning, direction: Bool.random(using: &generator) ? 1 : -1, strength: 0)
                phaseDuration = warning
            case .warning:
                state.phase = .blowing
                phaseDuration = TimeInterval.random(in: gust, using: &generator)
            case .blowing:
                startCalm()
            }
        }
        // A short rise, a long stretch at full strength, a short fall.
        state.strength = state.phase == .blowing && phaseDuration > 0
            ? min(1, CGFloat(sin(.pi * elapsed / phaseDuration)) * WindSchedule.plateau)
            : 0
        return state
    }

    private mutating func startCalm() {
        state = WindState(phase: .calm, direction: state.direction, strength: 0)
        elapsed = 0
        phaseDuration = TimeInterval.random(in: pause, using: &generator)
    }
}
