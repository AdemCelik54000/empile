import CoreGraphics
import Testing
@testable import Empile

@Suite("Tension and slow motion")
struct DramaTests {
    @Test func aBarelyTiltedBlockIsNoDanger() {
        #expect(TensionGauge.danger(forTilt: 0) == 0)
        #expect(TensionGauge.danger(forTilt: Tuning.Tension.safeTilt) == 0)
    }

    @Test func dangerGrowsWithTheTiltAndCapsAtOne() {
        let middle = (Tuning.Tension.safeTilt + Tuning.Tension.fullTilt) / 2
        #expect(abs(TensionGauge.danger(forTilt: middle) - 0.5) < 1e-9)
        #expect(TensionGauge.danger(forTilt: Tuning.Tension.fullTilt) == 1)
        #expect(TensionGauge.danger(forTilt: 1) == 1)
    }

    @Test func tensionRisesFasterThanItFades() {
        var gauge = TensionGauge()
        gauge.update(towards: 1, deltaTime: 0.1)
        let risen = gauge.level
        gauge.update(towards: 0, deltaTime: 0.1)
        let fallen = risen - gauge.level
        #expect(risen > fallen)
    }

    @Test func slowMotionHoldsThenEasesBackToFullSpeed() {
        var slow = SlowMotion()
        #expect(slow.speed(at: 10) == 1)
        slow.trigger(at: 10)
        #expect(slow.speed(at: 10) == Tuning.SlowMotion.speed)
        let rampMiddle = 10 + Tuning.SlowMotion.holdDuration + Tuning.SlowMotion.rampDuration / 2
        #expect(slow.speed(at: rampMiddle) > Tuning.SlowMotion.speed)
        #expect(slow.speed(at: rampMiddle) < 1)
        let end = 10 + Tuning.SlowMotion.holdDuration + Tuning.SlowMotion.rampDuration
        #expect(abs(slow.speed(at: end) - 1) < 1e-6)
        #expect(slow.speed(at: end + 0.01) == 1)
    }

    @Test func slowMotionLastsLessThanASecond() {
        #expect(Tuning.SlowMotion.holdDuration + Tuning.SlowMotion.rampDuration < 1)
    }

    @Test func aSecondTriggerDoesNotRestartARunningSlowMotion() {
        var slow = SlowMotion()
        slow.trigger(at: 0)
        slow.trigger(at: 0.5)
        #expect(!slow.isActive(at: Tuning.SlowMotion.holdDuration + Tuning.SlowMotion.rampDuration + 0.01))
    }
}
