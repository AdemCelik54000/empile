import SpriteKit

/// The game world: a platform, the blocks the player drags in from the hand, a camera that climbs with the tower,
/// feedback on every impact, block powers, milestones and lost pieces.
///
/// Frame order: `update` measures the frame time, SpriteKit steps physics (reporting contacts), then
/// `didSimulatePhysics` plays impacts and powers, reads the tower, moves the camera, and only then places
/// the held block, so it never lags a frame behind the finger.
final class TowerScene: SKScene {
    private let session: GameSession
    private let haptics: HapticsManager
    private let audio: AudioManager
    private let textures = TextureFactory()
    private let cameraRig: CameraRig
    private let platform = Platform()
    private let tower = Tower()
    private let guide = DropGuide()
    private let drag = DragController()
    private let dust: DustPool
    private let impacts: ImpactDirector
    private let powers: PowerEffects
    private let tension: TensionMonitor
    private let windEffect = WindEffect()
    private let bird: BirdVisit
    private let effects = PlacementEffects()
    private var wind = TowerScene.makeWind()
    private let sky = SKSpriteNode()
    private var slowMotion = SlowMotion()
    private var style = UIUserInterfaceStyle.light
    private var safeArea = (top: CGFloat(0), bottom: CGFloat(0))
    private var lastUpdateTime: TimeInterval?
    private var currentTime: TimeInterval = 0
    private var deltaTime: TimeInterval = 0
    private var isBuilt = false
    private var hasLaidOut = false

