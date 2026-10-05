import CoreGraphics
import Testing
@testable import Empile

@Suite("Impact strength and pitch")
struct ImpactTests {
    let scale = ImpactScale(threshold: 5, full: 260, curve: 0.6)

    @Test func softContactsAreIgnored() {
        #expect(scale.strength(for: 0) == nil)
        #expect(scale.strength(for: 4.9) == nil)
    }

    @Test func strengthGrowsWithTheImpulseAndCapsAtOne() {
        let gentle = scale.strength(for: 30) ?? -1
        let hard = scale.strength(for: 250) ?? -1
        #expect(gentle > 0)
        #expect(hard > gentle)
        #expect(scale.strength(for: 260) == 1)
        #expect(scale.strength(for: 5000) == 1)
    }

    @Test func softImpactsAreBoostedSoTheyStillRegister() {
        let linear = (30 - 5) / (260 - 5) as CGFloat
        #expect((scale.strength(for: 30) ?? 0) > linear)
    }

    @Test func biggerBlocksSoundLower() {
        let reference = Int(Tuning.Impact.referenceArea)
        #expect(ImpactPitch.semitones(forArea: reference) == 0)
        #expect(ImpactPitch.semitones(forArea: 1) > 0)
        #expect(ImpactPitch.semitones(forArea: 4) < 0)
        #expect(ImpactPitch.semitones(forArea: 0) == 0)
    }

    @Test func rangesInterpolateAndClamp() {
        let range: ClosedRange<CGFloat> = 10...20
        #expect(range.value(at: 0) == 10)
        #expect(range.value(at: 0.5) == 15)
        #expect(range.value(at: 2) == 20)
        #expect(range.value(at: -1) == 10)
    }
}
