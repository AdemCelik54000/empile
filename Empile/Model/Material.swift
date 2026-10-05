import CoreGraphics

/// How a block behaves physically, independent of any physics engine.
/// The values for each block type live in `Tuning.Materials`.
struct Material: Equatable, Sendable {
    /// Mass per unit of area. Higher means heavier at the same size.
    let density: CGFloat
    /// 0 = frictionless (ice), 1 = very grippy.
    let friction: CGFloat
    /// Bounciness: 0 = dead stop, 1 = perfectly elastic.
    let restitution: CGFloat
    /// Drag on movement. Kept low so falls still look natural.
    let linearDamping: CGFloat
    /// Drag on rotation. Calms rocking without making tipping look slow.
    let angularDamping: CGFloat
}
