import CoreHaptics

/// One short vibration.
struct HapticTap: Sendable {
    /// 0...1.
    let intensity: Float
    /// 0 = round thud, 1 = crisp click.
    let sharpness: Float
}

/// Plays every game vibration through Core Haptics. Does nothing on devices without a Taptic Engine.
///
/// An actor: starting the haptic engine blocks until it is ready, and the game's main thread must never
/// wait for it. Callers fire and forget.
actor HapticsManager {
    private let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var isRunning = false
    /// The player's setting. `Tuning.Haptics.isEnabled` stays the developer's master switch.
    private var isEnabled = true

    /// Creates and starts the engine in the background. Call when the app becomes active.
    nonisolated func start() {
        Task { await startEngine() }
    }

    nonisolated func play(_ tap: HapticTap) {
        play([tap], spacing: 0)
    }

    nonisolated func setEnabled(_ isEnabled: Bool) {
        Task { await apply(isEnabled) }
    }

    /// Several taps in a row, `spacing` seconds apart.
    nonisolated func play(_ taps: [HapticTap], spacing: TimeInterval) {
        guard Tuning.Haptics.isEnabled, !taps.isEmpty else { return }
        Task { await playNow(taps, spacing: spacing) }
    }

    private func apply(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    private func playNow(_ taps: [HapticTap], spacing: TimeInterval) {
        guard isEnabled else { return }
        startEngine()
        guard isRunning, let engine else { return }
        let events = taps.enumerated().map { index, tap in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: tap.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: tap.sharpness),
                ],
                relativeTime: Double(index) * spacing
            )
        }
        do {
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            isRunning = false
        }
    }

    private func startEngine() {
        guard isSupported, !isRunning else { return }
        do {
            let engine = try self.engine ?? makeEngine()
            self.engine = engine
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    private func markStopped() {
        isRunning = false
    }

    private func makeEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        // The system stops the engine in the background or when its server resets:
        // note it, and the next vibration restarts it.
        engine.stoppedHandler = { [weak self] _ in
            Task { await self?.markStopped() }
        }
        engine.resetHandler = { [weak self] in
            Task { await self?.markStopped() }
        }
        return engine
    }
}
