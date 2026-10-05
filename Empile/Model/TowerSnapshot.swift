import CoreGraphics

/// A piece placed in the world: its squares, where its bounding box is centered, and how it is tilted.
struct PlacedShape: Equatable, Sendable {
    let shape: BlockShape
    let center: CGPoint
    let rotation: CGFloat
    let unit: CGFloat

    var cellSize: CGSize { CGSize(width: unit, height: unit) }

    /// World center of one of its squares.
    func center(of cell: GridCell) -> CGPoint {
        let offset = shape.offset(of: cell, unit: unit)
        let cosine = cos(rotation)
        let sine = sin(rotation)
        return CGPoint(x: center.x + offset.x * cosine - offset.y * sine,
                       y: center.y + offset.x * sine + offset.y * cosine)
    }

    /// Highest point of the piece.
    var topY: CGFloat {
        shape.cells.reduce(-CGFloat.infinity) {
            max($0, BlockGeometry.topY(center: center(of: $1), size: cellSize, rotation: rotation))
        }
    }

    /// Lowest point of the piece.
    var bottomY: CGFloat {
        shape.cells.reduce(CGFloat.infinity) {
            min($0, center(of: $1).y - BlockGeometry.verticalHalfExtent(size: cellSize, rotation: rotation))
        }
    }

    /// Highest point of the piece over a horizontal span, or `nil` when the span misses it.
    func surfaceTop(over span: ClosedRange<CGFloat>) -> CGFloat? {
        var highest: CGFloat?
        for cell in shape.cells {
            guard let top = BlockGeometry.surfaceTop(center: center(of: cell), size: cellSize,
                                                     rotation: rotation, over: span)
            else { continue }
            highest = max(highest ?? top, top)
        }
        return highest
    }
}

/// The tower as the rules see it: which piece sits where. The game builds one whenever the tower is still;
/// tests build them by hand. Everything about stacking (what rests on what) is derived from the squares.
struct TowerSnapshot: Sendable {
    struct Block: Equatable, Sendable {
        let id: Int
        let kind: BlockKind
        let placement: PlacedShape

        var shape: BlockShape { placement.shape }
        var center: CGPoint { placement.center }
        var topY: CGFloat { placement.topY }
    }

    let blocks: [Block]
    /// Height of one floor.
    let unit: CGFloat
    /// Squares closer than this count as touching.
    let contactTolerance: CGFloat

    /// Whether `upper` rests on `lower`: one of its squares touches one of `lower`'s from above.
    /// Two pieces side by side touch but do not rest on each other.
    func rests(_ upper: Block, on lower: Block) -> Bool {
        contactWidth(of: upper, on: lower) > 0
    }

    /// Share of the squares on the underside of `block` (those with nothing of the same piece right below them)
    /// that rest on another piece or on the ground, 0...1. A square counts as resting when another square
    /// covers at least half of it from below.
    /// - Parameters:
    ///   - groundY: Height of the platform surface.
    ///   - groundSpan: Horizontal extent of the platform.
    ///   - gap: Vertical distance under which two squares count as touching.
    func supportedShare(of block: Block, groundY: CGFloat, groundSpan: ClosedRange<CGFloat>, gap: CGFloat) -> Double {
        let half = unit / 2
        let ownCenters = block.shape.cells.map { block.placement.center(of: $0) }
        let underside = ownCenters.filter { center in
            !ownCenters.contains { abs($0.x - center.x) <= half && abs(center.y - $0.y - unit) <= gap }
        }
        guard !underside.isEmpty else { return 0 }
        let others = blocks.filter { $0.id != block.id }.flatMap { other in
            other.shape.cells.map { other.placement.center(of: $0) }
        }
        let supported = underside.filter { center in
            let bottom = center.y - half
            if abs(bottom - groundY) <= gap && groundSpan.contains(center.x) {
                return true
            }
            return others.contains { abs($0.x - center.x) <= half && abs($0.y + half - bottom) <= gap }
        }
        return Double(supported.count) / Double(underside.count)
    }

    /// Every piece resting on `block`, directly or through other pieces.
    func blocksAbove(_ block: Block) -> Set<Int> {
        var found: Set<Int> = []
        var frontier = [block]
        while let current = frontier.popLast() {
            for candidate in blocks where !found.contains(candidate.id) && rests(candidate, on: current) {
                found.insert(candidate.id)
                frontier.append(candidate)
            }
        }
        return found
    }

    /// How much `upper` leans on `lower`: the horizontal overlap of every pair of squares where one of `upper`
    /// touches one of `lower` from above. Zero when it does not rest on it.
    private func contactWidth(of upper: Block, on lower: Block) -> CGFloat {
        guard upper.id != lower.id else { return 0 }
        let size = upper.placement.cellSize
        let halfHeight = unit / 2
        var width: CGFloat = 0
        for upperCell in upper.shape.cells {
            let top = upper.placement.center(of: upperCell)
            for lowerCell in lower.shape.cells {
                let bottom = lower.placement.center(of: lowerCell)
                guard top.y - halfHeight >= bottom.y - contactTolerance,
                      BlockGeometry.separation(
                        centerA: top, sizeA: size, rotationA: upper.placement.rotation,
                        centerB: bottom, sizeB: size, rotationB: lower.placement.rotation
                      ) <= contactTolerance
                else { continue }
                width += max(0, unit - abs(top.x - bottom.x))
            }
        }
        return width
    }
}
