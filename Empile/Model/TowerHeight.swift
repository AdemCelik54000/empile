import CoreGraphics

/// Tower height as the player sees it.
///
/// It rises as soon as a block settles higher, but only drops once the whole tower is still again.
/// A block landing on top shakes the blocks under it for a moment; without this rule the height would
/// dip during that moment and the camera would zoom in, then back out.
struct TowerHeight: Sendable {
    private(set) var top: CGFloat

    init(base: CGFloat) {
        top = base
    }

    /// - Parameters:
    ///   - settledTop: Top of the highest block that is currently still.
    ///   - isStable: Whether every block is still.
    mutating func update(settledTop: CGFloat, isStable: Bool) {
        top = isStable ? settledTop : max(top, settledTop)
    }
}
