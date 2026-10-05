import SpriteKit

/// The slab the tower stands on, with a pillar fading into the void below it.
@MainActor
final class Platform {
    /// World height of the surface blocks rest on.
    nonisolated static let surfaceY: CGFloat = 0
    nonisolated static let frame = CGRect(
        x: -Tuning.World.platformSize.width / 2,
        y: surfaceY - Tuning.World.platformSize.height,
        width: Tuning.World.platformSize.width,
        height: Tuning.World.platformSize.height
    )

    let node = SKNode()
    private let slab = SKSpriteNode()
    private let pillar = SKSpriteNode()

    init() {
        node.position = CGPoint(x: Platform.frame.midX, y: Platform.frame.midY)

        // Same inset as blocks, on the top face only, so blocks visually sit on the surface.
        let inset = Tuning.Physics.bodyInset
        let bodySize = CGSize(width: Platform.frame.width, height: Platform.frame.height - inset)
        let body = SKPhysicsBody(rectangleOf: bodySize, center: CGPoint(x: 0, y: -inset / 2))
        body.isDynamic = false
        body.apply(Tuning.Materials.platform)
        body.categoryBitMask = PhysicsCategory.platform
        node.physicsBody = body

        slab.size = Platform.frame.size
        slab.zPosition = Layer.platform
        pillar.anchorPoint = CGPoint(x: 0.5, y: 1)
        pillar.size = CGSize(width: Platform.frame.width * Tuning.World.pillarWidthRatio, height: Tuning.World.pillarDepth)
        pillar.zPosition = Layer.pillar
        node.addChild(pillar)
        node.addChild(slab)
    }

    func refreshTextures(using textures: TextureFactory) {
        slab.texture = textures.platform(size: Platform.frame.size)
        pillar.texture = textures.verticalFade(of: Palette.pillar)
    }
}
