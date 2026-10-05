import CoreGraphics
@testable import Empile

/// Builds towers by hand for the rules tests, in grid units: one floor is one unit high.
enum TowerBuilder {
    static let unit: CGFloat = 36

    /// A flat rectangle whose bottom edge sits on `floor`, centered at `x` units from the platform middle.
    static func block(
        _ id: Int,
        _ kind: BlockKind,
        columns: Int = 2,
        rows: Int = 1,
        x: CGFloat = 0,
        floor: CGFloat
    ) -> TowerSnapshot.Block {
        piece(id, kind, .rectangle(columns: columns, rows: rows), x: x, floor: floor)
    }

    /// Any piece, unturned, its bounding box's bottom on `floor` and centered at `x` units.
    static func piece(
        _ id: Int,
        _ kind: BlockKind,
        _ shape: BlockShape,
        x: CGFloat = 0,
        floor: CGFloat,
        rotation: CGFloat = 0
    ) -> TowerSnapshot.Block {
        let center = CGPoint(x: x * unit, y: (floor + CGFloat(shape.rows) / 2) * unit)
        return TowerSnapshot.Block(id: id, kind: kind,
                                   placement: PlacedShape(shape: shape, center: center, rotation: rotation, unit: unit))
    }

    static func tower(_ blocks: [TowerSnapshot.Block]) -> TowerSnapshot {
        TowerSnapshot(blocks: blocks, unit: unit, contactTolerance: 4)
    }

    /// `count` blocks of one kind stacked straight up, ids from `firstID`, bottom one on `floor`.
    static func column(of kind: BlockKind, count: Int, firstID: Int = 0, floor: CGFloat = 0) -> [TowerSnapshot.Block] {
        (0..<count).map { block(firstID + $0, kind, floor: floor + CGFloat($0)) }
    }
}
