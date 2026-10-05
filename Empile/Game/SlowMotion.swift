import CoreGraphics
import Foundation

/// A brief slow-down of the physics, for dramatic moments: holds a low speed, then eases back to normal.
struct SlowMotion: Sendable {
    private var startTime: TimeInterval?

    mutating func trigger(at time: TimeInterval) {
        guard !isActive(at: time) else { return }
        startTime = time
    }

    mutating func cancel() {
        startTime = nil
    }

    func isActive(at time: TimeInterval) -> Bool {
        guard let startTime else { return false }
        return time - startTime < Tuning.SlowMotion.holdDuration + Tuning.SlowMotion.rampDuration
    }

    /// Physics speed factor: 1 when inactive.
    func speed(at time: TimeInterval) -> CGFloat {
        guard let startTime, isActive(at: time) else { return 1 }
        let slow = Tuning.SlowMotion.speed
        let elapsed = time - startTime - Tuning.SlowMotion.holdDuration
        guard elapsed > 0, Tuning.SlowMotion.rampDuration > 0 else { return slow }
        let progress = CGFloat(elapsed / Tuning.SlowMotion.rampDuration).clamped(to: 0...1)
        return slow + (1 - slow) * progress
    }
}
