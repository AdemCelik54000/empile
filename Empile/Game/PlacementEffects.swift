import SpriteKit

/// Celebrations in the world: the points floating up from each settled piece, gold sparkles for perfect
/// placements and combos, and showers of sparkles for milestones and records.
@MainActor
final class PlacementEffects {
    let node = SKNode()
    private var sparkleTexture: SKTexture?
    private var textColor = UIColor.label
    private var celebrationColor = UIColor.orange
    private var shadowColor = UIColor.black

    init() {
        node.zPosition = Layer.effects
    }

    func refresh(using textures: TextureFactory) {
        sparkleTexture = textures.sparkle(size: Tuning.Celebration.sparkleSize)
        textColor = textures.resolve(Palette.scoreText)
        celebrationColor = textures.resolve(Palette.celebration)
        shadowColor = textures.resolve(Palette.shade)
    }

    /// The points a piece earned, floating up from it. Perfect placements glow gold, with the combo under them
    /// and a burst of sparkles that grows with the combo.
    func show(_ placement: PlacementScore, on block: BlockNode) {
        let point = CGPoint(x: block.position.x, y: block.topY + Tuning.Celebration.labelGap)
        switch placement.quality {
        case .perfect:
            var lines = [String(localized: "Parfait ! +\(placement.points)")]
            if placement.streak >= 2 {
                let multiplier = placement.multiplier.formatted(.number.precision(.fractionLength(0...2)))
                lines.append(String(localized: "Combo ×\(multiplier)"))
            }
            floatLabel(lines, color: celebrationColor, size: Tuning.Celebration.perfectFontSize, at: point)
            let count = Tuning.Celebration.perfectSparkles + Tuning.Celebration.sparklesPerStreak * (placement.streak - 1)
            burst(at: block.position, spread: block.footprint, count: min(count, Tuning.Celebration.maxComboSparkles))
        case .good:
            floatLabel(["+\(placement.points)"], color: textColor, size: Tuning.Celebration.labelFontSize, at: point)
        case .sloppy:
            floatLabel(["+\(placement.points)"], color: textColor.withAlphaComponent(Tuning.Celebration.sloppyOpacity),
                       size: Tuning.Celebration.labelFontSize, at: point)
        }
    }

    /// A shower of sparkles over the top of the tower.
    func shower(at point: CGPoint, count: Int) {
        burst(at: point, spread: CGSize(width: Tuning.Celebration.showerWidth, height: Tuning.World.unit), count: count)
    }

    /// Words floating up over the tower, for a record.
    func announce(_ text: String, at point: CGPoint) {
        floatLabel([text], color: celebrationColor, size: Tuning.Celebration.perfectFontSize, at: point)
    }

    func reset() {
        node.removeAllChildren()
    }

    private func burst(at point: CGPoint, spread: CGSize, count: Int) {
        guard count > 0 else { return }
        let tuning = Tuning.Celebration.self
        let burst = SKEmitterNode()
        burst.particleTexture = sparkleTexture
        burst.particleColor = celebrationColor
        burst.particleColorBlendFactor = 1
        // Some sparkles come out nearly white, so the burst glitters instead of looking flat.
        burst.particleColorBlueRange = 0.5
        burst.particleColorGreenRange = 0.3
        burst.particleBlendMode = .add
        burst.position = point
        burst.particlePositionRange = CGVector(dx: spread.width, dy: spread.height)
        burst.numParticlesToEmit = count
        burst.particleBirthRate = tuning.sparkleBirthRate
        burst.particleLifetime = tuning.sparkleLifetime
        burst.particleLifetimeRange = tuning.sparkleLifetime / 2
        burst.emissionAngle = .pi / 2
        burst.emissionAngleRange = 2 * .pi
        let speed = tuning.sparkleSpeed
        burst.particleSpeed = (speed.lowerBound + speed.upperBound) / 2
        burst.particleSpeedRange = speed.upperBound - speed.lowerBound
        burst.yAcceleration = Tuning.World.gravity.dy * Tuning.World.pointsPerMeter / 4
        burst.particleScale = 1
        burst.particleScaleRange = 0.6
        burst.particleScaleSpeed = -1 / tuning.sparkleLifetime
        burst.particleRotationRange = .pi
        burst.particleRotationSpeed = tuning.sparkleSpin
        burst.particleAlphaSpeed = -1 / tuning.sparkleLifetime
        node.addChild(burst)
        burst.run(.sequence([.wait(forDuration: TimeInterval(tuning.sparkleLifetime * 2)), .removeFromParent()]))
    }

    /// Lines that pop in from small, drift up and fade, with a soft shadow to stay readable over any piece.
    private func floatLabel(_ lines: [String], color: UIColor, size: CGFloat, at point: CGPoint) {
        let tuning = Tuning.Celebration.self
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 0) } ?? base
        let group = SKNode()
        group.position = point
        group.setScale(tuning.labelStartScale)
        for (index, line) in lines.enumerated() {
            let lineFont = index == 0 ? font : font.withSize(size * 0.7)
            let y = -CGFloat(index) * size
            let offset = tuning.labelShadowOffset
            for (fill, shift) in [(shadowColor.withAlphaComponent(tuning.labelShadowOpacity), offset), (color, 0)] {
                let label = SKLabelNode(attributedText: NSAttributedString(
                    string: line,
                    attributes: [.font: lineFont, .foregroundColor: fill]
                ))
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: shift, y: y - shift)
                group.addChild(label)
            }
        }
        node.addChild(group)
        let duration = tuning.labelDuration
        let pop = SKAction.scale(to: 1, duration: duration * 0.3)
        pop.timingFunction = Easing.backOut
        let rise = SKAction.moveBy(x: 0, y: tuning.labelRise, duration: duration)
        rise.timingMode = .easeOut
        group.run(.sequence([
            .group([pop, rise, .sequence([.wait(forDuration: duration * 0.6), .fadeOut(withDuration: duration * 0.4)])]),
            .removeFromParent(),
        ]))
    }
}
