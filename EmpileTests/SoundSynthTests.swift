import AVFoundation
import Testing
@testable import Empile

@Suite("Sound synthesis")
struct SoundSynthTests {
    let sampleRate = 44_100.0

    private static let synthesized = SoundEffect.allCases.filter { $0.recipe != nil }

    private func render(_ effect: SoundEffect) -> [Float] {
        guard let recipe = effect.recipe else { return [] }
        return SoundSynth.render(recipe, sampleRate: sampleRate, peak: 0.9, seed: effect.seed)
    }

    @Test(arguments: synthesized)
    func lastsAsLongAsItsRecipe(effect: SoundEffect) {
        #expect(render(effect).count == Int((effect.recipe?.duration ?? 0) * sampleRate))
    }

    @Test(arguments: synthesized)
    func peaksExactlyAtTheRequestedLevel(effect: SoundEffect) {
        let loudest = render(effect).map(abs).max() ?? 0
        #expect(abs(loudest - 0.9) < 0.0001)
    }

    @Test(arguments: synthesized.filter { !$0.loops })
    func startsAndEndsSilentSoItNeverClicks(effect: SoundEffect) {
        let samples = render(effect)
        #expect(abs(samples.first ?? 1) < 0.01)
        #expect(abs(samples.last ?? 1) < 0.01)
    }

    @Test func impactIsLoudAtFirstThenDiesAway() {
        let samples = render(.turn)
        let quarter = samples.count / 4
        let head = samples[..<quarter].map(abs).max() ?? 0
        let tail = samples[(3 * quarter)...].map(abs).max() ?? 1
        #expect(tail < head / 10)
    }

    @Test(arguments: synthesized.filter(\.loops))
    func loopsJoinWithoutAJump(effect: SoundEffect) {
        let samples = render(effect)
        let first = samples.first ?? 0
        let last = samples.last ?? 1
        let largestStep = zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        // Wrapping from the last sample to the first is no bigger a step than any inside the sound.
        #expect(abs(first - last) <= largestStep * 1.5)
    }

    @Test func wobbleBendsThePitch() {
        let steady = SoundRecipe(modes: [.init(frequency: 220, amplitude: 1, decay: .infinity)],
                                 noise: .init(amplitude: 0, decay: 1, brightness: 0),
                                 duration: 0.2, attack: 0, release: 0)
        var wobbly = steady
        wobbly.wobble = .init(depth: 0.3, rate: 10, decay: 1)
        let plain = SoundSynth.render(steady, sampleRate: sampleRate, peak: 0.9, seed: 1)
        let bent = SoundSynth.render(wobbly, sampleRate: sampleRate, peak: 0.9, seed: 1)
        #expect(plain != bent)
    }

    @Test func sameSoundOnEveryLaunch() {
        #expect(render(.glassShatter) == render(.glassShatter))
    }

    @Test(arguments: SoundEffect.allCases)
    func recordedSoundsShipWithTheApp(effect: SoundEffect) {
        guard case .file(let name) = effect.source else { return }
        #expect(Bundle.main.url(forResource: name, withExtension: "wav") != nil)
        let format = AVAudioFormat(standardFormatWithSampleRate: Tuning.Sound.sampleRate, channels: 1)!
        let buffer = AudioManager.loadBuffer(named: name, format: format)
        #expect((buffer?.frameLength ?? 0) > 0)
        #expect(buffer?.format.channelCount == 1)
    }
}
