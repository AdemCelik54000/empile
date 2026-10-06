import SpriteKit

/// The wind in the world: streaks blowing across the screen, and the push on the pieces it actually reaches.
///
/// The wind blows in horizontal rows. Each row hits the first thing in its way and stops there, so a solid wall
/// shelters whatever stands behind it. The streaks follow the same rule: they bend over and under the pieces
/// they meet, so their shape shows where the wind goes. Frozen pieces, left behind below the screen, are static
/// bodies: they still block the wind, but never feel it.
@MainActor
final class WindEffect {
    /// One line of wind: a head moving downwind, and the trail of where it went.
    private struct Streak {
        var trail: [CGPoint]
        var head: CGPoint
        var verticalSpeed: CGFloat = 0
        var age: CGFloat = 0
        var isDying = false
        var fade: CGFloat = 1
        let line: SKShapeNode
    }

    /// Lives in the world, so the streaks meet the pieces where they really are.
    let node = SKNode()
    private var streaks: [Streak] = []
    private var spare: [SKShapeNode] = []
    private var color = UIColor.white
    private var pendingSpawns: CGFloat = 0

    init() {
        node.zPosition = Layer.wind
    }

    func refresh(using textures: TextureFactory) {
        color = textures.resolve(Palette.wind)
    }

    /// Streaks from the side the wind comes from: a few while it rises, many while it blows. Each one moves
    /// downwind and bends around the pieces in its way.
    func show(_ wind: WindState, visible: CGRect, viewWidth: CGFloat, deltaTime: TimeInterval, in scene: SKScene) {
        let tuning = Tuning.Wind.self
        let share: CGFloat = switch wind.phase {
        case .calm: 0
        case .warning: tuning.warningStreakShare
        case .blowing: max(tuning.warningStreakShare, wind.strength)
        }
        let step = CGFloat(deltaTime)
        let scale = viewWidth > 0 ? visible.width / viewWidth : 1
        let crossing = visible.width * (1 + tuning.streakStartOffset) / tuning.streakLifetime
        let speed = crossing * (tuning.streakBaseSpeed + (1 - tuning.streakBaseSpeed) * share)
        let direction: CGFloat = wind.direction > 0 ? 1 : -1

        if share > 0 {
            pendingSpawns += tuning.maxStreaksPerSecond * share * step
            while pendingSpawns >= 1 {
                pendingSpawns -= 1
                spawn(in: visible, direction: direction, scene: scene)
            }
        } else {
            pendingSpawns = 0
        }

        let opacity = tuning.streakOpacity * max(share, tuning.warningStreakShare)
        for index in streaks.indices.reversed() {
            advance(&streaks[index], speed: speed, direction: direction, deltaTime: step, scale: scale, scene: scene)
            let streak = streaks[index]
            let downwindEdge = direction > 0 ? visible.maxX : visible.minX
            let isPast = (streak.head.x - downwindEdge) * direction > tuning.streakLength * scale
            if streak.isDying && streak.fade <= 0 || isPast || streak.age > tuning.streakLifetime * 3 {
                retire(at: index)
                continue
            }
            draw(streak, opacity: share > 0 ? opacity : opacity * streak.fade, scale: scale)
        }
    }

    /// Pushes the pieces the wind reaches. Each row of wind pushes the first piece in its way, where it hits it:
    /// a piece behind a solid wall is sheltered, a tall exposed face catches a lot, and the push lands where the
    /// wind meets the piece, so a thin pile tips over while a wide, well-built one holds.
    /// - Parameter pressure: Push at the peak of the gust on a row of wind, as a share of the weight of a slice
    ///   of stone as tall as the row and `catchDepth` deep.
    func push(_ blocks: [BlockNode], wind: WindState, pressure: CGFloat, gravity: CGFloat, in scene: SKScene) {
        guard wind.phase == .blowing, wind.strength > 0 else { return }
        let tuning = Tuning.Wind.self
        var span = CGRect.null
        for block in blocks where !block.isFrozen && block.physicsBody?.isDynamic == true && block.parent != nil {
            span = span.union(block.calculateAccumulatedFrame())
        }
        guard !span.isNull else { return }
        let direction: CGFloat = wind.direction > 0 ? 1 : -1
        let reach = span.insetBy(dx: -tuning.rayMargin, dy: 0)
        let start = direction > 0 ? reach.minX : reach.maxX
        let end = direction > 0 ? reach.maxX : reach.minX
        // A row of wind weighs like a slice of stone `rowSpacing` tall and `catchDepth` deep; `area × density`
        // is exactly how the engine computes mass, in square meters.
        let meters = Tuning.World.pointsPerMeter
        let rowArea = tuning.rowSpacing * tuning.catchDepth / (meters * meters)
        let rowWeight = rowArea * Tuning.Materials.stone.density * gravity
        let force = pressure * wind.strength * rowWeight * direction * PhysicsUnits.pointsPerNewton
        var y = span.minY + tuning.rowSpacing / 2
        while y < span.maxY {
            if let hit = firstHit(from: CGPoint(x: start, y: y), to: CGPoint(x: end, y: y), in: scene),
               let block = hit.body.node as? BlockNode, !block.isFrozen, hit.body.isDynamic {
                block.wake()
                hit.body.applyForce(CGVector(dx: force, dy: 0), at: hit.point)
            }
            y += tuning.rowSpacing
        }
    }

