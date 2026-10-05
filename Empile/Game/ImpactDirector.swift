import SpriteKit

/// Turns collisions into feel: squash, dust, sound, vibration and camera shake, all scaled by how hard
/// the blocks hit. Contacts are collected during the physics step and played once per frame, so several
/// contacts in one frame give one sound and one vibration, from the strongest.
@MainActor
final class ImpactDirector {
    private struct Impact {
        let point: CGPoint
        /// Points away from the surface that was hit.
        let normal: CGVector
        let strength: CGFloat
        /// The block that came down (the most recently dropped one when two blocks meet).
        let landing: BlockNode
        /// The block it hit, if not the platform.
        let struck: BlockNode?
    }

    /// Room reserved up front, so collecting contacts never allocates during play.
    private static let typicalContactsPerFrame = 8

    private let haptics: HapticsManager
    private let audio: AudioManager
    private let dust: DustPool
    private let cameraRig: CameraRig
    private var pending: [Impact] = []
    private var lastHapticTime = -TimeInterval.infinity

    init(haptics: HapticsManager, audio: AudioManager, dust: DustPool, cameraRig: CameraRig) {
        self.haptics = haptics
        self.audio = audio
        self.dust = dust
        self.cameraRig = cameraRig
        pending.reserveCapacity(ImpactDirector.typicalContactsPerFrame)
    }

    /// Call from the physics contact delegate.
    func record(_ contact: SKPhysicsContact) {
        guard let strength = Tuning.Impact.scale.strength(for: contact.collisionImpulse) else { return }
        let first = contact.bodyA.node as? BlockNode
        let second = contact.bodyB.node as? BlockNode
        let landing: BlockNode
        let struck: BlockNode?
        switch (first, second) {
        case let (first?, second?):
            (landing, struck) = first.dropOrder > second.dropOrder ? (first, second) : (second, first)
        case let (block?, nil), let (nil, block?):
            (landing, struck) = (block, nil)
        case (nil, nil):
            return
        }
        let normal = contact.contactNormal.dy < 0
            ? CGVector(dx: -contact.contactNormal.dx, dy: -contact.contactNormal.dy)
            : contact.contactNormal
        pending.append(Impact(point: contact.contactPoint, normal: normal, strength: strength,
                              landing: landing, struck: struck))
    }

    /// Call once per frame, after physics.
    func playPending(at time: TimeInterval) {
        guard !pending.isEmpty else { return }
        var strongest: Impact?
        for impact in pending where impact.landing.acceptsImpact(at: time) {
            squash(for: impact)
            puffDust(for: impact)
            if impact.strength > (strongest?.strength ?? -1) {
                strongest = impact
            }
        }
        pending.removeAll(keepingCapacity: true)
        guard let strongest else { return }
        playSound(for: strongest)
        vibrate(for: strongest, at: time)
        shakeCamera(for: strongest)
    }

    private func squash(for impact: Impact) {
        guard Tuning.Juice.squashEnabled, impact.strength >= Tuning.Juice.squashMinimumStrength else { return }
        let amount = Tuning.Juice.squashMax * impact.strength
        impact.landing.squash(by: amount)
        impact.struck?.squash(by: amount * Tuning.Juice.struckSquashShare)
    }

    private func puffDust(for impact: Impact) {
        guard Tuning.Juice.dustEnabled, impact.strength >= Tuning.Juice.dustMinimumStrength else { return }
        dust.puff(at: impact.point, normal: impact.normal,
                  width: impact.landing.footprint.width * Tuning.Juice.dustSpread, strength: impact.strength)
    }

    private func playSound(for impact: Impact) {
        let jitter = Tuning.Sound.pitchJitter
        audio.play(
            .impact(of: impact.landing.definition.kind),
            volume: Tuning.Sound.impactVolume.value(at: Float(impact.strength)),
            semitones: ImpactPitch.semitones(forArea: impact.landing.shape.area) + .random(in: -jitter...jitter)
        )
    }

    private func vibrate(for impact: Impact, at time: TimeInterval) {
        guard time - lastHapticTime >= Tuning.Haptics.minimumInterval else { return }
        lastHapticTime = time
        let strength = Float(impact.strength)
        haptics.play(HapticTap(
            intensity: Tuning.Haptics.impactIntensity.value(at: strength),
            sharpness: Tuning.Haptics.impactSharpness.value(at: strength)
        ))
    }

    private func shakeCamera(for impact: Impact) {
        let threshold = Tuning.Juice.shakeMinimumStrength
        guard Tuning.Juice.shakeEnabled, impact.strength >= threshold, threshold < 1 else { return }
        cameraRig.shake(strength: (impact.strength - threshold) / (1 - threshold))
    }
}
