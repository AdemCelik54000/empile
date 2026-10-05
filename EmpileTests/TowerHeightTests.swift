import CoreGraphics
import Testing
@testable import Empile

@Suite("Tower height seen by the camera")
struct TowerHeightTests {
    @Test func risesAsSoonAsABlockSettlesHigher() {
        var height = TowerHeight(base: 0)
        height.update(settledTop: 300, isStable: false)
        #expect(height.top == 300)
    }

    @Test func doesNotDipWhileBlocksShakeFromAnImpact() {
        var height = TowerHeight(base: 0)
        height.update(settledTop: 500, isStable: true)
        // A new block lands on top: the upper blocks move and stop counting as settled for a moment.
        height.update(settledTop: 120, isStable: false)
        #expect(height.top == 500)
    }

    @Test func dropsOnceTheTowerIsStillAgain() {
        var height = TowerHeight(base: 0)
        height.update(settledTop: 500, isStable: true)
        height.update(settledTop: 120, isStable: false)
        // The top blocks fell off: once everything is still, the lower height is the real one.
        height.update(settledTop: 200, isStable: true)
        #expect(height.top == 200)
    }
}
