import CoreGraphics
import Testing
@testable import Empile

@Suite("Frame-rate independent smoothing")
struct SmoothingTests {
    @Test func sameMotionAt60And120Hertz() {
        let start = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 100, y: -40)
        let at60 = Smoothing.approach(start, to: target, sharpness: 30, deltaTime: 1.0 / 60)
        let halfway = Smoothing.approach(start, to: target, sharpness: 30, deltaTime: 1.0 / 120)
        let at120 = Smoothing.approach(halfway, to: target, sharpness: 30, deltaTime: 1.0 / 120)
        #expect(abs(at60.x - at120.x) < 1e-9)
        #expect(abs(at60.y - at120.y) < 1e-9)
    }

    @Test func neverOvershootsEvenOnALongFrame() {
        let blend = Smoothing.blend(sharpness: 30, deltaTime: 1)
        #expect(blend > 0.99)
        #expect(blend <= 1)
    }

    @Test func standsStillWhenNoTimePasses() {
        #expect(Smoothing.blend(sharpness: 30, deltaTime: 0) == 0)
    }
}
