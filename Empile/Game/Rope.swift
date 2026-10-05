import SpriteKit

/// The rope of the "pull" power: tied to a piece of the tower where the finger caught it, it pulls that point
/// towards the finger. The further the finger, the harder the pull, and the thinner the rope.
@MainActor
final class Rope {
    let node = SKNode()
    private let line = SKShapeNode()
    private let knot = SKShapeNode(circleOfRadius: 4)
    private(set) var block: BlockNode?
    /// Where the rope is tied, in the piece's own coordinates.
    private var localAnchor = CGPoint.zero
    private var fingerInView = CGPoint.zero

    var isHolding: Bool { block != nil }

    init() {
        node.zPosition = Layer.rope
        node.isHidden = true
        line.lineCap = .round
        knot.lineWidth = 0
        node.addChild(line)
        node.addChild(knot)
    }

    func refresh(using textures: TextureFactory) {
        let color = textures.resolve(Palette.accent)
        line.strokeColor = color
        knot.fillColor = color
    }

    /// Ties the rope to `block` at `point` (scene coordinates).
    func attach(to block: BlockNode, at point: CGPoint, fingerInView: CGPoint) {
        self.block = block
        localAnchor = block.convert(point, from: node.scene ?? block)
        self.fingerInView = fingerInView
        block.wake()
        node.isHidden = false
    }

    func move(fingerInView: CGPoint) {
        self.fingerInView = fingerInView
    }

    func release() {
        block = nil
        node.isHidden = true
    }

    /// Call before physics steps: pulls the tied point towards the finger, like a stiff spring with a little
    /// damping. Lets go by itself when the piece is gone or frozen out of sight.
    func pull(in scene: SKScene, deltaTime: TimeInterval) {
        guard let block else { return }
        guard block.parent != nil, !block.isFrozen, !block.hasFallenOff, let body = block.physicsBody else {
            release()
            return
        }
        let anchor = scene.convert(localAnchor, from: block)
        let finger = scene.convertPoint(fromView: fingerInView)
        let arm = CGVector(dx: anchor.x - block.position.x, dy: anchor.y - block.position.y)
        // Speed of the tied point itself: the piece's speed plus its spin around its center.
        let speed = CGVector(dx: body.velocity.dx - body.angularVelocity * arm.dy,
                             dy: body.velocity.dy + body.angularVelocity * arm.dx)
        let tuning = Tuning.Abilities.self
        var acceleration = CGVector(
            dx: tuning.pullStiffness * (finger.x - anchor.x) - tuning.pullDamping * speed.dx,
            dy: tuning.pullStiffness * (finger.y - anchor.y) - tuning.pullDamping * speed.dy
        )
        let magnitude = hypot(acceleration.dx, acceleration.dy)
        if magnitude > tuning.maxPullAcceleration {
            let shrink = tuning.maxPullAcceleration / magnitude
            acceleration = CGVector(dx: acceleration.dx * shrink, dy: acceleration.dy * shrink)
        }
        // Impulses are in kilograms × points per second: the push over this frame is mass × acceleration × time.
        let perAcceleration = body.mass * CGFloat(deltaTime)
        block.wake()
        body.applyImpulse(CGVector(dx: acceleration.dx * perAcceleration, dy: acceleration.dy * perAcceleration),
                          at: anchor)
        let speedNow = hypot(body.velocity.dx, body.velocity.dy)
        if speedNow > tuning.maxPullSpeed {
            let shrink = tuning.maxPullSpeed / speedNow
            body.velocity = CGVector(dx: body.velocity.dx * shrink, dy: body.velocity.dy * shrink)
        }
    }

    /// Call after physics: draws the rope from the piece to the finger.
    func draw(in scene: SKScene, cameraScale: CGFloat) {
        guard let block else { return }
        let anchor = scene.convert(localAnchor, from: block)
        let finger = scene.convertPoint(fromView: fingerInView)
        let length = hypot(finger.x - anchor.x, finger.y - anchor.y) / max(cameraScale, 0.01)
        let tuning = Tuning.Abilities.self
        let width = max(tuning.ropeMinWidth, tuning.ropeWidth - length / tuning.ropeThinningLength)
        let path = CGMutablePath()
        path.move(to: anchor)
        path.addLine(to: finger)
        line.path = path
        line.lineWidth = width * cameraScale
        knot.position = anchor
        knot.setScale(cameraScale)
    }
}
