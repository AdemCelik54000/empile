import Testing
@testable import Empile

@Suite("Tower stability detection")
struct SettlingTests {
    let threshold = CalmThreshold(linearSpeed: 6, angularSpeed: 0.08)

    @Test func settlesAfterStayingCalmLongEnough() {
        var timer = SettleTimer(requiredDuration: 0.5)
        for _ in 0..<3 {
            timer.record(isCalm: true, deltaTime: 0.125)
        }
        #expect(!timer.isSettled)
        timer.record(isCalm: true, deltaTime: 0.125)
        #expect(timer.isSettled)
    }

    @Test func anyMovementRestartsTheWait() {
        var timer = SettleTimer(requiredDuration: 0.5)
        timer.record(isCalm: true, deltaTime: 0.4)
        timer.record(isCalm: false, deltaTime: 1.0 / 120)
        timer.record(isCalm: true, deltaTime: 0.4)
        #expect(!timer.isSettled)
    }

    @Test(arguments: [60.0, 120.0])
    func waitLastsTheSameRealTimeAtAnyFrameRate(hertz: Double) {
        var timer = SettleTimer(requiredDuration: 0.5)
        for _ in 0..<Int(0.45 * hertz) { timer.record(isCalm: true, deltaTime: 1 / hertz) }
        #expect(!timer.isSettled)
        for _ in 0..<Int(0.1 * hertz) { timer.record(isCalm: true, deltaTime: 1 / hertz) }
        #expect(timer.isSettled)
    }

    @Test func slowDriftIsCalmButRockingIsNot() {
        #expect(threshold.isCalm(speed: 2, angularSpeed: 0.01))
        #expect(!threshold.isCalm(speed: 2, angularSpeed: -0.3))
        #expect(!threshold.isCalm(speed: 40, angularSpeed: 0))
    }
}
