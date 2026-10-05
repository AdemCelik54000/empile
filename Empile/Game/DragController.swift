import SpriteKit

/// Follows the finger with the held block: right above the fingertip sideways, at the height it was taken from
/// (then following the finger up and down), smoothed, kept above the tower, and released with part of the
/// finger's horizontal speed. Positions come in view coordinates, from the SwiftUI gesture on the world.
@MainActor
final class DragController {
    struct Release {
        let block: BlockNode
        let velocity: CGVector
    }

    private(set) var block: BlockNode?
    /// Where the finger is, in view coordinates, so the block stays with it while the camera moves.
    private(set) var fingerInView = CGPoint.zero
    /// How far above its usual spot over the finger the block is held, in screen points: the waiting piece
    /// keeps its height when a finger takes it, instead of diving down to the finger.
    private var heightOffset: CGFloat = 0
    private var tracker = VelocityTracker(
        window: Tuning.Drag.velocityWindow,
        capacity: Tuning.Drag.velocitySampleCapacity
    )

    var isDragging: Bool { block != nil }

    /// - Parameter snaps: Puts the block under the finger at once; otherwise it glides there.
    func begin(_ block: BlockNode, at viewPoint: CGPoint, time: TimeInterval, in scene: SKScene, zone: HoldZone,
               cameraScale: CGFloat, snaps: Bool) {
        self.block = block
        tracker.reset()
        track(to: viewPoint, time: time)
        heightOffset = 0
        if !snaps {
            let usual = target(for: block, in: scene, zone: zone, cameraScale: cameraScale)
            heightOffset = (block.position.y - usual.y) / max(cameraScale, 0.01)
        }
        if snaps {
            block.position = target(for: block, in: scene, zone: zone, cameraScale: cameraScale)
        }
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

    /// Lets go of the block right under the finger, even if it had not caught up yet (a quick tap on a side
    /// drops it on that side, not where it was gliding from).
    func release(at viewPoint: CGPoint, time: TimeInterval, in scene: SKScene, zone: HoldZone,
                 cameraScale: CGFloat) -> Release? {
        guard let block else { return nil }
        track(to: viewPoint, time: time)
        block.position = target(for: block, in: scene, zone: zone, cameraScale: cameraScale)
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
        let lift = (Tuning.Drag.fingerGap + heightOffset) * cameraScale + block.footprint.height / 2
        return zone.clamp(CGPoint(x: finger.x, y: finger.y + lift), size: block.footprint)
    }
}
