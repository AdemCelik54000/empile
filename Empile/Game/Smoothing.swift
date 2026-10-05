import CoreGraphics
import Foundation

/// Exponential smoothing that moves the same way at 60 Hz and 120 Hz:
/// two half-length frames cover exactly the same distance as one full-length frame.
enum Smoothing {
    /// Share of the remaining distance to cover during `deltaTime`.
    static func blend(sharpness: Double, deltaTime: TimeInterval) -> CGFloat {
        CGFloat(1 - exp(-sharpness * deltaTime))
    }

    static func approach(
        _ point: CGPoint,
        to target: CGPoint,
        sharpness: Double,
        deltaTime: TimeInterval
    ) -> CGPoint {
        let blend = blend(sharpness: sharpness, deltaTime: deltaTime)
        return CGPoint(x: point.x + (target.x - point.x) * blend, y: point.y + (target.y - point.y) * blend)
    }
}
