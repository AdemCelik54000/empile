import CoreGraphics
import Foundation

/// Tells the camera to peek a little to the side when the finger stays at the very edge of the screen.
/// Once it has stayed there a moment, the push rises smoothly to 1 (or -1 towards the left) and stays there
/// until the piece is let go, even if the finger comes back to the middle; then it falls back to 0.
/// Staying at the opposite edge a moment switches sides.
struct EdgeNudge: Sendable {
    /// How close to the screen side the finger must be to count as at the edge.
    let edgeWidth: CGFloat
    /// How long the finger must stay there first, so a finger passing by never moves the camera.
    let dwell: TimeInterval
    /// How quickly the push follows its target.
    let sharpness: Double
    /// -1 towards the left, 1 towards the right, 0 at rest.
    private(set) var push: CGFloat = 0
    /// The side the finger is at the edge of right now, 0 when it is not at an edge.
    private var side: CGFloat = 0
    private var waited: TimeInterval = 0
    /// The side the camera has peeked to, kept until the piece is let go.
    private var held: CGFloat = 0

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
        guard let fingerX else {
            side = 0
            waited = 0
            held = 0
            push += (0 - push) * Smoothing.blend(sharpness: sharpness, deltaTime: deltaTime)
            return push
        }
        let current: CGFloat = fingerX <= edgeWidth ? -1 : fingerX >= width - edgeWidth ? 1 : 0
        if current != side {
            side = current
            waited = 0
        } else if current != 0 {
            waited += max(0, deltaTime)
        }
        if current != 0 && waited >= dwell {
            held = current
        }
        push += (held - push) * Smoothing.blend(sharpness: sharpness, deltaTime: deltaTime)
        return push
    }
}
