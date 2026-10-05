import Foundation

/// When a bird visits the tower: away for a random while, flies in, perches on a piece for a few seconds
/// (its weight pulls that side down), then flies off.
struct BirdSchedule: Sendable {
    enum Phase: Equatable, Sendable {
        case away
        case arriving
        case perched
        case leaving
    }

    /// Time between two visits.
    let pause: ClosedRange<TimeInterval>
    /// Time to fly in, and to fly off.
    let flight: TimeInterval
    /// Time spent perched.
    let perch: ClosedRange<TimeInterval>
    private(set) var phase = Phase.away
    /// Time spent in the current phase.
    private(set) var elapsed: TimeInterval = 0
    /// How long the current phase lasts.
    private(set) var duration: TimeInterval = 0
    private var generator: SeededGenerator

    init(pause: ClosedRange<TimeInterval>, flight: TimeInterval, perch: ClosedRange<TimeInterval>, seed: UInt64) {
        self.pause = pause
        self.flight = flight
        self.perch = perch
        generator = SeededGenerator(seed: seed)
        duration = TimeInterval.random(in: pause, using: &generator)
    }

    /// Share of the current phase done, 0...1.
    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 1 }

    /// - Parameter isActive: While false (tower too low, game over), no new bird comes; one already there
    ///   finishes its visit.
    /// - Returns: The phases entered during this step, in order (empty when nothing changed).
    mutating func advance(by deltaTime: TimeInterval, isActive: Bool) -> [Phase] {
        guard isActive || phase != .away else {
            elapsed = 0
            return []
        }
        elapsed += max(0, deltaTime)
        var entered: [Phase] = []
        while elapsed >= duration {
            elapsed -= duration
            switch phase {
            case .away: enter(.arriving, for: flight)
            case .arriving: enter(.perched, for: TimeInterval.random(in: perch, using: &generator))
            case .perched: enter(.leaving, for: flight)
            case .leaving: enter(.away, for: TimeInterval.random(in: pause, using: &generator))
            }
            entered.append(phase)
            if phase == .away && !isActive {
                elapsed = 0
                break
            }
        }
        return entered
    }

    /// The bird flies off now: its perch moved too much, or there was nowhere to land.
    /// Ignored while it is already leaving or away.
    mutating func scare() {
        guard phase == .arriving || phase == .perched else { return }
        enter(.leaving, for: flight)
        elapsed = 0
    }

    /// No bird at all, and the next visit a whole pause away.
    mutating func reset() {
        enter(.away, for: TimeInterval.random(in: pause, using: &generator))
        elapsed = 0
    }

    /// Leaves `elapsed` alone: time left over from the phase that just ended carries into this one.
    private mutating func enter(_ phase: Phase, for duration: TimeInterval) {
        self.phase = phase
        self.duration = duration
    }
}
