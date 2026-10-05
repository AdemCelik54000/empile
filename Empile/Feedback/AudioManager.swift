import AVFoundation

/// Plays every game sound through one `AVAudioEngine`. Each voice has its own varispeed, so any sound
/// can be played higher or lower on the fly, like a tape running faster or slower.
///
/// An actor: starting the audio session can block for a moment, and the game's main thread must never
/// wait for it. Callers fire and forget.
actor AudioManager {
    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }

    private let engine = AVAudioEngine()
    /// The player's setting. `Tuning.Sound.isEnabled` stays the developer's master switch.
    private var isEnabled = true
    private var voices: [Voice] = []
    /// One dedicated voice per looping sound, whose volume is set on the fly.
    private var loopVoices: [SoundEffect: Voice] = [:]
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var nextVoice = 0

    /// Builds the sounds and starts the engine in the background. Call when the app becomes active.
    nonisolated func start() {
        Task { await startEngine() }
    }

    /// - Parameters:
    ///   - volume: 0...1.
    ///   - semitones: Pitch shift; 12 is one octave up.
    nonisolated func play(_ effect: SoundEffect, volume: Float, semitones: Float = 0) {
        guard Tuning.Sound.isEnabled, !effect.loops else { return }
        Task { await playNow(effect, volume: volume, semitones: semitones) }
    }

    nonisolated func setEnabled(_ isEnabled: Bool) {
        Task { await apply(isEnabled) }
    }

    /// Starts, adjusts or stops (volume 0) a looping sound.
    nonisolated func setLoopVolume(_ effect: SoundEffect, _ volume: Float) {
        guard effect.loops else { return }
        Task { await applyLoopVolume(effect, volume) }
    }

    private func apply(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        guard !isEnabled else { return }
        for voice in loopVoices.values {
            voice.player.stop()
        }
    }

    private func applyLoopVolume(_ effect: SoundEffect, _ volume: Float) {
        guard volume > 0, isEnabled, Tuning.Sound.isEnabled else {
            loopVoices[effect]?.player.stop()
            return
        }
        startEngine()
        guard engine.isRunning, let voice = loopVoices[effect], let buffer = buffers[effect] else { return }
        voice.player.volume = volume
        if !voice.player.isPlaying {
            voice.player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            voice.player.play()
        }
    }

    private func playNow(_ effect: SoundEffect, volume: Float, semitones: Float) {
        guard isEnabled else { return }
        startEngine()
        guard engine.isRunning, let buffer = buffers[effect], !voices.isEmpty else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.player.stop()
        voice.varispeed.rate = pow(2, semitones / 12)
        voice.player.volume = volume
        voice.player.scheduleBuffer(buffer, completionHandler: nil)
        voice.player.play()
    }

    private func startEngine() {
        buildIfNeeded()
        guard !engine.isRunning, !voices.isEmpty else { return }
        do {
            // Ambient: follows the Silent switch and mixes with the player's own music.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // No sound for now; the next sound tries again.
        }
    }

    private func buildIfNeeded() {
        guard voices.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: Tuning.Sound.sampleRate, channels: 1)
        else { return }
        for effect in SoundEffect.allCases {
            buffers[effect] = makeBuffer(for: effect, format: format)
        }
        for _ in 0..<Tuning.Sound.voices {
            voices.append(makeVoice(format: format))
        }
        for effect in SoundEffect.allCases where effect.loops {
            loopVoices[effect] = makeVoice(format: format)
        }
        engine.prepare()
    }

    private func makeVoice(format: AVAudioFormat) -> Voice {
        let voice = Voice(player: AVAudioPlayerNode(), varispeed: AVAudioUnitVarispeed())
        engine.attach(voice.player)
        engine.attach(voice.varispeed)
        engine.connect(voice.player, to: voice.varispeed, format: format)
        engine.connect(voice.varispeed, to: engine.mainMixerNode, format: format)
        return voice
    }

    private func makeBuffer(for effect: SoundEffect, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let samples = SoundSynth.render(
            effect.recipe,
            sampleRate: Tuning.Sound.sampleRate,
            peak: Tuning.Sound.peakLevel,
            seed: effect.seed
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }
}
