import SpriteKit

/// Piece powers that act on the physics: springs launching the piece that lands on them, and glass shattering.
///
/// Contacts are collected during the physics step and acted on once it is over, since the physics world
/// cannot change while it is being stepped.
@MainActor
final class PowerEffects {
    private struct Launch {
        let spring: BlockNode
        let block: BlockNode
        /// Which way the spring pushes: along the contact, so a level spring sends the piece straight up.
        let direction: CGVector
    }

    let node = SKNode()
    private let haptics: HapticsManager
    private let audio: AudioManager
    private var pendingLaunches: [Launch] = []
    private var shardTexture: SKTexture?
    private var shardColor = UIColor.white
    private var flakeTexture: SKTexture?
    private var iceColor = UIColor.cyan

    init(haptics: HapticsManager, audio: AudioManager) {
        self.haptics = haptics
        self.audio = audio
        node.zPosition = Layer.dust
    }

    func refresh(using textures: TextureFactory) {
        shardTexture = textures.shard(size: Tuning.Powers.shardSize)
        shardColor = textures.resolve(Palette.shard)
        flakeTexture = textures.snowflake(size: Tuning.Freeze.snowSize)
        iceColor = textures.resolve(Palette.ice)
    }

    /// Call from the physics contact delegate: arms a launch when a piece comes down on an unfired spring.
    func record(_ contact: SKPhysicsContact) {
        guard let first = contact.bodyA.node as? BlockNode,
              let second = contact.bodyB.node as? BlockNode,
              abs(contact.contactNormal.dy) >= Tuning.Powers.springContactVerticality
        else { return }
        let normal = contact.contactNormal
        if first.isArmed, second.position.y > first.position.y {
            pendingLaunches.append(Launch(spring: first, block: second, direction: Self.upward(normal)))
        } else if second.isArmed, first.position.y > second.position.y {
            pendingLaunches.append(Launch(spring: second, block: first, direction: Self.upward(normal)))
        }
    }

    /// The contact normal, flipped to point up and made unit length.
    private static func upward(_ normal: CGVector) -> CGVector {
        let sign: CGFloat = normal.dy < 0 ? -1 : 1
        let length = max(hypot(normal.dx, normal.dy), 0.001)
        return CGVector(dx: sign * normal.dx / length, dy: sign * normal.dy / length)
    }

    /// Call once per frame, after physics: fires the springs hit during the last step.
    func firePendingSprings(using textures: TextureFactory) {
        guard !pendingLaunches.isEmpty else { return }
        for launch in pendingLaunches where launch.spring.isArmed {
            launch.spring.spend(using: textures)
            launch.spring.squash(by: -Tuning.Powers.springSquash)
            if let body = launch.block.physicsBody {
                // The piece leaves along the spring, without the sideways speed or spin it landed with.
                let speed = max(body.velocity.dy, Tuning.Powers.springSpeed(forMass: body.mass))
                body.velocity = CGVector(dx: launch.direction.dx * speed, dy: launch.direction.dy * speed)
                body.angularVelocity = 0
            }
            audio.play(.springBoing, volume: Tuning.Sound.springVolume)
            haptics.play(Tuning.Haptics.springBounce, spacing: Tuning.Haptics.patternSpacing)
        }
        pendingLaunches.removeAll(keepingCapacity: true)
    }

    /// Bursts a glass piece into shards that fly out and fall. The caller removes the piece itself.
    func shatter(_ block: BlockNode) {
        let burst = SKEmitterNode()
        burst.particleTexture = shardTexture
        burst.particleColor = shardColor
        burst.particleColorBlendFactor = 1
        burst.position = block.position
        burst.zRotation = block.zRotation
        burst.particlePositionRange = CGVector(dx: block.footprint.width, dy: block.footprint.height)
        burst.numParticlesToEmit = Tuning.Powers.shardCount
        burst.particleBirthRate = Tuning.Juice.dustBirthRate
        burst.particleLifetime = Tuning.Powers.shardLifetime
        burst.particleLifetimeRange = Tuning.Powers.shardLifetime / 2
        burst.emissionAngleRange = 2 * .pi
        let speed = Tuning.Powers.shardSpeed
        burst.particleSpeed = (speed.lowerBound + speed.upperBound) / 2
        burst.particleSpeedRange = speed.upperBound - speed.lowerBound
        burst.yAcceleration = Tuning.World.gravity.dy * Tuning.World.pointsPerMeter
        burst.particleRotationRange = 2 * .pi
        burst.particleRotationSpeed = Tuning.Powers.shardSpin
        burst.particleAlphaSpeed = -1 / Tuning.Powers.shardLifetime
        burst.particleScaleRange = 0.5
        node.addChild(burst)
        let lifetime = TimeInterval(Tuning.Powers.shardLifetime * 1.5)
        burst.run(.sequence([.wait(forDuration: lifetime), .removeFromParent()]))
        audio.play(.glassShatter, volume: Tuning.Sound.shatterVolume)
        haptics.play(Tuning.Haptics.shatter, spacing: Tuning.Haptics.patternSpacing / 2)
    }

