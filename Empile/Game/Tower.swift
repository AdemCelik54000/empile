import SpriteKit

/// What changed in the tower during one frame.
struct TowerUpdate {
    /// Every block has just become still.
    var becameStable = false
    /// A block that had landed has just dropped below the platform.
    var placedBlockFellOff = false
    /// Blocks that fell out of sight this frame: each one costs a life.
    var lostBlocks = 0
    /// How close a moving block is to toppling, 0...1.
    var danger: CGFloat = 0
    /// Blocks that have just come to rest for the first time: their placement is ready to be judged.
    var newlySettled: [BlockNode] = []
}

/// The dropped blocks: which ones have settled, how tall the tower stands, which ones are lost,
/// and which ones are frozen for good because the camera has left them behind.
@MainActor
final class Tower {
    private(set) var blocks: [BlockNode] = []
    private var height = TowerHeight(base: Platform.surfaceY)
    /// Top of the highest block that has landed, moving or not. Blocks still in free fall are ignored,
    /// so picking up a new block while the last one is falling does not push it off screen.
    private(set) var landedTop = Platform.surfaceY
    /// True once every block has stayed still for `Tuning.Physics.settleDuration`.
    private(set) var isStable = true
    private var dropCount = 0

    /// Tower height: top of the highest settled block, or the platform surface.
    /// It never dips while blocks shake from an impact (see `TowerHeight`).
    var stableTop: CGFloat { height.top }

    func add(_ block: BlockNode) {
        block.markDropped(order: dropCount)
        dropCount += 1
        blocks.append(block)
    }

    /// Call once per frame, after physics.
    /// - Parameter viewBottom: Lowest world height on screen. A block wholly below it is frozen if it is
    ///   still, and lost if it is falling.
    func update(deltaTime: TimeInterval, viewBottom: CGFloat) -> TowerUpdate {
        var result = TowerUpdate()
        var allSettled = true
        var stable = Platform.surfaceY
        var landed = Platform.surfaceY
        for index in stride(from: blocks.count - 1, through: 0, by: -1) {
            let block = blocks[index]
            if block.isFrozen {
                stable = max(stable, block.topY)
                landed = max(landed, block.topY)
                continue
            }
            let isBelowPlatform = block.position.y < Platform.surfaceY - Tuning.World.lossDepth
            let isFallingOutOfSight = block.topY < viewBottom
                && (block.physicsBody?.velocity.dy ?? 0) < -Tuning.Climb.lostFallSpeed
            guard !isBelowPlatform && !isFallingOutOfSight else {
                blocks.remove(at: index)
                block.vanish()
                result.lostBlocks += 1
                continue
            }
            block.recordMotion(deltaTime: deltaTime)
            let top = block.topY
            if top < viewBottom && block.isSettled {
                block.freeze()
            }
            if block.hasLanded && !block.hasFallenOff && top < Platform.surfaceY {
                block.markFellOff()
                result.placedBlockFellOff = true
            }
            if block.hasLanded {
                landed = max(landed, top)
            }
            if block.isSettled {
                stable = max(stable, top)
                if block.hasLanded && !block.hasFallenOff && !block.isScored {
                    block.markScored()
                    result.newlySettled.append(block)
                }
            } else {
                allSettled = false
                if block.hasLanded && !block.hasFallenOff {
                    let tilt = abs(remainder(block.zRotation, .pi / 2))
                    result.danger = max(result.danger, TensionGauge.danger(forTilt: tilt))
                }
            }
        }

        result.becameStable = allSettled && !isStable
        isStable = allSettled
        height.update(settledTop: stable, isStable: allSettled)
        landedTop = landed
        if result.becameStable && Tuning.Physics.restsWhenStable {
            for block in blocks {
                block.rest()
            }
        }
        return result
    }

    var frozenCardIDs: Set<Card.ID> {
        Set(blocks.filter(\.isFrozen).map(\.cardID))
    }

    /// A dropped block is still in free fall: the next one waits, so two quick drops never start inside
    /// each other.
    var hasBlockInFlight: Bool {
        blocks.contains { !$0.hasLanded }
    }

    /// The tower as the rules see it: every block that has landed and is still on the platform.
    func snapshot() -> TowerSnapshot {
        TowerSnapshot(
            blocks: blocks.filter { $0.hasLanded && !$0.hasFallenOff }.map {
                TowerSnapshot.Block(id: $0.cardID, kind: $0.definition.kind, placement: $0.placement)
            },
            unit: Tuning.World.unit,
            contactTolerance: Tuning.World.contactTolerance
        )
    }

    func block(withCardID id: Card.ID) -> BlockNode? {
        blocks.first { $0.cardID == id }
    }

    /// Takes a piece out at once (shattered glass). The pieces it held are woken up so they fall.
    func remove(_ block: BlockNode) {
        blocks.removeAll { $0 === block }
        block.removeFromParent()
        isStable = false
        for other in blocks {
            other.wake()
        }
    }

    /// Fades every block out and starts again from an empty platform.
    func clear() {
        for block in blocks {
            block.physicsBody = nil
            block.run(.sequence([.fadeOut(withDuration: Tuning.Climb.clearDuration), .removeFromParent()]))
        }
        blocks.removeAll()
        height = TowerHeight(base: Platform.surfaceY)
        landedTop = Platform.surfaceY
        isStable = true
    }

    /// Highest surface below a horizontal span, among the platform and every block that has landed.
    /// `nil` when the span is over the void.
    func landingY(under span: ClosedRange<CGFloat>) -> CGFloat? {
        var landing = BlockGeometry.surfaceTop(
            center: CGPoint(x: Platform.frame.midX, y: Platform.frame.midY),
            size: Platform.frame.size,
            rotation: 0,
            over: span
        )
        for block in blocks where block.hasLanded {
            guard let top = block.placement.surfaceTop(over: span) else { continue }
            landing = max(landing ?? top, top)
        }
        return landing
    }
}
