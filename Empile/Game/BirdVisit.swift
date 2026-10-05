import SpriteKit

/// A bird that now and then lands on one of the top pieces. Perched near an edge, its weight tips that side
/// down; if its piece tilts too far, falls or freezes out of sight, it flies off at once.
@MainActor
final class BirdVisit {
    let node = SKSpriteNode()
    private let audio: AudioManager
    private let haptics: HapticsManager
    private var schedule = BirdVisit.makeSchedule()
    private var textures: [TextureFactory.BirdPose: SKTexture] = [:]
    private var perch: BlockNode?
    /// Where the feet stand, in the perch's own coordinates, so the bird rides along when the piece moves.
    private var foothold = CGPoint.zero
    private var flightStart = CGPoint.zero
    private var flightEnd = CGPoint.zero

    private enum ActionKey {
        static let flap = "flap"
    }

    init(audio: AudioManager, haptics: HapticsManager) {
        self.audio = audio
        self.haptics = haptics
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.size = Tuning.Birds.size
        node.zPosition = Layer.bird
        node.isHidden = true
    }

    func refresh(using factory: TextureFactory) {
        for pose in TextureFactory.BirdPose.allCases {
            textures[pose] = factory.bird(pose)
        }
        if node.action(forKey: ActionKey.flap) != nil {
            flap()
        } else {
            node.texture = textures[.perched]
        }
    }

    func reset() {
        schedule.reset()
        hide()
    }

    /// Call once per frame, before physics: moves the bird and, while it is perched, weighs on its piece.
    /// - Parameter isActive: Whether new birds may come.
    func update(deltaTime: TimeInterval, isActive: Bool, blocks: [BlockNode], in scene: SKScene, visible: CGRect) {
        for phase in schedule.advance(by: deltaTime, isActive: isActive) {
            switch phase {
            case .arriving: arrive(among: blocks, in: scene, visible: visible)
            case .perched: settle()
            case .leaving: takeOff(visible: visible)
            case .away: hide()
            }
        }
        if (schedule.phase == .arriving || schedule.phase == .perched) && !isPerchSafe {
            schedule.scare()
            takeOff(visible: visible)
        }
        switch schedule.phase {
        case .away:
            break
        case .arriving:
            guard let target = footholdInWorld(in: scene) else { return }
            let progress = CGFloat(schedule.progress)
            let eased = 1 - (1 - progress) * (1 - progress)
            node.position = flightStart.interpolated(to: target, by: eased)
                + CGVector(dx: 0, dy: sin(.pi * progress) * Tuning.Birds.flightArc)
        case .perched:
            guard let perch, let target = footholdInWorld(in: scene) else { return }
            node.position = target
            node.zRotation = perch.zRotation
            perch.wake()
            perch.physicsBody?.applyForce(CGVector(dx: 0, dy: -Tuning.Birds.weight), at: target)
        case .leaving:
            let progress = CGFloat(schedule.progress)
            node.position = flightStart.interpolated(to: flightEnd, by: progress * progress)
            node.zRotation *= Tuning.Birds.rotationSettle
        }
    }

    // MARK: - Phases

    private func arrive(among blocks: [BlockNode], in scene: SKScene, visible: CGRect) {
        guard let (block, point) = BirdVisit.findPerch(among: blocks, in: scene, visible: visible) else {
            // Nowhere to land this time: try again after a whole pause.
            schedule.reset()
            return
        }
        perch = block
        foothold = point
        let target = footholdInWorld(in: scene) ?? .zero
        let fromRight = Bool.random()
        let margin = Tuning.Birds.edgeMargin
        flightStart = CGPoint(x: fromRight ? visible.maxX + margin : visible.minX - margin,
                              y: target.y + Tuning.Birds.flightRise)
        node.position = flightStart
        node.zRotation = 0
        face(towards: target.x - flightStart.x)
        node.isHidden = false
        flap()
    }

    private func settle() {
        node.removeAction(forKey: ActionKey.flap)
        node.texture = textures[.perched]
        perch?.squash(by: Tuning.Birds.landingSquash)
        audio.play(.chirp, volume: Tuning.Birds.chirpVolume)
        haptics.play(Tuning.Haptics.birdLanding)
    }

    private func takeOff(visible: CGRect) {
        perch = nil
        flightStart = node.position
        let toRight = Bool.random()
        let margin = Tuning.Birds.edgeMargin
        flightEnd = CGPoint(x: toRight ? visible.maxX + margin : visible.minX - margin,
                            y: node.position.y + Tuning.Birds.flightRise)
        face(towards: flightEnd.x - flightStart.x)
        flap()
        audio.play(.chirp, volume: Tuning.Birds.chirpVolume, semitones: Tuning.Birds.takeOffSemitones)
    }

    /// Gone: hidden until the next visit.
    private func hide() {
        perch = nil
        node.removeAllActions()
        node.isHidden = true
    }

    // MARK: - Helpers

    private var isPerchSafe: Bool {
        guard let perch, perch.parent != nil, !perch.isFrozen, perch.physicsBody != nil else { return false }
        return abs(remainder(perch.zRotation, .pi / 2)) < Tuning.Birds.maxTilt
    }

    private func footholdInWorld(in scene: SKScene) -> CGPoint? {
        guard let perch, perch.parent != nil else { return nil }
        return scene.convert(foothold, from: perch)
    }

    private func face(towards dx: CGFloat) {
        node.xScale = dx < 0 ? -1 : 1
    }

    private func flap() {
        guard let up = textures[.wingsUp], let down = textures[.wingsDown] else { return }
        node.run(.repeatForever(.animate(with: [up, down], timePerFrame: Tuning.Birds.flapInterval)),
                 withKey: ActionKey.flap)
    }

    /// A free spot on top of one of the highest pieces, in that piece's coordinates.
    private static func findPerch(among blocks: [BlockNode], in scene: SKScene,
                                  visible: CGRect) -> (BlockNode, CGPoint)? {
        let candidates = blocks.filter {
            $0.hasLanded && $0.isSettled && !$0.isFrozen && $0.physicsBody != nil && visible.contains($0.position)
        }
        guard let top = candidates.map(\.topY).max() else { return nil }
        let unit = Tuning.World.unit
        for block in candidates.filter({ $0.topY >= top - Tuning.Birds.perchDepth }).shuffled() {
            let shape = block.shape
            // Squares with nothing of the piece on top of them.
            let exposed = shape.cells.filter { !shape.contains(column: $0.column, row: $0.row + 1) }
            for cell in exposed.shuffled() {
                let center = shape.offset(of: cell, unit: unit)
                let jitter = CGFloat.random(in: -Tuning.Birds.footholdJitter...Tuning.Birds.footholdJitter) * unit
                let local = CGPoint(x: center.x + jitter, y: center.y + unit / 2)
                let world = scene.convert(local, from: block)
                // Another piece lying on that square would leave no room for the bird.
                let above = CGPoint(x: world.x, y: world.y + Tuning.Birds.clearance)
                if let body = scene.physicsWorld.body(at: above), body !== block.physicsBody { continue }
                return (block, local)
            }
        }
        return nil
    }

    private static func makeSchedule() -> BirdSchedule {
        BirdSchedule(pause: Tuning.Birds.pause, flight: Tuning.Birds.flight, perch: Tuning.Birds.perch,
                     seed: .random(in: .min ... .max))
    }
}

private extension CGPoint {
    func interpolated(to other: CGPoint, by amount: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * amount, y: y + (other.y - y) * amount)
    }

    static func + (point: CGPoint, offset: CGVector) -> CGPoint {
        CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)
    }
}
