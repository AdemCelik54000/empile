import CoreGraphics

/// Where the camera should look so the player always sees the platform, the tower top,
/// and enough room above it to hold the next block.
struct CameraFraming: Sendable {
    struct Viewport: Equatable, Sendable {
        var size: CGSize
        /// Screen area hidden by the Dynamic Island or the notch.
        var topInset: CGFloat
        /// Screen area taken by the home indicator.
        var bottomInset: CGFloat
    }

    struct Shot: Equatable, Sendable {
        var centerY: CGFloat
        /// 1 = no zoom, above 1 = zoomed out.
        var scale: CGFloat
    }

    /// Screen space kept free above the tower top.
    let headroom: CGFloat
    /// Screen space kept visible below the platform surface.
    let floorMargin: CGFloat
    let maxScale: CGFloat

    func shot(towerTop: CGFloat, platformTop: CGFloat, viewport: Viewport) -> Shot {
        let usableHeight = viewport.size.height - viewport.topInset - viewport.bottomInset
        let roomForTower = usableHeight - headroom - floorMargin
        let towerHeight = max(0, towerTop - platformTop)
        let scale = roomForTower > 0 ? (towerHeight / roomForTower).clamped(to: 1...maxScale) : maxScale
        let halfHeight = viewport.size.height / 2 * scale

        // Keep the platform pinned near the bottom while zooming out is enough; past the zoom limit,
        // follow the top instead. Both agree exactly at the limit, so the switch is seamless.
        let pinnedToPlatform = platformTop - scale * (viewport.bottomInset + floorMargin) + halfHeight
        let followingTop = towerTop + scale * (viewport.topInset + headroom) - halfHeight
        return Shot(centerY: max(pinnedToPlatform, followingTop), scale: scale)
    }
}
