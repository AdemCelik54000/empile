import CoreGraphics
import Foundation

/// Motion limits under which a body counts as still.
struct CalmThreshold: Equatable, Sendable {
    /// Points per second.
    let linearSpeed: CGFloat
    /// Radians per second.
    let angularSpeed: CGFloat

    func isCalm(speed: CGFloat, angularSpeed: CGFloat) -> Bool {
        speed < linearSpeed && abs(angularSpeed) < self.angularSpeed
    }
}

/// Decides when something has stayed calm long enough to count as settled.
/// Any movement above the threshold restarts the wait.
struct SettleTimer: Sendable {
    let requiredDuration: TimeInterval
    private(set) var calmDuration: TimeInterval = 0

    var isSettled: Bool { calmDuration >= requiredDuration }

    mutating func record(isCalm: Bool, deltaTime: TimeInterval) {
        calmDuration = isCalm ? calmDuration + deltaTime : 0
    }
}
