import CoreGraphics
import Foundation

/// Measurements of a rectangle that may be tilted, such as a block resting at an angle.
enum BlockGeometry {
    /// Half of the vertical extent of a `size` rectangle rotated by `rotation` radians.
    static func verticalHalfExtent(size: CGSize, rotation: CGFloat) -> CGFloat {
        abs(size.width / 2 * sin(rotation)) + abs(size.height / 2 * cos(rotation))
    }

    /// Half of the horizontal extent of a `size` rectangle rotated by `rotation` radians.
    static func horizontalHalfExtent(size: CGSize, rotation: CGFloat) -> CGFloat {
        abs(size.width / 2 * cos(rotation)) + abs(size.height / 2 * sin(rotation))
    }

    /// Distance between two rectangles along the axis that separates them best (separating axis test).
    /// Positive: they are apart by at least that much. Zero or negative: they touch or overlap.
    static func separation(
        centerA: CGPoint, sizeA: CGSize, rotationA: CGFloat,
        centerB: CGPoint, sizeB: CGSize, rotationB: CGFloat
    ) -> CGFloat {
        let axes = [rotationA, rotationA + .pi / 2, rotationB, rotationB + .pi / 2]
        var largestGap = -CGFloat.infinity
        for angle in axes {
            let axis = CGVector(dx: cos(angle), dy: sin(angle))
            let a = projection(center: centerA, size: sizeA, rotation: rotationA, on: axis)
            let b = projection(center: centerB, size: sizeB, rotation: rotationB, on: axis)
            largestGap = max(largestGap, b.lowerBound - a.upperBound, a.lowerBound - b.upperBound)
        }
        return largestGap
    }

    /// Highest point of the rectangle.
    static func topY(center: CGPoint, size: CGSize, rotation: CGFloat) -> CGFloat {
        center.y + verticalHalfExtent(size: size, rotation: rotation)
    }

    /// Highest point of the rectangle within a horizontal span, or `nil` when the span misses it.
    /// This is where something falling straight down over that span would first touch it.
    static func surfaceTop(
        center: CGPoint,
        size: CGSize,
        rotation: CGFloat,
        over span: ClosedRange<CGFloat>
    ) -> CGFloat? {
        let cosine = cos(rotation)
        let sine = sin(rotation)

        // Corners counter-clockwise from bottom-left.
        func corner(_ index: Int) -> CGPoint {
            let x = (index == 1 || index == 2) ? size.width / 2 : -size.width / 2
            let y = index >= 2 ? size.height / 2 : -size.height / 2
            return CGPoint(x: center.x + x * cosine - y * sine, y: center.y + x * sine + y * cosine)
        }

        // The rectangle is convex, so its highest point over the span lies on an edge, at an end of the
        // portion of that edge inside the span.
        var highest: CGFloat?
        for index in 0..<4 {
            let start = corner(index)
            let end = corner((index + 1) % 4)
            let lower = max(min(start.x, end.x), span.lowerBound)
            let upper = min(max(start.x, end.x), span.upperBound)
            guard lower <= upper else { continue }
            let edgeTop = highestY(onEdgeFrom: start, to: end, between: lower, and: upper)
            highest = max(highest ?? edgeTop, edgeTop)
        }
        return highest
    }

    private static func projection(
        center: CGPoint,
        size: CGSize,
        rotation: CGFloat,
        on axis: CGVector
    ) -> ClosedRange<CGFloat> {
        let middle = center.x * axis.dx + center.y * axis.dy
        let radius = abs(size.width / 2 * (cos(rotation) * axis.dx + sin(rotation) * axis.dy))
            + abs(size.height / 2 * (-sin(rotation) * axis.dx + cos(rotation) * axis.dy))
        return (middle - radius)...(middle + radius)
    }

    private static func highestY(
        onEdgeFrom start: CGPoint,
        to end: CGPoint,
        between lower: CGFloat,
        and upper: CGFloat
    ) -> CGFloat {
        let run = end.x - start.x
        guard run != 0 else { return max(start.y, end.y) }
        let slope = (end.y - start.y) / run
        return max(start.y + (lower - start.x) * slope, start.y + (upper - start.x) * slope)
    }
}
