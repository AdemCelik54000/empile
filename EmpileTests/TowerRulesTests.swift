import CoreGraphics
import Testing
@testable import Empile

@Suite("What rests on what, and when glass breaks")
struct TowerRulesTests {
    typealias Build = TowerBuilder

    @Test func aBlockOnTopRestsOnTheOneBelow() {
        let lower = Build.block(0, .stone, floor: 0)
        let upper = Build.block(1, .stone, floor: 1)
        let tower = Build.tower([lower, upper])
        #expect(tower.rests(upper, on: lower))
        #expect(!tower.rests(lower, on: upper))
    }

    @Test func blocksSideBySideDoNotRestOnEachOther() {
        let left = Build.block(0, .stone, x: -1, floor: 0)
        let right = Build.block(1, .stone, x: 1, floor: 0)
        let tower = Build.tower([left, right])
        #expect(!tower.rests(left, on: right))
        #expect(!tower.rests(right, on: left))
    }

    @Test func aBlockFloatingAboveRestsOnNothing() {
        let lower = Build.block(0, .stone, floor: 0)
        let floating = Build.block(1, .stone, floor: 2)
        #expect(!Build.tower([lower, floating]).rests(floating, on: lower))
    }

    @Test func aSlightlyTiltedBlockStillRestsOnItsSupport() {
        let lower = Build.block(0, .stone, columns: 3, floor: 0)
        let rotation: CGFloat = 0.05
        let lift = BlockGeometry.verticalHalfExtent(size: CGSize(width: 72, height: 36), rotation: rotation)
        let tilted = TowerSnapshot.Block(id: 1, kind: .stone, placement: PlacedShape(
            shape: .domino, center: CGPoint(x: 0, y: 36 + lift), rotation: rotation, unit: 36))
        #expect(Build.tower([lower, tilted]).rests(tilted, on: lower))
    }

    @Test func blocksAboveIncludesEverythingStackedOnTop() {
        let blocks = Build.column(of: .stone, count: 4)
        let tower = Build.tower(blocks)
        #expect(tower.blocksAbove(blocks[0]) == [1, 2, 3])
        #expect(tower.blocksAbove(blocks[3]).isEmpty)
    }

    @Test func glassHoldsThreeBlocks() {
        let blocks = [Build.block(0, .glass, floor: 0)] + Build.column(of: .stone, count: 3, firstID: 1, floor: 1)
        #expect(PowerRules.overloadedBlocks(in: Build.tower(blocks), maxLoad: 3).isEmpty)
    }

    @Test func glassBreaksUnderAFourthBlock() {
        let blocks = [Build.block(0, .glass, floor: 0)] + Build.column(of: .stone, count: 4, firstID: 1, floor: 1)
        #expect(PowerRules.overloadedBlocks(in: Build.tower(blocks), maxLoad: 3) == [0])
    }

    @Test func frozenGlassNeverBreaks() {
        let blocks = [Build.block(0, .glass, floor: 0)] + Build.column(of: .stone, count: 4, firstID: 1, floor: 1)
        #expect(PowerRules.overloadedBlocks(in: Build.tower(blocks), maxLoad: 3, ignoring: [0]).isEmpty)
    }

    @Test func onlyBlocksRestingOnTheGlassWeighOnIt() {
        // Four stones, but two of them stand beside the glass on the platform.
        let blocks = [
            Build.block(0, .glass, x: -2, floor: 0),
            Build.block(1, .stone, x: -2, floor: 1),
            Build.block(2, .stone, x: -2, floor: 2),
            Build.block(3, .stone, x: 2, floor: 0),
            Build.block(4, .stone, x: 2, floor: 1),
        ]
        #expect(PowerRules.overloadedBlocks(in: Build.tower(blocks), maxLoad: 3).isEmpty)
    }

    @Test func separationIsZeroForTouchingBlocksAndPositiveForApartOnes() {
        let size = CGSize(width: 72, height: 36)
        let touching = BlockGeometry.separation(centerA: CGPoint(x: 0, y: 18), sizeA: size, rotationA: 0,
                                                centerB: CGPoint(x: 0, y: 54), sizeB: size, rotationB: 0)
        let apart = BlockGeometry.separation(centerA: CGPoint(x: 0, y: 18), sizeA: size, rotationA: 0,
                                             centerB: CGPoint(x: 0, y: 64), sizeB: size, rotationB: 0)
        #expect(abs(touching) < 1e-9)
        #expect(abs(apart - 10) < 1e-9)
    }
}
