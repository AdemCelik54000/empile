import CoreGraphics

/// Drawing order. The view ignores sibling order, so every node gets an explicit depth.
enum Layer {
    static let background: CGFloat = -100
    static let pillar: CGFloat = -10
    static let platform: CGFloat = 0
    static let guide: CGFloat = 5
    static let droppedBlocks: CGFloat = 10
    /// Dust rises in front of the blocks.
    static let dust: CGFloat = 50
    /// Wind streaks blow in front of the tower.
    static let wind: CGFloat = 80
    /// A perched bird stands in front of its piece.
    static let bird: CGFloat = 90
    /// Floating points and sparkles, in front of everything in the world but the held block.
    static let effects: CGFloat = 95
    static let heldBlock: CGFloat = 100
    /// Depth added per drop: later blocks draw above earlier ones, so shadows fall on the blocks below.
    static let dropStep: CGFloat = 0.001

    static func droppedBlock(order: Int) -> CGFloat {
        droppedBlocks + CGFloat(order) * dropStep
    }
}

enum PhysicsCategory {
    static let block: UInt32 = 1 << 0
    static let platform: UInt32 = 1 << 1
}

/// Timing curves for SpriteKit actions.
enum Easing {
    /// Ease-out with a small overshoot, like a light spring.
    static func backOut(_ time: Float) -> Float {
        let overshoot = Tuning.Look.springOvershoot
        let shifted = time - 1
        return shifted * shifted * ((overshoot + 1) * shifted + overshoot) + 1
    }
}

extension CGSize {
    /// Grows the size by `amount` on every side.
    func outset(by amount: CGFloat) -> CGSize {
        CGSize(width: width + 2 * amount, height: height + 2 * amount)
    }
}