    func reset() {
        for index in streaks.indices.reversed() {
            retire(at: index)
        }
        pendingSpawns = 0
    }

    // MARK: - Rays

    /// The body a row of wind meets first, and where.
    private func firstHit(from start: CGPoint, to end: CGPoint,
                          in scene: SKScene) -> (body: SKPhysicsBody, point: CGPoint)? {
        var nearest: (body: SKPhysicsBody, point: CGPoint, distance: CGFloat)?
        scene.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { body, point, _, _ in
            let distance = abs(point.x - start.x)
            if nearest.map({ distance < $0.distance }) ?? true {
                nearest = (body, point, distance)
            }
        }
        return nearest.map { ($0.body, $0.point) }
    }

    // MARK: - Streaks

    private func spawn(in visible: CGRect, direction: CGFloat, scene: SKScene) {
        guard streaks.count < Tuning.Wind.maxStreaks else { return }
        let x = direction > 0 ? visible.minX : visible.maxX
        let head = CGPoint(x: x, y: CGFloat.random(in: visible.minY...visible.maxY))
        guard scene.physicsWorld.body(at: head) == nil else { return }
        let line = spare.popLast() ?? makeLine()
        line.alpha = 1
        node.addChild(line)
        streaks.append(Streak(trail: [head], head: head, line: line))
    }

    private func makeLine() -> SKShapeNode {
        let line = SKShapeNode()
        line.lineCap = .round
        line.lineJoin = .round
        line.isAntialiased = true
        return line
    }

    private func retire(at index: Int) {
        let line = streaks[index].line
        line.removeFromParent()
        line.path = nil
        spare.append(line)
        streaks.remove(at: index)
    }

    /// Moves a streak downwind. When a piece stands in the way, the streak turns towards the nearest free side,
    /// above or below it, and straightens again once past; with nowhere to go, it fades against the piece.
    private func advance(_ streak: inout Streak, speed: CGFloat, direction: CGFloat, deltaTime: CGFloat,
                         scale: CGFloat, scene: SKScene) {
        let tuning = Tuning.Wind.self
        streak.age += deltaTime
        if streak.isDying {
            streak.fade -= deltaTime / tuning.streakFadeDuration
            return
        }
        let look = (speed * deltaTime + tuning.streakLookAhead) * direction
        let ahead = CGPoint(x: streak.head.x + look, y: streak.head.y)
        var forward = speed
        if scene.physicsWorld.body(at: streak.head) != nil {
            // A piece moved onto the streak.
            streak.isDying = true
            return
        } else if scene.physicsWorld.body(at: ahead) != nil {
            guard let side = freeSide(from: ahead, in: scene) else {
                streak.isDying = true
                return
            }
            streak.verticalSpeed = side * speed * tuning.streakDeflection
            forward = speed * tuning.streakSlowdown
        } else {
            streak.verticalSpeed *= exp(-tuning.streakRecovery * deltaTime)
        }
        var next = CGPoint(x: streak.head.x + forward * direction * deltaTime,
                           y: streak.head.y + streak.verticalSpeed * deltaTime)
        if scene.physicsWorld.body(at: next) != nil {
            // Sliding along a face: climb or dive without moving forward this frame.
            next.x = streak.head.x
        }
        streak.head = next
        if let last = streak.trail.last, hypot(next.x - last.x, next.y - last.y) >= tuning.streakPointSpacing {
            streak.trail.append(next)
        }
        trim(&streak.trail, to: tuning.streakLength * scale, head: next)
    }

    /// +1 when the wind gets past above, -1 below, nil when it is boxed in.
    private func freeSide(from point: CGPoint, in scene: SKScene) -> CGFloat? {
        let tuning = Tuning.Wind.self
        for step in 1...tuning.streakProbeSteps {
            let offset = CGFloat(step) * tuning.streakProbeSpacing
            if scene.physicsWorld.body(at: CGPoint(x: point.x, y: point.y + offset)) == nil { return 1 }
            if scene.physicsWorld.body(at: CGPoint(x: point.x, y: point.y - offset)) == nil { return -1 }
        }
        return nil
    }

    /// Keeps only the last `length` points of the trail, measured back from the head.
    private func trim(_ trail: inout [CGPoint], to length: CGFloat, head: CGPoint) {
        var total: CGFloat = 0
        var previous = head
        for index in stride(from: trail.count - 1, through: 0, by: -1) {
            total += hypot(previous.x - trail[index].x, previous.y - trail[index].y)
            previous = trail[index]
            if total > length {
                trail.removeFirst(index)
                return
            }
        }
    }

    private func draw(_ streak: Streak, opacity: CGFloat, scale: CGFloat) {
        let tuning = Tuning.Wind.self
        let path = CGMutablePath()
        path.move(to: streak.trail.first ?? streak.head)
        for point in streak.trail.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: streak.head)
        streak.line.path = path
        streak.line.lineWidth = tuning.streakThickness * scale
        let fadeIn = min(1, streak.age / tuning.streakFadeDuration)
        streak.line.strokeColor = color.withAlphaComponent(opacity * fadeIn * max(streak.fade, 0))
    }
}
