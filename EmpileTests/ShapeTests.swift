import CoreGraphics
import Testing
@testable import Empile

@Suite("Pieces: shapes, turns and outlines")
struct ShapeTests {
    typealias Build = TowerBuilder

    static let allPieces: [BlockShape] = [.mono, .domino, .bar3, .corner, .bar4, .square, .t, .l, .j, .s, .z]

    @Test func patternsBecomeSquares() {
        #expect(BlockShape.t.area == 4)
        #expect(BlockShape.t.columns == 3)
        #expect(BlockShape.t.rows == 2)
        // "XXX" on top, ".X." below.
        #expect(BlockShape.t.contains(column: 1, row: 0))
        #expect(!BlockShape.t.contains(column: 0, row: 0))
    }

    @Test(arguments: allPieces)
    func fourQuarterTurnsComeBackHome(shape: BlockShape) {
        #expect(shape.quarterTurned.quarterTurned.quarterTurned.quarterTurned == shape)
        #expect(shape.quarterTurned.area == shape.area)
        #expect(shape.quarterTurned.columns == shape.rows)
        #expect(shape.quarterTurned.family == shape.family)
    }

    @Test func quarterTurnIsClockwise() {
        // An L standing up, foot to the right, turned clockwise lies down with its foot pointing down-left.
        #expect(BlockShape.l.quarterTurned == BlockShape(.l, ["XXX", "X.."]))
    }

    @Test func onlyTheSquaresLookTheSameTurned() {
        let invariant = Self.allPieces.filter(\.isTurnInvariant).map(\.family)
        #expect(Set(invariant) == [.mono, .square])
    }

    @Test(arguments: allPieces)
    func outlineGoesAroundTheWholePiece(shape: BlockShape) {
        let outline = shape.outline
        // A rectilinear polygon has 4 more outward corners than inward ones.
        let convex = outline.filter(\.isConvex).count
        #expect(convex - (outline.count - convex) == 4)
    }

    @Test func outlineOfAnLHasOneNotch() {
        #expect(BlockShape.l.outline.count == 6)
        #expect(BlockShape.l.outline.filter { !$0.isConvex }.count == 1)
    }

    @Test func rowsBecomeFewRectangles() {
        #expect(BlockShape.bar4.horizontalRuns.count == 1)
        #expect(BlockShape.t.horizontalRuns.map(\.length) == [1, 3])
        #expect(BlockShape.l.horizontalRuns.map(\.length) == [2, 1, 1])
    }

    @Test(arguments: allPieces)
    func everyPieceFitsOnThePlatform(shape: BlockShape) {
        let widest = max(shape.columns, shape.rows)
        #expect(CGFloat(widest) * Tuning.World.unit <= Tuning.World.platformSize.width)
    }

    @Test func topOfATIsItsCrossbar() {
        let placed = PlacedShape(shape: .t, center: CGPoint(x: 0, y: 36), rotation: 0, unit: 36)
        #expect(abs(placed.topY - 72) < 1e-9)
        #expect(abs(placed.bottomY - 0) < 1e-9)
    }

    @Test func surfaceFollowsTheStepsOfAPiece() {
        // L standing on the platform: tall column on the left, foot on the right.
        let placed = PlacedShape(shape: .l, center: CGPoint(x: 0, y: 54), rotation: 0, unit: 36)
        #expect(placed.surfaceTop(over: -30...(-10)) == 108)
        #expect(placed.surfaceTop(over: 10...30) == 36)
        #expect(placed.surfaceTop(over: 100...120) == nil)
    }

    @Test func aPieceRestingInTheNotchOfAnotherCounts() {
        // An L, and a single square sitting on its foot, beside the tall column.
        let l = Build.piece(0, .stone, .l, floor: 0)
        let square = Build.piece(1, .stone, .mono, x: 0.5, floor: 1)
        let tower = Build.tower([l, square])
        #expect(tower.rests(square, on: l))
        #expect(tower.blocksAbove(l) == [1])
    }

    @Test func aPieceAgainstTheSideOfAnotherDoesNotRestOnIt() {
        let l = Build.piece(0, .stone, .l, floor: 0)
        let beside = Build.piece(1, .stone, .mono, x: -1.5, floor: 1)
        #expect(!Build.tower([l, beside]).rests(beside, on: l))
    }
}
