import CoreGraphics
import Foundation

/// Tells the camera to peek a little to the side when the finger stays at the very edge of the screen.
/// Once it has stayed there a moment, the push rises smoothly to 1 (or -1 towards the left); when the finger
/// moves away or lets go, it falls back to 0.
struct EdgeNudge: Sendable {
    /// How close to the screen side the finger must be to count as at the edge.
    let edgeWidth: CGFloat
    /// How long the finger must stay there first, so a finger passing by never moves the camera.
    let dwell: TimeInterval
    /// How quickly the push follows its target.
    let sharpness: Double
    /// -1 towards the left, 1 towards the right, 0 at rest.
    private(set) var push: CGFloat = 0
    private var side: CGFloat = 0
    private var waited: TimeInterval = 0

    init(edgeWidth: CGFloat, dwell: TimeInterval, sharpness: Double) {
        self.edgeWidth = edgeWidth
        self.dwell = dwell
        self.sharpness = sharpness
    }

    /// - Parameters:
    ///   - fingerX: Where the finger is across the screen, `nil` when nothing is held.
    ///   - width: Screen width, in the same units.
    @discardableResult
    mutating func update(fingerX: CGFloat?, width: CGFloat, deltaTime: TimeInterval) -> CGFloat {
        let current: CGFloat = if let fingerX {
            fingerX <= edgeWidth ? -1 : fingerX >= width - edgeWidth ? 1 : 0
        } else {
            0
        }
        if current != side {
            side = current
            waited = 0
        } else if current != 0 {
            waited += max(0, deltaTime)
        }
        let target = current != 0 && waited >= dwell ? current : 0
        push += (target - push) * Smoothing.blend(sharpness: sharpness, deltaTime: deltaTime)
        return push
    }
}
