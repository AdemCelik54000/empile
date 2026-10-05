import CoreGraphics

/// How well a piece was placed, judged once it has settled.
enum PlacementQuality: Equatable, Sendable {
    /// Flat, and every square of its underside rests on something: the combo grows.
    case perfect
    /// Flat enough and mostly supported: the combo holds.
    case good
    /// Tilted or overhanging: the combo breaks.
    case sloppy

    /// - Parameters:
    ///   - tilt: How far the piece leans from straight, in radians.
    ///   - supportedShare: Share of the squares of its underside that rest on something, 0...1.
    static func judge(tilt: CGFloat, supportedShare: Double) -> PlacementQuality {
        let rules = Tuning.Score.self
        if tilt <= rules.perfectTilt && supportedShare >= 1 {
            return .perfect
        }
        if tilt <= rules.goodTilt && supportedShare >= rules.goodSupport {
            return .good
        }
        return .sloppy
    }
}

/// Perfect placements in a row. Each one raises the multiplier a step, up to a cap; a sloppy one or a lost
/// piece starts over.
struct Combo: Equatable, Sendable {
    private(set) var streak = 0

    var multiplier: Double {
        1 + Tuning.Score.comboStep * Double(min(streak, Tuning.Score.maxComboStreak))
    }

    mutating func record(_ quality: PlacementQuality) {
        switch quality {
        case .perfect: streak += 1
        case .good: break
        case .sloppy: streak = 0
        }
    }

    mutating func reset() {
        streak = 0
    }
}

/// The points one piece earned, and why.
struct PlacementScore: Equatable, Sendable {
    /// Points of the piece itself: its squares times its material.
    let base: Int
    let quality: PlacementQuality
    /// Combo multiplier applied, once this placement is counted.
    let multiplier: Double
    /// Perfect placements in a row, this one included.
    let streak: Int

    var points: Int { Int((Double(base) * multiplier).rounded()) }

    /// - Parameter combo: The combo once this placement is recorded in it.
    init(kind: BlockKind, shape: BlockShape, quality: PlacementQuality, combo: Combo) {
        base = shape.area * BlockCatalog.definition(for: kind).pointsPerCell
        self.quality = quality
        multiplier = combo.multiplier
        streak = combo.streak
    }
}
