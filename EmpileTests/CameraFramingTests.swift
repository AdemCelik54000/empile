import CoreGraphics
import Testing
@testable import Empile

@Suite("Camera framing")
struct CameraFramingTests {
    let framing = CameraFraming(headroom: 280, floorMargin: 150, maxScale: 1.6)
    // iPhone 17 Pro sized screen: 874 tall, room for the tower at scale 1 is 874 - 62 - 34 - 280 - 150 = 348.
    let viewport = CameraFraming.Viewport(size: CGSize(width: 402, height: 874), topInset: 62, bottomInset: 34)

    /// Screen distance of a world height from the bottom edge.
    private func screenY(of worldY: CGFloat, in shot: CameraFraming.Shot) -> CGFloat {
        (worldY - shot.centerY) / shot.scale + viewport.size.height / 2
    }

    @Test func shortTowerKeepsFullSizeWithPlatformNearTheBottom() {
        let shot = framing.shot(towerTop: 100, platformTop: 0, viewport: viewport)
        #expect(shot.scale == 1)
        #expect(abs(screenY(of: 0, in: shot) - (34 + 150)) < 0.001)
    }

    @Test func growingTowerZoomsOutToKeepTopAndPlatformInView() {
        let shot = framing.shot(towerTop: 500, platformTop: 0, viewport: viewport)
        #expect(shot.scale > 1)
        #expect(shot.scale < 1.6)
        #expect(abs(screenY(of: 0, in: shot) - (34 + 150)) < 0.001)
        #expect(abs(screenY(of: 500, in: shot) - (874 - 62 - 280)) < 0.001)
    }

    @Test func veryTallTowerStopsZoomingAndFollowsTheTop() {
        let shot = framing.shot(towerTop: 2000, platformTop: 0, viewport: viewport)
        #expect(shot.scale == 1.6)
        #expect(abs(screenY(of: 2000, in: shot) - (874 - 62 - 280)) < 0.001)
        #expect(screenY(of: 0, in: shot) < 0)
    }

    @Test func noJumpWhenReachingTheZoomLimit() {
        let limit = 348 * 1.6
        let before = framing.shot(towerTop: limit - 0.01, platformTop: 0, viewport: viewport)
        let after = framing.shot(towerTop: limit + 0.01, platformTop: 0, viewport: viewport)
        #expect(abs(before.centerY - after.centerY) < 0.1)
        #expect(abs(before.scale - after.scale) < 0.001)
    }

    @Test func cameraNeverMovesDownWhenTheTowerGrows() {
        var previous = framing.shot(towerTop: 0, platformTop: 0, viewport: viewport)
        for top in stride(from: CGFloat(20), through: 1500, by: 20) {
            let shot = framing.shot(towerTop: top, platformTop: 0, viewport: viewport)
            #expect(shot.centerY >= previous.centerY)
            #expect(shot.scale >= previous.scale)
            previous = shot
        }
    }
}