    init(session: GameSession, haptics: HapticsManager, audio: AudioManager) {
        let cameraRig = CameraRig()
        let dust = DustPool()
        self.session = session
        self.haptics = haptics
        self.audio = audio
        self.cameraRig = cameraRig
        self.dust = dust
        impacts = ImpactDirector(haptics: haptics, audio: audio, dust: dust, cameraRig: cameraRig)
        powers = PowerEffects(haptics: haptics, audio: audio)
        tension = TensionMonitor(haptics: haptics, audio: audio)
        bird = BirdVisit(audio: audio, haptics: haptics)
        super.init(size: .zero)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { nil }

    // MARK: - Settings from SwiftUI

    func setAppearance(_ style: UIUserInterfaceStyle) {
        self.style = style
        refreshAppearance()
    }

    /// Screen areas the world must keep clear: system areas plus the interface drawn over the game.
    func setSafeAreaInsets(top: CGFloat, bottom: CGFloat) {
        safeArea = (top, bottom)
        layoutViewport()
    }

    func setFeedback(sound: Bool, haptics: Bool) {
        audio.setEnabled(sound)
        self.haptics.setEnabled(haptics)
    }

    /// Lets go of anything held and quiets the tension before the world freezes (pause menu, home screen).
    func prepareForPause() {
        if drag.isDragging {
            cancelDrag()
        }
        tension.silence()
    }

    /// Stops physics and every animation in the world, or lets them run again.
    func setFrozen(_ isFrozen: Bool) {
        isPaused = isFrozen
    }

    /// Restarts sound and vibration engines, which the system stops in the background.
    func resumeFeedback() {
        haptics.start()
        audio.start()
    }

    /// A block drawn exactly as in the game, for the interface.
    func preview(of kind: BlockKind, shape: BlockShape, style: UIUserInterfaceStyle, displayScale: CGFloat) -> UIImage {
        textures.preview(of: kind, shape: shape, style: style, displayScale: displayScale)
    }

    // MARK: - Playing, from the hand

    /// A finger takes a card: from the hand, or anywhere on screen for the selected card.
    /// Points are in view coordinates.
    /// - Returns: Whether the block was taken: not once the game is over, nor while another finger holds one,
    ///   nor while the last block dropped is still falling.
    @discardableResult
    func beginDrag(cardID: Card.ID, at point: CGPoint, time: TimeInterval) -> Bool {
        guard isBuilt, !drag.isDragging, !tower.hasBlockInFlight, let card = session.pickUp(cardID) else {
            return false
        }
        let block = BlockNode(card: card, textures: textures)
        block.zPosition = Layer.heldBlock
        addChild(block)
        drag.begin(block, at: point, time: time, in: self, zone: holdZone(), cameraScale: cameraRig.scale)
        block.appear()
        haptics.play(Tuning.Haptics.pickup)
        audio.play(.pickup, volume: Tuning.Sound.pickupVolume)
        return true
    }

    func moveDrag(to point: CGPoint, time: TimeInterval) {
        drag.track(to: point, time: time)
    }

    /// - Parameter returnsToHand: The finger let go over the hand: the block goes back instead of falling.
    func endDrag(at point: CGPoint, time: TimeInterval, returnsToHand: Bool) {
        guard !returnsToHand else {
            cancelDrag()
            return
        }
        guard let release = drag.release(at: point, time: time, cameraScale: cameraRig.scale) else { return }
        place(release.block, velocity: release.velocity)
    }

    func cancelDrag() {
        drag.cancel()?.dismiss()
        guide.hide()
        session.returnHeldCard()
    }

    /// Turns the dragged block, or the selected card when nothing is dragged.
    func rotateActiveCard() {
        guard let card = session.rotateActiveCard() else { return }
        if let held = drag.block, held.cardID == card.id {
            _ = held.turnQuarter(using: textures)
        }
        haptics.play(Tuning.Haptics.turn)
        audio.play(.turn, volume: Tuning.Sound.turnVolume)
    }

    /// Drops a card straight above the middle of the tower, without dragging (for VoiceOver).
    func dropAboveTower(cardID: Card.ID) {
        guard isBuilt, !drag.isDragging, !tower.hasBlockInFlight, let card = session.pickUp(cardID) else { return }
        let block = BlockNode(card: card, textures: textures)
        addChild(block)
        let lift = Tuning.Drag.clearanceAboveTower + block.footprint.height / 2
        block.position = CGPoint(x: Platform.frame.midX, y: tower.landedTop + lift)
        place(block, velocity: .zero)
    }

    /// A bright double chime and a tap when the shop sells something.
    func celebratePurchase() {
        for note in Tuning.Sound.purchaseNotes {
            audio.play(.ding, volume: Tuning.Sound.resultVolume, semitones: note)
        }
        haptics.play(Tuning.Haptics.purchase)
    }

    func startNewGame() {
        clearWorld()
        session.startNewGame()
    }

    private static func makeWind() -> WindSchedule {
        WindSchedule(pause: Tuning.Wind.pause, warning: Tuning.Wind.warning, gust: Tuning.Wind.gust,
                     seed: .random(in: .min ... .max))
    }

    private func place(_ block: BlockNode, velocity: CGVector) {
        block.drop(velocity: velocity)
        tower.add(block)
        guide.hide()
        session.placeHeldCard()
    }

    private func clearWorld() {
        drag.cancel()?.removeFromParent()
        guide.hide()
        powers.reset()
        tension.silence()
        slowMotion.cancel()
        tower.clear()
        wind = TowerScene.makeWind()
        windEffect.reset()
        bird.reset()
        effects.reset()
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        guard !isBuilt else { return }
        isBuilt = true
        physicsWorld.gravity = Tuning.World.gravity
        physicsWorld.speed = Tuning.Physics.simulationSpeed
        physicsWorld.contactDelegate = self
        addChild(cameraRig.node)
        camera = cameraRig.node
        sky.zPosition = Layer.background
        cameraRig.node.addChild(sky)
        cameraRig.node.addChild(windEffect.node)
        for node in [platform.node, guide.node, dust.node, powers.node, bird.node, effects.node] {
            addChild(node)
        }
        refreshAppearance()
        layoutViewport()
        resumeFeedback()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        hasLaidOut = false
        layoutViewport()
    }

    override func update(_ currentTime: TimeInterval) {
        let elapsed = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime
        self.currentTime = currentTime
        deltaTime = elapsed.clamped(to: 0...Tuning.Display.maxFrameDuration)
        physicsWorld.speed = Tuning.Physics.simulationSpeed * slowMotion.speed(at: currentTime)
        blow()
    }

    override func didSimulatePhysics() {
        impacts.playPending(at: currentTime)
        powers.firePendingSprings(using: textures)
        react(to: tower.update(deltaTime: deltaTime, viewBottom: cameraRig.visibleRect.minY))
        cameraRig.follow(towerTop: tower.stableTop, deltaTime: deltaTime)
        updateHeldBlock()
    }

    // MARK: - Climb

    /// Advances the gusts and the birds, and pushes the pieces still in play, before physics steps.
    private func blow() {
        guard !isPaused else { return }
        let previous = wind.state.phase
        let state = wind.advance(by: deltaTime, isActive: session.isWindy)
        if state.phase != previous {
            if state.phase == .warning {
                haptics.play(Tuning.Haptics.windWarning, spacing: Tuning.Haptics.patternSpacing)
            } else if state.phase == .blowing {
                audio.play(.windGust, volume: Tuning.Wind.gustVolume)
            }
            session.reportWind(state)
        }
        windEffect.show(state)
        windEffect.push(tower.blocks, wind: state,
                        pressure: Tuning.Wind.pressure(level: session.climb.milestonesReached),
                        gravity: abs(physicsWorld.gravity.dy))
        bird.update(deltaTime: deltaTime, isActive: session.hasBirds, blocks: tower.blocks, in: self,
                    visible: cameraRig.visibleRect)
    }

    private func react(to update: TowerUpdate) {
        let isPlaying = session.isPlaying
        if update.placedBlockFellOff, isPlaying, Tuning.SlowMotion.isEnabled {
            slowMotion.trigger(at: currentTime)
        }
        tension.update(danger: isPlaying ? update.danger : 0, time: currentTime, deltaTime: deltaTime)
        for _ in 0..<update.lostBlocks where session.isPlaying {
            loseLife()
        }
        if !update.newlySettled.isEmpty && isPlaying {
            score(update.newlySettled)
        }
        if update.becameStable && isPlaying {
            breakOverloadedGlass()
        }
        let floors = ClimbProgress.floors(height: tower.stableTop - Platform.surfaceY, unit: Tuning.World.unit)
        if floors != session.climb.floors, !session.reportHeight(floors).isEmpty {
            celebrateMilestone()
        }
    }

    /// Judges each piece that has just come to rest: how straight it stands and how much of it is supported.
    private func score(_ blocks: [BlockNode]) {
        let snapshot = tower.snapshot()
        let ground = Platform.frame.minX...Platform.frame.maxX
        for block in blocks {
            guard let placed = snapshot.blocks.first(where: { $0.id == block.cardID }) else { continue }
            let share = snapshot.supportedShare(of: placed, groundY: Platform.surfaceY, groundSpan: ground,
                                                gap: Tuning.Score.supportGap)
            let tilt = abs(remainder(block.zRotation, .pi / 2))
            let quality = PlacementQuality.judge(tilt: tilt, supportedShare: share)
            guard let placement = session.scorePlacement(kind: block.definition.kind, shape: block.shape,
                                                         quality: quality)
            else { continue }
            effects.show(placement, on: block)
            if quality == .perfect {
                block.flash()
                let semitones = min(Float(placement.streak - 1) * Tuning.Celebration.semitonesPerStreak,
                                    Tuning.Celebration.maxChimeSemitones)
                audio.play(.ding, volume: Tuning.Celebration.chimeVolume, semitones: semitones)
                haptics.play(Tuning.Haptics.perfect)
            }
        }
    }

    /// The score just beat the best one ever: a shower of sparkles and a fanfare over the tower.
    func celebrateRecord() {
        let top = CGPoint(x: Platform.frame.midX, y: tower.stableTop + Tuning.World.unit)
        effects.shower(at: top, count: Tuning.Celebration.recordSparkles)
        effects.announce(String(localized: "Nouveau record !"), at: CGPoint(x: top.x, y: top.y + Tuning.World.unit))
        playNotes(Tuning.Sound.milestoneArpeggio, effect: .ding, volume: Tuning.Celebration.recordVolume,
                  spacing: Tuning.Sound.arpeggioSpacing)
        haptics.play(Tuning.Haptics.record, spacing: Tuning.Haptics.patternSpacing)
    }

    /// Glass carrying too many pieces shatters once the tower stands still; frozen glass is safe for good.
    private func breakOverloadedGlass() {
        let overloaded = PowerRules.overloadedBlocks(
            in: tower.snapshot(),
            maxLoad: Tuning.Powers.glassMaxLoad,
            ignoring: tower.frozenCardIDs
        )
        for id in overloaded {
            guard let block = tower.block(withCardID: id) else { continue }
            powers.shatter(block)
            tower.remove(block)
        }
    }

    private func loseLife() {
        session.loseLife()
        playNotes(Tuning.Sound.lifeLostNotes, effect: .lifeLost, volume: Tuning.Sound.lifeLostVolume,
                  spacing: Tuning.Sound.lifeLostSpacing)
        haptics.play(Tuning.Haptics.lifeLost, spacing: Tuning.Haptics.lifeLostSpacing)
        cameraRig.shake(strength: Tuning.Juice.lostPieceShake)
        if !session.isPlaying {
            if drag.isDragging {
                cancelDrag()
            }
            tension.silence()
        }
    }

    private func celebrateMilestone() {
        effects.shower(at: CGPoint(x: Platform.frame.midX, y: tower.stableTop + Tuning.World.unit),
                       count: Tuning.Celebration.milestoneSparkles)
        playNotes(Tuning.Sound.milestoneArpeggio, effect: .ding, volume: Tuning.Sound.resultVolume,
                  spacing: Tuning.Sound.arpeggioSpacing)
        haptics.play(Tuning.Haptics.milestone, spacing: Tuning.Haptics.patternSpacing)
    }

    private func playNotes(_ notes: [Float], effect: SoundEffect, volume: Float, spacing: TimeInterval) {
        let sequence = notes.enumerated().map { index, note in
            SKAction.sequence([
                .wait(forDuration: spacing * Double(index)),
                .run { [weak self] in self?.audio.play(effect, volume: volume, semitones: note) },
            ])
        }
        run(.group(sequence))
    }

    // MARK: - Held block

    private func updateHeldBlock() {
        guard let block = drag.block else { return }
        let scale = cameraRig.scale
        drag.update(in: self, zone: holdZone(), cameraScale: scale, deltaTime: deltaTime)
        let halfWidth = block.footprint.width / 2
        let span = (block.position.x - halfWidth)...(block.position.x + halfWidth)
        guide.show(
            below: block,
            landingY: tower.landingY(under: span),
            bottomY: cameraRig.visibleRect.minY,
            cameraScale: scale
        )
    }

    /// On screen, clear of the screen edges and the interface, and above every block that has landed.
    private func holdZone() -> HoldZone {
        let visible = cameraRig.visibleRect
        let scale = cameraRig.scale
        let margin = Tuning.Drag.sideMargin * scale
        let bounds = CGRect(
            x: visible.minX + margin,
            y: visible.minY,
            width: visible.width - 2 * margin,
            height: visible.height - safeArea.top * scale
        )
        return HoldZone(floorY: tower.landedTop + Tuning.Drag.clearanceAboveTower, bounds: bounds)
    }

    // MARK: - Layout and appearance

    /// The first layout places the camera at once; later changes (the interface settling) ease in.
    private func layoutViewport() {
        guard isBuilt, size.width > 0, size.height > 0 else { return }
        sky.size = size
        windEffect.layout(viewSize: size)
        let viewport = CameraFraming.Viewport(size: size, topInset: safeArea.top, bottomInset: safeArea.bottom)
        if hasLaidOut {
            cameraRig.setViewport(viewport)
        } else {
            cameraRig.snap(to: viewport, towerTop: tower.stableTop)
            hasLaidOut = true
        }
    }

    private func refreshAppearance() {
        guard isBuilt, let view else { return }
        textures.configure(style: style, displayScale: view.contentScaleFactor)
        backgroundColor = textures.resolve(Palette.skyBottom)
        sky.texture = textures.verticalGradient(top: Palette.skyTop, bottom: Palette.skyBottom)
        platform.refreshTextures(using: textures)
        guide.refreshColors(using: textures)
        dust.refresh(using: textures)
        powers.refresh(using: textures)
        windEffect.refresh(using: textures)
        bird.refresh(using: textures)
        effects.refresh(using: textures)
        drag.block?.refreshTexture(using: textures)
        for block in tower.blocks {
            block.refreshTexture(using: textures)
        }
    }
}

extension TowerScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        (contact.bodyA.node as? BlockNode)?.markLanded()
        (contact.bodyB.node as? BlockNode)?.markLanded()
        impacts.record(contact)
        powers.record(contact)
    }
}

