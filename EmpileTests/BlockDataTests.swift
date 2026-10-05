import CoreGraphics
import Testing
@testable import Empile

@Suite("Block data")
struct BlockDataTests {
    @Test(arguments: BlockCatalog.all)
    func materialsStayWithinPhysicalRanges(definition: BlockDefinition) {
        let material = definition.material
        #expect(material.density > 0)
        #expect((0...1).contains(material.friction))
        #expect((0...1).contains(material.restitution))
        #expect(material.linearDamping >= 0)
        #expect(material.angularDamping >= 0)
    }

    @Test func stoneSlidesALittleButBarelyBounces() {
        let stone = BlockCatalog.stone.material
        #expect((0.3...0.7).contains(stone.friction))
        #expect(stone.restitution <= 0.1)
        #expect(stone.angularDamping > 0)
    }

    @Test func quarterTurnSwapsTheFootprint() {
        let plank = BlockShape.rectangle(columns: 3, rows: 1)
        #expect(plank.quarterTurned == BlockShape.rectangle(columns: 1, rows: 3))
        #expect(plank.quarterTurned.quarterTurned == plank)
        #expect(!plank.isTurnInvariant)
        #expect(BlockShape.square.isTurnInvariant)
    }

    @Test func sizeFollowsTheGrid() {
        #expect(BlockShape.rectangle(columns: 3, rows: 1).size(unit: 36) == CGSize(width: 108, height: 36))
    }

    @Test func everyKindHasADefinition() {
        for kind in BlockKind.allCases {
            #expect(BlockCatalog.definition(for: kind).kind == kind)
        }
    }

    @Test func glassIsSlipperyAndSpringIsLight() {
        #expect(BlockCatalog.glass.material.friction < BlockCatalog.stone.material.friction)
        #expect(BlockCatalog.spring.material.density < BlockCatalog.stone.material.density)
    }

    @Test func goldIsTheHeaviestAndGrippiestAnchor() {
        let others = BlockCatalog.all.filter { $0.kind != .gold }
        #expect(others.allSatisfy { $0.material.density < BlockCatalog.gold.material.density })
        #expect(others.allSatisfy { $0.material.friction <= BlockCatalog.gold.material.friction })
    }
}
