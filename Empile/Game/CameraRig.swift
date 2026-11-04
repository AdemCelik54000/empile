import SpriteKit

/// The camera: glides up with the tower, zooms out a little so the top and the platform stay in view,
/// and shakes very slightly on strong impacts.
@MainActor
final class CameraRig {
    let node = SKCameraNode()
    private(set) var viewport = CameraFraming.Viewport(size: .zero, topInset: 0, bottomInset: 0)
    private let framing = CameraFraming(
        headroom: Tuning.Camera.headroom,
        floorMargin: Tuning.Camera.floorMargin,
        maxScale: Tuning.Camera.maxZoomOut
    )
    /// Where the camera looks, before any shake.
    private var focusY: CGFloat = 0
    /// The zoom the framing asks for, before the sideways peek zooms out a little more.
    private var baseScale: CGFloat = 1
    /// -1...1: the camera peeks towards the left or the right.
    private(set) var sidePush: CGFloat = 0
    /// Remaining shake, 0...1. Fades out over `Tuning.Juice.shakeDuration`.
    private var trauma: CGFloat = 0
    private var shakeClock: TimeInterval = 0

    /// The end of a game: the camera slowly pulls back until the whole tower is in view.
    var showsWholeTower = false

    var scale: CGFloat { node.xScale }

    /// World rectangle currently on screen.
    var visibleRect: CGRect {
        let width = viewport.size.width * scale
        let height = viewport.size.height * scale
        return CGRect(x: node.position.x - width / 2, y: node.position.y - height / 2, width: width, height: height)
    }

    /// Jumps straight to the right framing, for the first layout.
    func snap(to viewport: CameraFraming.Viewport, towerTop: CGFloat) {
        self.viewport = viewport
        let shot = framing.shot(towerTop: towerTop, platformTop: Platform.surfaceY, viewport: viewport)
        focusY = shot.centerY
        baseScale = shot.scale
        trauma = 0
        node.position = CGPoint(x: 0, y: focusY)
        node.setScale(baseScale)
    }

    /// Peeks to a side: the camera moves over and zooms out a little. 0 is the normal view.
    func nudge(_ push: CGFloat) {
        sidePush = push.clamped(to: -1...1)
    }

    /// Changes the screen area to frame for; the camera eases to it on the next frames.
    func setViewport(_ viewport: CameraFraming.Viewport) {
        self.viewport = viewport
    }

    /// Eases toward the right framing. Position and zoom share one blend,
    /// so the platform stays pinned on screen while the camera zooms out.
    func follow(towerTop: CGFloat, deltaTime: TimeInterval) {
        let shot = showsWholeTower
            ? framing.overview(towerTop: towerTop, platformTop: Platform.surfaceY, viewport: viewport)
            : framing.shot(towerTop: towerTop, platformTop: Platform.surfaceY, viewport: viewport)
        let sharpness = showsWholeTower ? Tuning.Camera.overviewSharpness : Tuning.Camera.sharpness
        let blend = Smoothing.blend(sharpness: sharpness, deltaTime: deltaTime)
        focusY += (shot.centerY - focusY) * blend
        baseScale += (shot.scale - baseScale) * blend
        node.setScale(baseScale * (1 + Tuning.Camera.edgeZoomOut * abs(sidePush)))
        let shake = shakeOffset(deltaTime: deltaTime)
        node.position = CGPoint(x: shake.dx + sidePush * Tuning.Camera.edgePan * scale, y: focusY + shake.dy)
    }

    /// - Parameter strength: 0...1. A stronger shake replaces a weaker one still running.
    func shake(strength: CGFloat) {
        trauma = max(trauma, strength.clamped(to: 0...1))
    }

    private func shakeOffset(deltaTime: TimeInterval) -> CGVector {
        guard trauma > 0 else { return .zero }
        shakeClock += deltaTime
        trauma = max(0, trauma - CGFloat(deltaTime / Tuning.Juice.shakeDuration))
        // Squared, so the shake dies off quickly instead of lingering.
        let amplitude = Tuning.Juice.shakeAmplitude * trauma * trauma * scale
        let phase = 2 * .pi * Tuning.Juice.shakeFrequency * shakeClock
        return CGVector(
            dx: amplitude * CGFloat(sin(phase)),
            dy: amplitude * CGFloat(cos(phase * Tuning.Juice.shakeVerticalRatio))
        )
    }
}
