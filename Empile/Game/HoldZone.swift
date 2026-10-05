import CoreGraphics

/// Where the held block may hover: on screen, and always above the tower so it can never overlap it.
struct HoldZone: Equatable, Sendable {
    /// Lowest allowed bottom edge for the held block.
    var floorY: CGFloat
    /// World rectangle the held block must stay inside.
    var bounds: CGRect
    /// Share of the block's width that may stick out of `bounds` sideways (0...1).
    var overhang: CGFloat = 0

    func clamp(_ center: CGPoint, size: CGSize) -> CGPoint {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let outside = size.width * overhang.clamped(to: 0...1)
        let x = bounds.width > size.width
            ? center.x.clamped(to: (bounds.minX + halfWidth - outside)...(bounds.maxX - halfWidth + outside))
            : bounds.midX
        // Staying above the tower wins over staying on screen.
        let lowestY = floorY + halfHeight
        let highestY = max(lowestY, bounds.maxY - halfHeight)
        return CGPoint(x: x, y: center.y.clamped(to: lowestY...highestY))
    }
}
