import CoreGraphics
import Foundation

/// Measures how fast the finger moved just before now, from recent touch samples.
/// Storage is allocated once, so tracking a drag never allocates.
struct VelocityTracker: Sendable {
    private struct Sample: Sendable {
        var point: CGPoint
        var time: TimeInterval
    }

    private let window: TimeInterval
    private var samples: [Sample]
    private var newest = 0
    private var count = 0

    init(window: TimeInterval, capacity: Int) {
        self.window = window
        samples = Array(repeating: Sample(point: .zero, time: 0), count: max(capacity, 2))
    }

    mutating func reset() {
        count = 0
    }

    mutating func add(_ point: CGPoint, at time: TimeInterval) {
        newest = (newest + 1) % samples.count
        samples[newest] = Sample(point: point, time: time)
        count = min(count + 1, samples.count)
    }

    /// Average velocity over the last `window` seconds. Zero when the finger rested before the latest sample.
    var velocity: CGVector {
        guard count > 1 else { return .zero }
        let latest = samples[newest]
        var oldest = latest
        for age in 1..<count {
            let sample = samples[(newest - age + samples.count) % samples.count]
            guard latest.time - sample.time <= window else { break }
            oldest = sample
        }
        let elapsed = latest.time - oldest.time
        guard elapsed > 0 else { return .zero }
        return CGVector(
            dx: (latest.point.x - oldest.point.x) / elapsed,
            dy: (latest.point.y - oldest.point.y) / elapsed
        )
    }
}
