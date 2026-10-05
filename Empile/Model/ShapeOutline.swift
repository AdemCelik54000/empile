/// A corner of a piece's outline, in grid units (origin at the bottom-left of the bounding box, y up).
struct OutlineCorner: Equatable, Sendable {
    let x: Int
    let y: Int
    /// Outward corner (to round generously) rather than an inner notch.
    let isConvex: Bool
}

extension BlockShape {
    /// The outline of the piece, counterclockwise, one corner per change of direction.
    /// Pieces are made of squares that share edges, so the outline is a single loop.
    var outline: [OutlineCorner] {
        let set = Set(cells)
        // Every square edge that is not shared with a neighbour, oriented counterclockwise.
        var next: [Point: Point] = [:]
        for cell in cells {
            let (c, r) = (cell.column, cell.row)
            if !set.contains(GridCell(column: c, row: r - 1)) { next[Point(c, r)] = Point(c + 1, r) }
            if !set.contains(GridCell(column: c + 1, row: r)) { next[Point(c + 1, r)] = Point(c + 1, r + 1) }
            if !set.contains(GridCell(column: c, row: r + 1)) { next[Point(c + 1, r + 1)] = Point(c, r + 1) }
            if !set.contains(GridCell(column: c - 1, row: r)) { next[Point(c, r + 1)] = Point(c, r) }
        }
        guard let start = next.keys.min() else { return [] }
        var loop: [Point] = []
        var current = start
        repeat {
            loop.append(current)
            guard let following = next[current] else { break }
            current = following
        } while current != start && loop.count <= next.count

        // Keep only the points where the outline turns, and note which way it turns.
        var corners: [OutlineCorner] = []
        for index in loop.indices {
            let previous = loop[(index + loop.count - 1) % loop.count]
            let point = loop[index]
            let following = loop[(index + 1) % loop.count]
            let cross = (point.x - previous.x) * (following.y - point.y) - (point.y - previous.y) * (following.x - point.x)
            guard cross != 0 else { continue }
            corners.append(OutlineCorner(x: point.x, y: point.y, isConvex: cross > 0))
        }
        return corners
    }
}

private struct Point: Hashable, Comparable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    static func < (lhs: Point, rhs: Point) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }
}
