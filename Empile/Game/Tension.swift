import CoreGraphics
import Foundation

/// How worried the game sounds: rises fast when a block starts to topple, fades slowly once it is safe.
struct TensionGauge: Sendable {
    private(set) var level: CGFloat = 0

    /// Danger from one moving block tilted by `tilt` radians away from lying flat or standing straight.
    static func danger(forTilt tilt: CGFloat) -> CGFloat {
        let safe = Tuning.Tension.safeTilt
        let full = Tuning.Tension.fullTilt
        guard full > safe else { return tilt > safe ? 1 : 0 }
        return ((tilt - safe) / (full - safe)).clamped(to: 0...1)
    }

    mutating func update(towards danger: CGFloat, deltaTime: TimeInterval) {
        let sharpness = danger > level ? Tuning.Tension.attackSharpness : Tuning.Tension.releaseSharpness
        level += (danger.clamped(to: 0...1) - level) * Smoothing.blend(sharpness: sharpness, deltaTime: deltaTime)
    }

    mutating func reset() {
        level = 0
    }
}

/// Plays the tension: a low hum whose volume follows the gauge, and light ticks when it gets serious.
@MainActor
final class TensionMonitor {
    private let haptics: HapticsManager
    private let audio: AudioManager
    private var gauge = TensionGauge()
    private var sentVolume: Float = 0
    private var nextTickTime: TimeInterval = 0

    init(haptics: HapticsManager, audio: AudioManager) {
        self.haptics = haptics
        self.audio = audio
    }

    func update(danger: CGFloat, time: TimeInterval, deltaTime: TimeInterval) {
        gauge.update(towards: danger, deltaTime: deltaTime)
        let level = gauge.level
        let step = Tuning.Tension.droneVolumeStep
        let rawVolume = Float(level) * Tuning.Tension.droneMaxVolume
        let volume = rawVolume < step ? 0 : rawVolume
        // Only talk to the audio engine when the volume really changes.
        if abs(volume - sentVolume) >= step || (volume == 0 && sentVolume != 0) {
            sentVolume = volume
            audio.setLoopVolume(.tensionDrone, volume)
        }
        guard level >= Tuning.Tension.hapticThreshold, time >= nextTickTime else { return }
        let urgency = (level - Tuning.Tension.hapticThreshold) / (1 - Tuning.Tension.hapticThreshold)
        haptics.play(HapticTap(
            intensity: Tuning.Tension.tickIntensity.value(at: Float(urgency)),
            sharpness: Tuning.Tension.tickSharpness
        ))
        let interval = Tuning.Tension.tickInterval
        nextTickTime = time + interval.upperBound - (interval.upperBound - interval.lowerBound) * TimeInterval(urgency)
    }

    func silence() {
        gauge.reset()
        sentVolume = 0
        audio.setLoopVolume(.tensionDrone, 0)
    }
}
