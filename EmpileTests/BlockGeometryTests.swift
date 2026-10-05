import CoreGraphics
import Testing
@testable import Empile

@Suite("Block geometry")
struct BlockGeometryTests {
    let plank = CGSize(width: 72, height: 36)

    @Test func topOfAFlatBlock() {
        #expect(BlockGeometry.topY(center: CGPoint(x: 0, y: 18), size: plank, rotation: 0) == 36)
    }

    @Test func topOfABlockStandingOnItsEnd() {
        let top = BlockGeometry.topY(center: CGPoint(x: 0, y: 36), size: plank, rotation: .pi / 2)
        #expect(abs(top - 72) < 1e-9)
    }

    @Test func tiltedBlockReachesHigherThanItsHalfHeight() {
        let extent = BlockGeometry.verticalHalfExtent(size: plank, rotation: .pi / 4)
        #expect(abs(extent - (36 + 18) * 0.5.squareRoot()) < 1e-9)
    }

    @Test func surfaceOfAFlatBlockUnderASpan() {
        let top = BlockGeometry.surfaceTop(center: CGPoint(x: 0, y: 18), size: plank, rotation: 0, over: -10...10)
        #expect(top == 36)
    }

    @Test func spanBesideTheBlockMissesIt() {
        let top = BlockGeometry.surfaceTop(center: CGPoint(x: 0, y: 18), size: plank, rotation: 0, over: 40...80)
        #expect(top == nil)
    }

    @Test func spanTouchingOnlyTheEdgeStillCounts() {
        let top = BlockGeometry.surfaceTop(center: CGPoint(x: 0, y: 18), size: plank, rotation: 0, over: 36...80)
        #expect(top == 36)
    }

    @Test func tiltedBlockUsesTheHighestCornerUnderTheSpan() {
        // A square tilted 45°: a diamond with its top corner straight above the center.
        let square = CGSize(width: 40, height: 40)
        let halfDiagonal = 20 * 2.0.squareRoot()
        let center = CGPoint(x: 0, y: 100)
        let overCorner = BlockGeometry.surfaceTop(center: center, size: square, rotation: .pi / 4, over: -5...5)
        let overSlope = BlockGeometry.surfaceTop(center: center, size: square, rotation: .pi / 4, over: 10...30)
        #expect(abs((overCorner ?? 0) - (100 + halfDiagonal)) < 1e-9)
        #expect(abs((overSlope ?? 0) - (100 + halfDiagonal - 10)) < 1e-9)
    }
}
