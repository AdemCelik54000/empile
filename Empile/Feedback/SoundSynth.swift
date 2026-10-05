import Foundation

/// How to synthesize a short percussive sound: a few decaying resonances plus a burst of filtered noise.
/// Sounds are generated in code at launch, so the game ships no audio files.
struct SoundRecipe: Sendable {
    struct Mode: Sendable {
        /// Hertz.
        let frequency: Double
        let amplitude: Double
        /// Seconds for the resonance to fade to about a third.
        let decay: Double
    }

    struct Noise: Sendable {
        let amplitude: Double
        let decay: Double
        /// 0 = muffled, 1 = bright.
        let brightness: Double
    }

    /// Pitch that wobbles up and down, then steadies: what makes a spring go "boing".
    struct Wobble: Sendable {
        static let none = Wobble(depth: 0, rate: 0, decay: 0)

        /// Largest pitch swing, as a share of the frequency.
        let depth: Double
        /// Swings per second.
        let rate: Double
        /// Seconds for the swing to fade to about a third.
        let decay: Double
    }

    let modes: [Mode]
    let noise: Noise
    /// Seconds.
    let duration: Double
    /// Fade-in at the start, against clicks.
    let attack: Double
    /// Fade-out at the end, against clicks.
    let release: Double
    var wobble = Wobble.none
}

enum SoundSynth {
    /// Mono samples, normalized so the loudest one reaches `peak`.
    static func render(_ recipe: SoundRecipe, sampleRate: Double, peak: Float, seed: UInt64) -> [Float] {
        let count = max(1, Int(recipe.duration * sampleRate))
        var generator = SeededGenerator(seed: seed)
        var filteredNoise = 0.0
        // Phases are accumulated rather than computed from time, so the pitch can wobble smoothly.
        var phases = [Double](repeating: 0, count: recipe.modes.count)
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let wobble = recipe.wobble
            let pitch = 1 + wobble.depth * fade(time, decay: wobble.decay) * sin(2 * .pi * wobble.rate * time)
            var value = 0.0
            for (modeIndex, mode) in recipe.modes.enumerated() {
                value += mode.amplitude * fade(time, decay: mode.decay) * sin(phases[modeIndex])
                phases[modeIndex] += 2 * .pi * mode.frequency * pitch / sampleRate
            }
            let noise = Double.random(in: -1...1, using: &generator)
            filteredNoise += recipe.noise.brightness * (noise - filteredNoise)
            value += recipe.noise.amplitude * fade(time, decay: recipe.noise.decay) * filteredNoise
            samples[index] = Float(value * envelope(at: time, of: recipe))
        }
        normalize(&samples, to: peak)
        return samples
    }

    private static func fade(_ time: Double, decay: Double) -> Double {
        decay > 0 ? exp(-time / decay) : 0
    }

    private static func envelope(at time: Double, of recipe: SoundRecipe) -> Double {
        let fadeIn = recipe.attack > 0 ? min(1, time / recipe.attack) : 1
        let fadeOut = recipe.release > 0 ? ((recipe.duration - time) / recipe.release).clamped(to: 0...1) : 1
        return fadeIn * fadeOut
    }

    private static func normalize(_ samples: inout [Float], to peak: Float) {
        let loudest = samples.reduce(0) { max($0, abs($1)) }
        guard loudest > 0 else { return }
        let gain = peak / loudest
        for index in samples.indices {
            samples[index] *= gain
        }
    }
}
