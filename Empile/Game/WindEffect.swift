import SpriteKit

/// The wind in the world: streaks blowing across the screen, and the push on every piece still in play.
/// Frozen pieces, left behind below the screen, are static bodies and never feel it.
@MainActor
final class WindEffect {
    /// Hangs from the camera, so the streaks cross the screen whatever the height and the zoom.
    let node = SKEmitterNode()
    private var viewSize = CGSize.zero

    init() {
        node.zPosition = Layer.wind
        node.particleBirthRate = 0
        node.particleLifetime = Tuning.Wind.streakLifetime
        node.particleLifetimeRange = Tuning.Wind.streakLifetime / 3
        node.particleAlphaRange = Tuning.Wind.streakOpacity / 2
        node.particleScaleRange = Tuning.Wind.streakScaleRange
        node.particleColorBlendFactor = 1
        node.particleBlendMode = .alpha
    }

    func refresh(using textures: TextureFactory) {
        node.particleTexture = textures.streak(length: Tuning.Wind.streakLength, thickness: Tuning.Wind.streakThickness)
        node.particleColor = textures.resolve(Palette.wind)
    }

    func layout(viewSize: CGSize) {
        self.viewSize = viewSize
    }

    /// Streaks from the side the wind comes from: a few while it rises, many while it blows.
    func show(_ wind: WindState) {
        let share: CGFloat = switch wind.phase {
        case .calm: 0
        case .warning: Tuning.Wind.warningStreakShare
        case .blowing: max(Tuning.Wind.warningStreakShare, wind.strength)
        }
        node.particleBirthRate = Tuning.Wind.maxStreaksPerSecond * share
        guard share > 0 else { return }
        // Just off screen on the upwind side, along the whole height.
        node.position = CGPoint(x: -wind.direction * viewSize.width * Tuning.Wind.streakStartOffset, y: 0)
        node.particlePositionRange = CGVector(dx: 0, dy: viewSize.height)
        node.emissionAngle = wind.direction > 0 ? 0 : .pi
        node.emissionAngleRange = Tuning.Wind.streakSpread
        node.particleRotation = node.emissionAngle
        let crossing = viewSize.width * (1 + Tuning.Wind.streakStartOffset) / Tuning.Wind.streakLifetime
        node.particleSpeed = crossing * (Tuning.Wind.streakBaseSpeed + (1 - Tuning.Wind.streakBaseSpeed) * share)
        node.particleSpeedRange = node.particleSpeed / 3
        node.particleAlpha = Tuning.Wind.streakOpacity * max(share, Tuning.Wind.warningStreakShare)
    }

    /// Pushes every piece still in play sideways. Each piece catches wind in proportion to its size, as a share
    /// of what a stone piece that size weighs: stone and gold resist, light glass and springs get blown away.
    /// The push lands high on each piece, so a tall, thin pile tips over while a wide, well-built one holds.
    /// - Parameter pressure: Push at the peak of the gust, as a share of the weight of the same piece in stone.
    func push(_ blocks: [BlockNode], wind: WindState, pressure: CGFloat, gravity: CGFloat) {
        guard wind.phase == .blowing, wind.strength > 0 else { return }
        let stoneDensity = Tuning.Materials.stone.density
        for block in blocks where !block.isFrozen {
            guard let body = block.physicsBody, body.isDynamic, let scene = block.scene else { continue }
            block.wake()
            // `area × density` is exactly how the engine computes mass, whatever its units.
            let stoneWeight = body.area * stoneDensity * gravity
            let force = pressure * wind.strength * stoneWeight * wind.direction
            let lift = block.footprint.height / 2 * Tuning.Wind.pushHeight
            let point = scene.convert(CGPoint(x: 0, y: lift), from: block)
            body.applyForce(CGVector(dx: force, dy: 0), at: point)
        }
    }

    func reset() {
        node.particleBirthRate = 0
        node.resetSimulation()
    }
}
