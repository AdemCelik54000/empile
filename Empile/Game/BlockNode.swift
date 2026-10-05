import SpriteKit

/// One block in the world: its picture, its physics body once dropped, and how long it has stayed still.
///
/// The physics body sits on this node; the picture hangs from a pivot at the bottom of the block.
/// Squashing scales only the pivot, so the visual effect never touches the physics.
final class BlockNode: SKNode {
    private struct PendingTurn {
        let shape: BlockShape
        let texture: SKTexture
    }

    private enum ActionKey {
        static let appear = "appear"
        static let turn = "turn"
        static let squash = "squash"
        static let flash = "flash"
    }

    /// The card this block came from; also its id in tower snapshots.
    let cardID: Card.ID
    let definition: BlockDefinition
    let variant: Int
    private(set) var shape: BlockShape
    /// A spring that has not fired yet.
    private(set) var isArmed: Bool
    /// Set once a block that had landed drops below the platform: it is on its way out.
    private(set) var hasFallenOff = false
    /// Order in which the block was dropped: the higher, the more recent.
    private(set) var dropOrder = 0
    /// False while the block is still in free fall after being dropped.
    private(set) var hasLanded = false
    /// Top of the block once it is frozen out of sight: it never moves again.
    private(set) var frozenTop: CGFloat?
    /// Its placement has been judged and its points counted.
    private(set) var isScored = false
    private let pivot = SKNode()
    private let sprite: SKSpriteNode
    private var settleTimer = SettleTimer(requiredDuration: Tuning.Physics.settleDuration)
    private var pendingTurn: PendingTurn?
    private var lastImpactTime = -TimeInterval.infinity

