import CoreGraphics
import Testing
@testable import Empile

@Suite("Where the held block may hover")
struct HoldZoneTests {
    let zone = HoldZone(floorY: 200, bounds: CGRect(x: -200, y: -100, width: 400, height: 800))
    let block = CGSize(width: 72, height: 36)

    @Test func freePositionIsKept() {
        let point = CGPoint(x: 10, y: 400)
        #expect(zone.clamp(point, size: block) == point)
    }

    @Test func neverDipsIntoTheTower() {
        let justAboveTower: CGFloat = 200 + 18
        #expect(zone.clamp(CGPoint(x: 0, y: 0), size: block).y == justAboveTower)
    }

    @Test func staysOnScreenSideways() {
        let leftmost: CGFloat = -200 + 36
        let rightmost: CGFloat = 200 - 36
        #expect(zone.clamp(CGPoint(x: -500, y: 400), size: block).x == leftmost)
        #expect(zone.clamp(CGPoint(x: 500, y: 400), size: block).x == rightmost)
    }

    @Test func staysBelowTheTopOfTheScreen() {
        let highest: CGFloat = 700 - 18
        #expect(zone.clamp(CGPoint(x: 0, y: 2000), size: block).y == highest)
    }

    @Test func clearingTheTowerWinsOverStayingOnScreen() {
        let crowded = HoldZone(floorY: 690, bounds: zone.bounds)
        let justAboveTower: CGFloat = 690 + 18
        #expect(crowded.clamp(CGPoint(x: 0, y: 2000), size: block).y == justAboveTower)
    }

    @Test func blockWiderThanTheScreenIsCentered() {
        let narrow = HoldZone(floorY: 0, bounds: CGRect(x: 0, y: 0, width: 50, height: 500))
        #expect(narrow.clamp(CGPoint(x: 400, y: 100), size: block).x == 25)
    }

    @Test func peekingLetsTwoThirdsOfTheBlockStickOut() {
        let peeking = HoldZone(floorY: 200, bounds: zone.bounds, overhang: 2.0 / 3.0)
        let rightmost: CGFloat = 200 - 36 + 48
        #expect(abs(peeking.clamp(CGPoint(x: 500, y: 400), size: block).x - rightmost) < 0.001)
        #expect(abs(peeking.clamp(CGPoint(x: -500, y: 400), size: block).x - (-200 + 36 - 48)) < 0.001)
    }
}
