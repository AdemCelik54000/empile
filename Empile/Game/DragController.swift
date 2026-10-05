import SpriteKit

/// Follows the finger with the held block: offset above the fingertip, smoothed,
/// kept above the tower, and released with part of the finger's horizontal speed.
/// Positions come in view coordinates, from the SwiftUI gesture on the hand.
@MainActor
final class DragController {
    struct Release {
        let block: BlockNode
        let velocity: CGVector
    }

    private(set) var block: BlockNode?
    /// Kept in view coordinates, so the block stays under the finger while the camera moves.
    /// Where the finger is, in view coordinates.
    private(set) var fingerInView = CGPoint.zero
    private var tracker = VelocityTracker(
        window: Tuning.Drag.velocityWindow,
        capacity: Tuning.Drag.velocitySampleCapacity
    )

    var isDragging: Bool { block != nil }

    func begin(_ block: BlockNode, at viewPoint: CGPoint, time: TimeInterval, in scene: SKScene, zone: HoldZone,
               cameraScale: CGFloat) {
        self.block = block
        tracker.reset()
        track(to: viewPoint, time: time)
        block.position = target(for: block, in: scene, zone: zone, cameraScale: cameraScale)
    }

    func track(to viewPoint: CGPoint, time: TimeInterval) {
        fingerInView = viewPoint
        tracker.add(viewPoint, at: time)
    }

    /// Call once per frame, after the camera moved.
    func update(in scene: SKScene, zone: HoldZone, cameraScale: CGFloat, deltaTime: TimeInterval) {
        guard let block else { return }
        block.position = Smoothing.approach(
            block.position,
            to: target(for: block, in: scene, zone: zone, cameraScale: cameraScale),
            sharpness: Tuning.Drag.followSharpness,
            deltaTime: deltaTime
        )
    }

    func release(at viewPoint: CGPoint, time: TimeInterval, cameraScale: CGFloat) -> Release? {
        guard let block else { return nil }
        track(to: viewPoint, time: time)
        self.block = nil
        let fingerSpeed = tracker.velocity.dx * cameraScale
        let limit = Tuning.Drag.maxInheritedSpeed
        let inherited = (fingerSpeed * Tuning.Drag.inheritedVelocityFactor).clamped(to: -limit...limit)
        return Release(block: block, velocity: CGVector(dx: inherited, dy: 0))
    }

    func cancel() -> BlockNode? {
        defer { block = nil }
        return block
    }

    private func target(for block: BlockNode, in scene: SKScene, zone: HoldZone, cameraScale: CGFloat) -> CGPoint {
        let finger = scene.convertPoint(fromView: fingerInView)
        let lift = Tuning.Drag.fingerGap * cameraScale + block.footprint.height / 2
        return zone.clamp(CGPoint(x: finger.x, y: finger.y + lift), size: block.footprint)
    }
}
