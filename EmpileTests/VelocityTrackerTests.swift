import CoreGraphics
import Testing
@testable import Empile

@Suite("Finger velocity at release")
struct VelocityTrackerTests {
    private func tracker() -> VelocityTracker {
        VelocityTracker(window: 0.08, capacity: 32)
    }

    @Test func steadySwipe() {
        var tracker = tracker()
        for frame in 0...12 {
            let time = Double(frame) / 120
            tracker.add(CGPoint(x: 300 * time, y: 0), at: time)
        }
        #expect(abs(tracker.velocity.dx - 300) < 0.001)
        #expect(tracker.velocity.dy == 0)
    }

    @Test func fingerThatStoppedBeforeReleasingGivesNoThrow() {
        var tracker = tracker()
        tracker.add(CGPoint(x: 0, y: 0), at: 0)
        tracker.add(CGPoint(x: 50, y: 0), at: 0.05)
        tracker.add(CGPoint(x: 50, y: 0), at: 0.4)
        #expect(tracker.velocity == .zero)
    }

    @Test func onlyRecentMotionCounts() {
        var tracker = tracker()
        tracker.add(CGPoint(x: 0, y: 0), at: 0)
        tracker.add(CGPoint(x: 1000, y: 0), at: 0.01)
        tracker.add(CGPoint(x: 1000, y: 0), at: 0.5)
        tracker.add(CGPoint(x: 1010, y: 0), at: 0.55)
        #expect(abs(tracker.velocity.dx - 200) < 0.001)
    }

    @Test func singleTouchHasNoVelocity() {
        var tracker = tracker()
        tracker.add(CGPoint(x: 10, y: 10), at: 1)
        #expect(tracker.velocity == .zero)
    }

    @Test func resetForgetsThePreviousDrag() {
        var tracker = tracker()
        tracker.add(CGPoint(x: 0, y: 0), at: 0)
        tracker.add(CGPoint(x: 30, y: 0), at: 0.02)
        tracker.reset()
        tracker.add(CGPoint(x: 30, y: 0), at: 0.03)
        #expect(tracker.velocity == .zero)
    }

    @Test func survivesMoreSamplesThanItsCapacity() {
        var tracker = VelocityTracker(window: 1, capacity: 4)
        for frame in 0..<20 {
            let time = Double(frame) / 100
            tracker.add(CGPoint(x: 0, y: -100 * time), at: time)
        }
        #expect(abs(tracker.velocity.dy + 100) < 0.001)
    }
}
