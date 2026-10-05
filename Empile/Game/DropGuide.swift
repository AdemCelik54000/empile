import SpriteKit

/// A faint vertical line from the held block down to where it will land, with a mark on the landing surface.
@MainActor
final class DropGuide {
    let node = SKNode()
    private let line = SKSpriteNode(color: .clear, size: .zero)
    private let footprint = SKSpriteNode(color: .clear, size: .zero)

    init() {
        node.zPosition = Layer.guide
        node.isHidden = true
        line.anchorPoint = CGPoint(x: 0.5, y: 1)
        line.alpha = Tuning.Guide.lineOpacity
        footprint.anchorPoint = CGPoint(x: 0.5, y: 0)
        footprint.alpha = Tuning.Guide.footprintOpacity
        node.addChild(line)
        node.addChild(footprint)
    }

    func refreshColors(using textures: TextureFactory) {
        let color = textures.resolve(Palette.guide)
        line.color = color
        footprint.color = color
    }

    /// - Parameters:
    ///   - landingY: Surface the block will hit, or `nil` over the void.
    ///   - bottomY: Where to stop the line over the void.
    ///   - cameraScale: Keeps the line equally thin on screen at any zoom.
    func show(below block: BlockNode, landingY: CGFloat?, bottomY: CGFloat, cameraScale: CGFloat) {
        node.isHidden = false
        let start = CGPoint(x: block.position.x, y: block.position.y - block.footprint.height / 2)
        let endY = landingY ?? bottomY
        line.position = start
        line.size = CGSize(width: Tuning.Guide.lineWidth * cameraScale, height: max(0, start.y - endY))
        footprint.isHidden = landingY == nil
        footprint.position = CGPoint(x: start.x, y: endY)
        footprint.size = CGSize(width: block.footprint.width, height: Tuning.Guide.footprintHeight * cameraScale)
    }

    func hide() {
        node.isHidden = true
    }
}