    /// The freeze power going off: the screen flashes ice blue, snow falls for a few seconds (while the interface
    /// shows frost on the edges of the screen), a ring of frost spreads from the top of the tower, and every frozen
    /// piece throws out snowflakes.
    /// - Parameter camera: The flash and the snow cover the screen, so they hang from the camera.
    func freeze(_ blocks: [BlockNode], top: CGPoint, camera: SKCameraNode, screenSize: CGSize, cameraScale: CGFloat) {
        let tuning = Tuning.Freeze.self
        let flash = SKSpriteNode(color: iceColor, size: screenSize)
        flash.blendMode = .add
        flash.alpha = tuning.screenFlashOpacity
        flash.zPosition = Layer.screenFlash
        camera.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: tuning.screenFlashDuration), .removeFromParent()]))

        let snow = SKEmitterNode()
        snow.particleTexture = flakeTexture
        snow.particleColor = .white
        snow.particleColorBlendFactor = 1
        snow.position = CGPoint(x: 0, y: screenSize.height / 2 + tuning.snowSize)
        snow.particlePositionRange = CGVector(dx: screenSize.width * 1.1, dy: 0)
        snow.particleBirthRate = tuning.snowBirthRate
        let fall = tuning.snowSpeed
        snow.particleSpeed = (fall.lowerBound + fall.upperBound) / 2
        snow.particleSpeedRange = fall.upperBound - fall.lowerBound
        snow.emissionAngle = -.pi / 2
        snow.emissionAngleRange = 0.35
        snow.particleLifetime = screenSize.height / fall.lowerBound
        snow.particleScale = 0.6
        snow.particleScaleRange = 0.6
        snow.particleRotationRange = 2 * .pi
        snow.particleRotationSpeed = 1.2
        snow.particleAlpha = 0.95
        snow.particleAlphaRange = 0.3
        snow.zPosition = Layer.screenFlash - 0.5
        snow.advanceSimulationTime(0.4)
        camera.addChild(snow)
        snow.run(.sequence([
            .wait(forDuration: tuning.frameFadeIn + tuning.frameHold),
            .run { [weak snow] in snow?.particleBirthRate = 0 },
            .wait(forDuration: TimeInterval(snow.particleLifetime)),
            .removeFromParent(),
        ]))

        let ring = SKShapeNode(circleOfRadius: Tuning.World.unit * cameraScale)
        ring.strokeColor = iceColor
        ring.lineWidth = 6 * cameraScale
        ring.glowWidth = 4 * cameraScale
        ring.fillColor = .clear
        ring.position = top
        node.addChild(ring)
        let grow = SKAction.scale(to: tuning.ringScale, duration: tuning.ringDuration)
        grow.timingMode = .easeOut
        ring.run(.sequence([.group([grow, .fadeOut(withDuration: tuning.ringDuration)]), .removeFromParent()]))

        for block in blocks {
            let flakes = SKEmitterNode()
            flakes.particleTexture = flakeTexture
            flakes.particleColor = iceColor
            flakes.particleColorBlendFactor = 1
            flakes.particleColorRedRange = 0.4
            flakes.position = block.position
            flakes.particlePositionRange = CGVector(dx: block.footprint.width, dy: block.footprint.height)
            flakes.numParticlesToEmit = tuning.flakesPerPiece
            flakes.particleBirthRate = Tuning.Juice.dustBirthRate
            flakes.particleLifetime = tuning.flakeLifetime
            flakes.particleLifetimeRange = tuning.flakeLifetime / 2
            flakes.emissionAngleRange = 2 * .pi
            let speed = tuning.flakeSpeed
            flakes.particleSpeed = (speed.lowerBound + speed.upperBound) / 2
            flakes.particleSpeedRange = speed.upperBound - speed.lowerBound
            flakes.yAcceleration = -80
            flakes.particleRotationRange = 2 * .pi
            flakes.particleRotationSpeed = 3
            flakes.particleScale = 0.6
            flakes.particleScaleRange = 0.5
            flakes.particleAlphaSpeed = -1 / tuning.flakeLifetime
            node.addChild(flakes)
            flakes.run(.sequence([.wait(forDuration: TimeInterval(tuning.flakeLifetime * 1.6)), .removeFromParent()]))
        }
        audio.play(.glassShatter, volume: Tuning.Sound.shatterVolume, semitones: 7)
        haptics.play(Tuning.Haptics.shatter, spacing: Tuning.Haptics.patternSpacing / 2)
    }

    func reset() {
        pendingLaunches.removeAll()
        node.removeAllChildren()
    }
}