    init(card: Card, textures: TextureFactory) {
        cardID = card.id
        definition = card.definition
        shape = card.shape
        variant = card.id % Tuning.Look.textureVariants
        isArmed = card.definition.power == .bounceNextBlock
        sprite = SKSpriteNode(
            texture: textures.block(card.kind, shape: card.shape, variant: variant),
            size: TextureFactory.spriteSize(for: card.shape)
        )
        super.init()
        addChild(pivot)
        pivot.addChild(sprite)
        placePivot()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    /// Size of the block itself, without the shadow around the picture.
    var footprint: CGSize { shape.size(unit: Tuning.World.unit) }

    /// The piece where it stands now, for geometry and rules.
    var placement: PlacedShape {
        PlacedShape(shape: shape, center: position, rotation: zRotation, unit: Tuning.World.unit)
    }

    var topY: CGFloat { frozenTop ?? placement.topY }

    var isSettled: Bool { frozenTop != nil || settleTimer.isSettled }
    var isFrozen: Bool { frozenTop != nil }

    func refreshTexture(using textures: TextureFactory) {
        sprite.texture = textures.block(definition.kind, shape: shape, variant: variant, isSpent: isSpent)
        pendingTurn = pendingTurn.map {
            PendingTurn(shape: $0.shape, texture: textures.block(definition.kind, shape: $0.shape, variant: variant))
        }
    }

    // MARK: - Held

    func appear() {
        setScale(Tuning.Drag.appearScale)
        let grow = SKAction.scale(to: 1, duration: Tuning.Drag.appearDuration)
        grow.timingFunction = Easing.backOut
        run(grow, withKey: ActionKey.appear)
    }

    /// Spins a quarter turn, then swaps width and height so the lighting stays on top.
    /// - Returns: `false` for a square, which looks the same after a turn.
    func turnQuarter(using textures: TextureFactory) -> Bool {
        completeTurn()
        guard !shape.isTurnInvariant else { return false }
        let turned = shape.quarterTurned
        pendingTurn = PendingTurn(shape: turned, texture: textures.block(definition.kind, shape: turned, variant: variant))
        let spin = SKAction.rotate(byAngle: -.pi / 2, duration: Tuning.Drag.turnDuration)
        spin.timingMode = .easeOut
        run(.sequence([spin, .run { [weak self] in self?.completeTurn() }]), withKey: ActionKey.turn)
        return true
    }

    /// Ends a turn still in progress right away.
    func completeTurn() {
        guard let pendingTurn else { return }
        self.pendingTurn = nil
        removeAction(forKey: ActionKey.turn)
        zRotation = 0
        shape = pendingTurn.shape
        sprite.texture = pendingTurn.texture
        sprite.size = TextureFactory.spriteSize(for: shape)
        placePivot()
    }

    /// Shrinks away when a drag is cancelled.
    func dismiss() {
        removeAllActions()
        let duration = Tuning.Drag.dismissDuration
        run(.sequence([
            .group([.scale(to: Tuning.Drag.appearScale, duration: duration), .fadeOut(withDuration: duration)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Dropped

    /// Hands the block to physics.
    func drop(velocity: CGVector) {
        completeTurn()
        removeAction(forKey: ActionKey.appear)
        setScale(1)
        let body = makeBody()
        body.categoryBitMask = PhysicsCategory.block
        body.collisionBitMask = PhysicsCategory.block | PhysicsCategory.platform
        body.contactTestBitMask = PhysicsCategory.block | PhysicsCategory.platform
        physicsBody = body
        body.velocity = velocity
        // Let go: the piece stretches a little as it starts to fall.
        squash(by: -Tuning.Juice.dropStretch)
    }

    func markDropped(order: Int) {
        dropOrder = order
        zPosition = Layer.droppedBlock(order: order)
    }

    func markLanded() {
        hasLanded = true
    }

    func markScored() {
        isScored = true
    }

    /// Lights up white for a moment and pops a little: a perfect placement.
    func flash() {
        let half = Tuning.Celebration.flashDuration / 2
        sprite.color = .white
        sprite.run(.sequence([
            .colorize(withColorBlendFactor: Tuning.Celebration.flashStrength, duration: half * 0.3),
            .colorize(withColorBlendFactor: 0, duration: half * 1.7),
        ]), withKey: ActionKey.flash)
        squash(by: -Tuning.Celebration.flashPop)
    }

    /// Called once per frame after physics: updates settling and collision precision.
    func recordMotion(deltaTime: TimeInterval) {
        guard let body = physicsBody else { return }
        let speed = hypot(body.velocity.dx, body.velocity.dy)
        let isCalm = Tuning.Physics.calm.isCalm(speed: speed, angularSpeed: body.angularVelocity)
        settleTimer.record(isCalm: isCalm, deltaTime: deltaTime)
        let needsPrecision = speed > Tuning.Physics.preciseCollisionSpeed
        if body.usesPreciseCollisionDetection != needsPrecision {
            body.usesPreciseCollisionDetection = needsPrecision
        }
    }

    func rest() {
        guard !isFrozen else { return }
        physicsBody?.isResting = true
    }

    func wake() {
        guard !isFrozen else { return }
        physicsBody?.isResting = false
    }

    /// Pins the block where it stands for good: it has left the screen at the bottom and should no longer
    /// shift under the weight of the tower above.
    func freeze() {
        guard frozenTop == nil, let body = physicsBody else { return }
        frozenTop = placement.topY
        body.velocity = .zero
        body.angularVelocity = 0
        body.isDynamic = false
    }

    func markFellOff() {
        hasFallenOff = true
    }

    /// Fades out once the block has fallen off the platform.
    func vanish() {
        run(.sequence([.fadeOut(withDuration: Tuning.Look.vanishDuration), .removeFromParent()]))
    }

    /// One polygon per row run of the piece, so it collides with its real shape, notches included.
    /// The outer corners are cut off: like soft jelly, a piece slides past edges and into gaps instead of
    /// catching on them.
    private func makeBody() -> SKPhysicsBody {
        let unit = Tuning.World.unit
        let inset = Tuning.Physics.bodyInset
        let chamfer = Tuning.Physics.bodyChamfer
        let shape = shape
        let parts = shape.horizontalRuns.map { run -> SKPhysicsBody in
            let lastColumn = run.firstColumn + run.length - 1
            let first = shape.offset(of: GridCell(column: run.firstColumn, row: run.row), unit: unit)
            let minX = first.x - unit / 2 + inset
            let maxX = minX + CGFloat(run.length) * unit - 2 * inset
            let minY = first.y - unit / 2 + inset
            let maxY = first.y + unit / 2 - inset
            // A corner is cut only where it is a corner of the whole piece, not where two rows meet.
            func cut(column: Int, rowStep: Int) -> CGFloat {
                shape.contains(column: column, row: run.row + rowStep) ? 0 : chamfer
            }
            let bottomLeft = cut(column: run.firstColumn, rowStep: -1)
            let bottomRight = cut(column: lastColumn, rowStep: -1)
            let topRight = cut(column: lastColumn, rowStep: 1)
            let topLeft = cut(column: run.firstColumn, rowStep: 1)
            // Counterclockwise; an uncut corner gives the same point twice, which the engine rejects.
            let corners = [
                CGPoint(x: minX + bottomLeft, y: minY), CGPoint(x: maxX - bottomRight, y: minY),
                CGPoint(x: maxX, y: minY + bottomRight), CGPoint(x: maxX, y: maxY - topRight),
                CGPoint(x: maxX - topRight, y: maxY), CGPoint(x: minX + topLeft, y: maxY),
                CGPoint(x: minX, y: maxY - topLeft), CGPoint(x: minX, y: minY + bottomLeft),
            ]
            var outline: [CGPoint] = []
            for corner in corners where corner != outline.last && corner != outline.first {
                outline.append(corner)
            }
            let path = CGMutablePath()
            path.addLines(between: outline)
            path.closeSubpath()
            let part = SKPhysicsBody(polygonFrom: path)
            part.apply(definition.material)
            return part
        }
        let body = parts.count == 1 ? parts[0] : SKPhysicsBody(bodies: parts)
        body.apply(definition.material)
        return body
    }

    // MARK: - Powers

    /// A spring is spent once it has fired: it looks flattened and never bounces again.
    var isSpent: Bool { definition.power == .bounceNextBlock && !isArmed }

    func spend(using textures: TextureFactory) {
        guard isArmed else { return }
        isArmed = false
        sprite.texture = textures.block(definition.kind, shape: shape, variant: variant, isSpent: true)
    }

    // MARK: - Impacts

    /// Whether this impact should be felt. A block that was just hit stays quiet for a moment,
    /// so one landing never rattles.
    func acceptsImpact(at time: TimeInterval) -> Bool {
        guard time - lastImpactTime >= Tuning.Impact.cooldown else { return false }
        lastImpactTime = time
        return true
    }

    /// Flattens against what it hit, then wobbles back like jelly, each swing smaller than the last.
    /// Only the picture moves: the physics body keeps its shape.
    /// - Parameter amount: 0.1 flattens the block by 10 %; a negative amount stretches it instead.
    func squash(by amount: CGFloat) {
        guard amount != 0 else { return }
        pivot.removeAction(forKey: ActionKey.squash)
        let juice = Tuning.Juice.self
        var swings = [deform(by: amount, duration: juice.squashCompressDuration)]
        var swing = amount
        for _ in 0..<juice.wobbleCount {
            swing *= -juice.wobbleDecay
            swings.append(deform(by: swing, duration: juice.wobbleHalfPeriod))
        }
        swings.append(deform(by: 0, duration: juice.wobbleHalfPeriod))
        pivot.run(.sequence(swings), withKey: ActionKey.squash)
    }

    /// Flattened by `amount` and widened to keep the volume.
    private func deform(by amount: CGFloat, duration: TimeInterval) -> SKAction {
        let action = SKAction.scaleX(to: 1 + amount * Tuning.Juice.squashWidening, y: 1 - amount, duration: duration)
        action.timingMode = .easeInEaseOut
        return action
    }

    /// The picture hangs from the bottom edge, so a squash flattens it onto what it landed on.
    private func placePivot() {
        let halfHeight = footprint.height / 2
        pivot.position = CGPoint(x: 0, y: -halfHeight)
        sprite.position = CGPoint(x: 0, y: halfHeight)
    }
}

extension SKPhysicsBody {
    func apply(_ material: Material) {
        density = material.density
        friction = material.friction
        restitution = material.restitution
        linearDamping = material.linearDamping
        angularDamping = material.angularDamping
    }
}
