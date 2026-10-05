import SpriteKit

/// Small puffs of dust where blocks land. A fixed set of emitters is reused, so an impact never allocates.
@MainActor
final class DustPool {
    let node = SKNode()
    private var emitters: [SKEmitterNode] = []
    private var next = 0

    init() {
        node.zPosition = Layer.dust
        for _ in 0..<Tuning.Juice.dustEmitters {
            let emitter = DustPool.makeEmitter()
            node.addChild(emitter)
            emitters.append(emitter)
        }
    }

    func refresh(using textures: TextureFactory) {
        let texture = textures.softDot(diameter: Tuning.Juice.dustDotSize)
        let color = textures.resolve(Palette.dust)
        for emitter in emitters {
            emitter.particleTexture = texture
            emitter.particleColor = color
        }
    }

    /// - Parameters:
    ///   - normal: Direction the dust rises toward, away from the surface that was hit.
    ///   - width: Length of contact the dust spreads along.
    ///   - strength: Impact strength, 0...1.
    func puff(at point: CGPoint, normal: CGVector, width: CGFloat, strength: CGFloat) {
        guard !emitters.isEmpty else { return }
        let emitter = emitters[next]
        next = (next + 1) % emitters.count
        emitter.position = point
        emitter.zRotation = atan2(normal.dy, normal.dx) - .pi / 2
        emitter.particlePositionRange = CGVector(dx: width, dy: 0)
        emitter.particleSpeed = Tuning.Juice.dustSpeed.value(at: strength)
        emitter.particleSpeedRange = emitter.particleSpeed
        emitter.numParticlesToEmit = Int(Tuning.Juice.dustParticles.value(at: strength))
        emitter.particleBirthRate = Tuning.Juice.dustBirthRate
        emitter.resetSimulation()
    }

    private static func makeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        let lifetime = Tuning.Juice.dustLifetime
        let opacity = Tuning.Juice.dustOpacity
        emitter.particleBirthRate = 0
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime / 2
        // Anywhere in the half-circle above the surface.
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.particleAlpha = opacity
        emitter.particleAlphaRange = opacity / 3
        emitter.particleAlphaSpeed = -opacity / lifetime
        emitter.particleScale = Tuning.Juice.dustScale
        emitter.particleScaleRange = Tuning.Juice.dustScale / 2
        emitter.particleScaleSpeed = Tuning.Juice.dustGrowth
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .alpha
        return emitter
    }
}
