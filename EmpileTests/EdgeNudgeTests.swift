import CoreGraphics
import Testing
@testable import Empile

@Suite("Peeking to the side")
struct EdgeNudgeTests {
    private func makeNudge() -> EdgeNudge {
        EdgeNudge(edgeWidth: 18, dwell: 0.2, sharpness: 8)
    }

    @Test func staysStillAwayFromTheEdges() {
        var nudge = makeNudge()
        for _ in 0..<60 { nudge.update(fingerX: 200, width: 400, deltaTime: 1.0 / 60) }
        #expect(nudge.push == 0)
    }

    @Test func aFingerPassingTheEdgeDoesNotMoveTheCamera() {
        var nudge = makeNudge()
        nudge.update(fingerX: 5, width: 400, deltaTime: 0.1)
        nudge.update(fingerX: 200, width: 400, deltaTime: 0.1)
        #expect(nudge.push == 0)
    }

    @Test func staysAtTheEdgeAMomentThenPeeksToThatSide() {
        var right = makeNudge()
        var left = makeNudge()
        for _ in 0..<60 {
            right.update(fingerX: 395, width: 400, deltaTime: 1.0 / 60)
            left.update(fingerX: 3, width: 400, deltaTime: 1.0 / 60)
        }
        #expect(right.push > 0.9)
        #expect(left.push < -0.9)
    }

    @Test func comesBackWhenTheFingerLeavesOrLetsGo() {
        var nudge = makeNudge()
        for _ in 0..<60 { nudge.update(fingerX: 395, width: 400, deltaTime: 1.0 / 60) }
        for _ in 0..<90 { nudge.update(fingerX: nil, width: 400, deltaTime: 1.0 / 60) }
        #expect(abs(nudge.push) < 0.01)
    }

    @Test func staysPeekingWhenTheFingerComesBackToTheMiddle() {
        var nudge = makeNudge()
        for _ in 0..<60 { nudge.update(fingerX: 395, width: 400, deltaTime: 1.0 / 60) }
        for _ in 0..<120 { nudge.update(fingerX: 200, width: 400, deltaTime: 1.0 / 60) }
        #expect(nudge.push > 0.9)
    }

    @Test func switchesSidesAtTheOppositeEdge() {
        var nudge = makeNudge()
        for _ in 0..<60 { nudge.update(fingerX: 395, width: 400, deltaTime: 1.0 / 60) }
        for _ in 0..<90 { nudge.update(fingerX: 3, width: 400, deltaTime: 1.0 / 60) }
        #expect(nudge.push < -0.9)
    }
}
