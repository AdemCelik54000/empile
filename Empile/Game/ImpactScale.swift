import CoreGraphics
import Foundation

/// Turns a physics impulse into an impact strength from 0 to 1, or `nil` when it is too soft to notice.
struct ImpactScale: Sendable {
    /// Impulse (`SKPhysicsContact.collisionImpulse`) below which an impact is ignored.
    let threshold: CGFloat
    /// Impulse at which an impact reaches full strength.
    let full: CGFloat
    /// Below 1, soft impacts are boosted; above 1, they are toned down.
    let curve: CGFloat

    func strength(for impulse: CGFloat) -> CGFloat? {
        guard impulse >= threshold, full > threshold else { return nil }
        let linear = ((impulse - threshold) / (full - threshold)).clamped(to: 0...1)
        return pow(linear, curve)
    }
}

enum ImpactPitch {
    /// Bigger blocks sound lower: a fixed number of semitones each time the area doubles.
    static func semitones(forArea area: Int) -> Float {
        guard area > 0 else { return 0 }
        let ratio = CGFloat(area) / Tuning.Impact.referenceArea
        return Tuning.Sound.semitonesPerSizeDoubling * Float(log2(ratio))
    }
}
