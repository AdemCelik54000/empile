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
    /// The frost over a piece caught by the freeze power: its own picture, tinted ice blue.
    private var frost: SKSpriteNode?
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

    /// The shape once a quarter turn still in progress is over.
    var finalShape: BlockShape { pendingTurn?.shape ?? shape }

    var isSettled: Bool { frozenTop != nil || settleTimer.isSettled }
    var isFrozen: Bool { frozenTop != nil }

    func refreshTexture(using textures: TextureFactory) {
        sprite.texture = textures.block(definition.kind, shape: shape, variant: variant, isSpent: isSpent)
        frost?.texture = sprite.texture
        frost?.setValue(SKAttributeValue(vectorFloat4: textures.resolve(Palette.ice).vector), forAttribute: "a_color")
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

    /// One side of one square of the piece, in the piece's own frame.
    struct SquareFace: Hashable {
        let cell: GridCell
        /// Which way it looks: up (0, 1), down (0, -1), left (-1, 0) or right (1, 0).
        let dx: Int
        let dy: Int
    }

    /// The sides of its squares that look up as the piece stands now and do not touch another of its squares:
    /// where ice settles.
    var upwardFaces: [SquareFace] {
        let cosine = cos(zRotation)
        let sine = sin(zRotation)
        return shape.cells.flatMap { cell in
            [(0, 1), (0, -1), (-1, 0), (1, 0)].compactMap { dx, dy -> SquareFace? in
                let up = CGFloat(dx) * sine + CGFloat(dy) * cosine
                guard up > 0.6, !shape.contains(column: cell.column + dx, row: cell.row + dy) else { return nil }
                return SquareFace(cell: cell, dx: dx, dy: dy)
            }
        }
    }

    /// Whether a point of the scene lies on one of the piece's squares.
    func covers(_ point: CGPoint) -> Bool {
        guard let parent else { return false }
        let local = convert(point, from: parent)
        let unit = Tuning.World.unit
        let column = Int((local.x / unit + CGFloat(shape.columns) / 2).rounded(.down))
        let row = Int((local.y / unit + CGFloat(shape.rows) / 2).rounded(.down))
        return shape.contains(column: column, row: row)
    }

    /// The middle of the square just past `face`, in the piece's frame: whatever is there covers the face.
    func pointPast(_ face: SquareFace) -> CGPoint {
        let center = shape.offset(of: face.cell, unit: Tuning.World.unit)
        return CGPoint(x: center.x + CGFloat(face.dx) * Tuning.World.unit,
                       y: center.y + CGFloat(face.dy) * Tuning.World.unit)
    }

    /// Frozen by the power, wherever it is: it turns to ice with frost crystals over it, flashes white, pops a
    /// little, and ice settles on `cappedFaces`, running down the sides.
    /// - Parameter delay: The freeze climbs the tower as a wave: higher pieces wait a little.
    func iceOver(after delay: TimeInterval, cappedFaces: [SquareFace], using textures: TextureFactory) {
        freeze()
        markLanded()
        guard frost == nil else { return }
        let tuning = Tuning.Freeze.self
        let frost = SKSpriteNode(texture: sprite.texture, size: sprite.size)
        frost.shader = Self.frostShader(using: textures)
        frost.setValue(SKAttributeValue(vectorFloat4: textures.resolve(Palette.ice).vector), forAttribute: "a_color")
        frost.setValue(SKAttributeValue(vectorFloat2: vector_float2(Float(sprite.size.width / tuning.patternSize),
                                                                    Float(sprite.size.height / tuning.patternSize))),
                       forAttribute: "a_tiles")
        frost.alpha = 0
        // Just above the piece, but under the next pieces dropped onto it.
        frost.zPosition = Layer.dropStep * 0.2
        sprite.addChild(frost)
        self.frost = frost
        let flash = silhouette(.white)
        flash.zPosition = Layer.dropStep * 0.4
        sprite.addChild(flash)
        frost.run(.sequence([.wait(forDuration: delay), .fadeAlpha(to: tuning.frostOpacity, duration: tuning.frostDuration)]))
        flash.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: tuning.flashOpacity, duration: tuning.frostDuration * 0.3),
            .fadeOut(withDuration: tuning.frostDuration * 1.4),
            .removeFromParent(),
        ]))
        if let cap = iceCap(on: cappedFaces, using: textures) {
            cap.alpha = 0
            cap.zPosition = Layer.dropStep * 0.6
            sprite.addChild(cap)
            cap.run(.sequence([.wait(forDuration: delay + tuning.frostDuration * 0.5),
                               .fadeIn(withDuration: tuning.capFadeIn)]))
        }
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.squash(by: tuning.pop) }]))
    }

    /// Ice that has settled on `faces`: a white layer, a little domed, its lower edge wavy with small icicles, running
    /// down the sides of the piece where nothing else of it is.
    private func iceCap(on faces: [SquareFace], using textures: TextureFactory) -> SKShapeNode? {
        guard !faces.isEmpty else { return nil }
        let tuning = Tuning.Freeze.self
        let unit = Tuning.World.unit
        let half = unit / 2
        let thickness = tuning.capThickness * unit
        var generator = SeededGenerator(seed: UInt64(cardID) &* 7919 &+ 17)
        var outline: CGPath?
        for face in faces {
            // Drawn with the face along x and looking towards +y, then turned and moved onto the face.
            let angle = atan2(CGFloat(face.dy), CGFloat(face.dx)) - .pi / 2
            func isOpen(towards side: CGFloat) -> Bool {
                let dx = Int((cos(angle) * side).rounded())
                let dy = Int((sin(angle) * side).rounded())
                return !shape.contains(column: face.cell.column + dx, row: face.cell.row + dy)
            }
            let leftOpen = isOpen(towards: -1)
            let rightOpen = isOpen(towards: 1)
            let leftOver = leftOpen ? thickness * 0.55 : 1.5
            let rightOver = rightOpen ? thickness * 0.55 : 1.5
            var points = [
                CGPoint(x: -half - leftOver, y: thickness * 0.3),
                CGPoint(x: -half * 0.3, y: thickness * 0.55),
                CGPoint(x: half * 0.3, y: thickness * 0.5),
                CGPoint(x: half + rightOver, y: thickness * 0.3),
            ]
            if rightOpen {
                let drip = CGFloat.random(in: tuning.sideDrip, using: &generator) * unit
                points += [CGPoint(x: half + rightOver, y: -drip + thickness * 0.6),
                           CGPoint(x: half + rightOver * 0.4, y: -drip),
                           CGPoint(x: half - thickness * 0.15, y: -drip + thickness * 0.7),
                           CGPoint(x: half - thickness * 0.2, y: -thickness * 0.7)]
            } else {
                points.append(CGPoint(x: half + rightOver, y: -thickness * 0.5))
            }
            for step in 1..<6 {
                points.append(CGPoint(x: half - unit * CGFloat(step) / 6,
                                      y: -thickness * .random(in: 0.4...0.9, using: &generator)))
            }
            if leftOpen {
                let drip = CGFloat.random(in: tuning.sideDrip, using: &generator) * unit
                points += [CGPoint(x: -half + thickness * 0.2, y: -thickness * 0.7),
                           CGPoint(x: -half + thickness * 0.15, y: -drip + thickness * 0.7),
                           CGPoint(x: -half - leftOver * 0.4, y: -drip),
                           CGPoint(x: -half - leftOver, y: -drip + thickness * 0.6)]
            } else {
                points.append(CGPoint(x: -half - leftOver, y: -thickness * 0.5))
            }
            let layer = CGMutablePath()
            layer.addPath(Self.smoothOutline(points))
            for _ in 0..<Int.random(in: 0...tuning.icicles, using: &generator) {
                let x = CGFloat.random(in: -half * 0.7...half * 0.7, using: &generator)
                let width = thickness * .random(in: 0.35...0.6, using: &generator)
                let length = CGFloat.random(in: tuning.icicleLength, using: &generator) * unit
                layer.move(to: CGPoint(x: x - width / 2, y: -thickness * 0.4))
                layer.addLine(to: CGPoint(x: x + width / 2, y: -thickness * 0.4))
                layer.addLine(to: CGPoint(x: x, y: -thickness * 0.4 - length))
                layer.closeSubpath()
            }
            let center = shape.offset(of: face.cell, unit: unit)
            var placement = CGAffineTransform(translationX: center.x + CGFloat(face.dx) * half,
                                              y: center.y + CGFloat(face.dy) * half).rotated(by: angle)
            guard let placed = layer.copy(using: &placement) else { continue }
            outline = outline.map { $0.union(placed) } ?? placed
        }
        guard let outline else { return nil }
        let cap = SKShapeNode(path: outline)
        cap.fillColor = UIColor(red: 0.93, green: 0.98, blue: 1, alpha: 1)
        cap.strokeColor = textures.resolve(Palette.ice)
        cap.lineWidth = 1.5
        cap.lineJoin = .round
        return cap
    }

    /// A closed, rounded outline passing near `points`: each corner becomes a soft curve.
    private static func smoothOutline(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 2 else { return path }
        func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: middle(points[points.count - 1], points[0]))
        for index in points.indices {
            path.addQuadCurve(to: middle(points[index], points[(index + 1) % points.count]), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    /// The piece in one flat color, its soft shadow left out, starting invisible. SpriteKit's own tint multiplies
    /// the texture, so a light color over a dark piece would not show.
    private func silhouette(_ color: UIColor) -> SKSpriteNode {
        let node = SKSpriteNode(texture: sprite.texture, size: sprite.size)
        node.shader = Self.silhouetteShader
        node.setValue(SKAttributeValue(vectorFloat4: color.vector), forAttribute: "a_color")
        node.alpha = 0
        return node
    }

    private static var sharedFrostShader: SKShader?

    /// Ice over the opaque part of the piece: its color, frost crystals in white, and a shine towards the top.
    private static func frostShader(using textures: TextureFactory) -> SKShader {
        if let sharedFrostShader { return sharedFrostShader }
        let shader = SKShader(source: """
            void main() {
                float body = smoothstep(0.55, 0.95, texture2D(u_texture, v_tex_coord).a) * v_color_mix.a;
                float crystals = texture2D(u_frost, fract(v_tex_coord * a_tiles)).a;
                float top = smoothstep(0.45, 1.0, v_tex_coord.y);
                vec3 color = mix(a_color.rgb, vec3(1.0), clamp(crystals * 0.9 + top * 0.35, 0.0, 1.0));
                float alpha = body * clamp(0.55 + crystals * 0.4 + top * 0.15, 0.0, 1.0);
                gl_FragColor = vec4(color * alpha, alpha);
            }
            """)
        shader.uniforms = [SKUniform(name: "u_frost", texture: textures.frostPattern())]
        shader.attributes = [SKAttribute(name: "a_color", type: .vectorFloat4),
                             SKAttribute(name: "a_tiles", type: .vectorFloat2)]
        sharedFrostShader = shader
        return shader
    }

    /// Paints the opaque part of the texture in `a_color`; the node's alpha still fades it.
    private static let silhouetteShader: SKShader = {
        let shader = SKShader(source: """
            void main() {
                float body = smoothstep(0.55, 0.95, texture2D(u_texture, v_tex_coord).a) * v_color_mix.a;
                gl_FragColor = vec4(a_color.rgb * body, body);
            }
            """)
        shader.attributes = [SKAttribute(name: "a_color", type: .vectorFloat4)]
        return shader
    }()

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
        frost?.texture = sprite.texture
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

private extension UIColor {
    /// Red, green, blue and alpha, for a shader.
    var vector: vector_float4 {
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return vector_float4(Float(red), Float(green), Float(blue), Float(alpha))
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
