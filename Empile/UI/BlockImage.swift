import SwiftUI

/// A block drawn exactly as in the game, with `unit` points per grid cell (its soft shadow included).
struct BlockImage: View {
    let scene: TowerScene
    let kind: BlockKind
    let shape: BlockShape
    let unit: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let scale = unit / Tuning.World.unit
        let size = TextureFactory.spriteSize(for: shape)
        Image(uiImage: scene.preview(
            of: kind,
            shape: shape,
            style: colorScheme == .dark ? .dark : .light,
            displayScale: displayScale * max(1, scale)
        ))
        .resizable()
        .interpolation(.high)
        .frame(width: size.width * scale, height: size.height * scale)
        .accessibilityHidden(true)
    }

    /// Blocks are drawn with room for their shadow; overlap by this much to make stacked blocks touch.
    static func shadowOverlap(unit: CGFloat) -> CGFloat {
        -2 * Tuning.Look.shadowPadding * unit / Tuning.World.unit
    }
}
