import SpriteKit

/// The game world: a platform, the piece waiting above the tower until a finger takes it, a camera that climbs
/// with the tower, feedback on every impact, block powers, the rope of the pull power, milestones and lost pieces.
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
    /// The piece to place, waiting in the air above the tower until a finger takes it.
    private var readyBlock: BlockNode?
    private let rope = Rope()
    private var edgeNudge = EdgeNudge(
        edgeWidth: Tuning.Camera.edgeWidth, dwell: Tuning.Camera.edgeDwell, sharpness: Tuning.Camera.edgeSharpness
    )
    private let dust: DustPool
    private let impacts: ImpactDirector
    private let powers: PowerEffects
    private let tension: TensionMonitor
    private let windEffect = WindEffect()
    private let bird: BirdVisit
    private let effects = PlacementEffects()
    private var wind = TowerScene.makeWind()
    private let sky = SKSpriteNode()
    /// The previous sky, fading out over the new one when the score reaches another stage.
    private let fadingSky = SKSpriteNode()
    private var skyStage = 0
    /// Glowing motes drifting up through the sky, behind the tower.
    private let motes = SKEmitterNode()
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
        rope.release()
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

    // MARK: - Touches on the world

    /// A finger comes down on the world. It takes the waiting piece, or while the rope is available, catches
    /// the piece of the tower under it. Points are in view coordinates.
    /// - Returns: Whether the touch took something: not once the game is over, nor while another finger
    ///   holds a piece, nor while the last piece dropped is still falling.
    @discardableResult
    func touchBegan(at point: CGPoint, time: TimeInterval) -> Bool {
        guard isBuilt, !drag.isDragging, !rope.isHolding else { return false }
        if session.isPulling {
            return catchBlock(at: point)
        }
        guard !tower.hasBlockInFlight, let id = session.selectedCardID, let card = session.pickUp(id) else {
            return false
        }
        let (block, isNew) = takeReadyBlock(for: card)
        drag.begin(block, at: point, time: time, in: self, zone: holdZone(), cameraScale: cameraRig.scale,
                   snaps: isNew)
        haptics.play(Tuning.Haptics.pickup)
        return true
    }

    func touchMoved(to point: CGPoint, time: TimeInterval) {
        if rope.isHolding {
            rope.move(fingerInView: point)
        } else {
            drag.track(to: point, time: time)
        }
    }

    /// The finger lifts: the held piece drops, or the rope lets go.
    func touchEnded(at point: CGPoint, time: TimeInterval) {
        if rope.isHolding {
            rope.release()
            return
        }
        guard let release = drag.release(at: point, time: time, in: self, zone: holdZone(),
                                         cameraScale: cameraRig.scale)
        else { return }
        place(release.block, velocity: release.velocity)
    }

    /// Another finger taps the screen while one holds the piece: the piece turns.
    func secondFingerTapped() {
        guard drag.isDragging else { return }
        rotateActiveCard()
    }

    /// Where the waiting piece is on screen, in view coordinates, for the tutorial.
    var readyPointInView: CGPoint? {
        guard let readyBlock, readyBlock.parent != nil else { return nil }
        return convertPoint(toView: readyBlock.position)
    }

    /// The held piece goes back to waiting above the tower.
    func cancelDrag() {
        guard let block = drag.cancel() else { return }
        guide.hide()
        session.returnHeldCard()
        if session.isPlaying {
            readyBlock?.dismiss()
            readyBlock = block
        } else {
            block.dismiss()
        }
    }

    /// Turns the held piece, or the waiting one.
    func rotateActiveCard() {
        guard let card = session.rotateActiveCard() else { return }
        if let held = drag.block, held.cardID == card.id {
            _ = held.turnQuarter(using: textures)
        } else if let ready = readyBlock, ready.cardID == card.id {
            _ = ready.turnQuarter(using: textures)
        }
        haptics.play(Tuning.Haptics.turn)
        audio.play(.turn, volume: Tuning.Sound.turnVolume)
    }

    /// Drops the waiting piece straight above the middle of the tower, without dragging (for VoiceOver).
    func dropAboveTower() {
        guard isBuilt, !drag.isDragging, !session.isPulling, !tower.hasBlockInFlight,
              let id = session.selectedCardID, let card = session.pickUp(id)
        else { return }
        let (block, _) = takeReadyBlock(for: card)
        let lift = Tuning.Drag.clearanceAboveTower + block.footprint.height / 2
        block.position = CGPoint(x: Platform.frame.midX, y: tower.landedTop + lift)
        place(block, velocity: .zero)
    }

    /// A bright double chime and a tap when a power is used.
    func celebrateAbility() {
        for note in Tuning.Sound.purchaseNotes {
            audio.play(.ding, volume: Tuning.Sound.resultVolume, semitones: note)
        }
        haptics.play(Tuning.Haptics.purchase)
    }

    /// The freeze power: every piece still in play turns to ice where it stands, a wave climbing the tower, and
    /// stays there for good. Pieces that had not been judged yet earn their points now.
    func freezeTower() {
        let frozen = tower.freezeLooseBlocks(using: textures)
        guard !frozen.isEmpty else { return }
        let top = frozen.max { $0.topY < $1.topY }.map { CGPoint(x: $0.position.x, y: $0.topY) }
            ?? CGPoint(x: Platform.frame.midX, y: tower.stableTop)
        powers.freeze(frozen, top: top, camera: cameraRig.node, screenSize: size, cameraScale: cameraRig.scale)
        cameraRig.shake(strength: Tuning.Freeze.shake)
        let unjudged = frozen.filter { !$0.isScored && session.isPlaying }
        for block in unjudged {
            block.markScored()
        }
        if !unjudged.isEmpty {
            score(unjudged)
        }
        session.reportLooseBlocks(false)
    }

    /// Frost on the edges of a screen this size, for the interface to lay over the game while the freeze goes off.
    func frostFrame(size: CGSize) -> UIImage {
        textures.frostFrame(size: size)
    }

    /// A short click, for each step of the roulette.
    func playTick() {
        audio.play(.turn, volume: Tuning.Sound.turnVolume)
        haptics.play(Tuning.Haptics.turn)
    }

    /// The waiting piece, or a new one when it does not match `card`.
    private func takeReadyBlock(for card: Card) -> (block: BlockNode, isNew: Bool) {
        if let ready = readyBlock, ready.cardID == card.id {
            readyBlock = nil
            ready.alpha = 1
            return (ready, false)
        }
        readyBlock?.dismiss()
        readyBlock = nil
        let block = makeBlock(card)
        block.appear()
        return (block, true)
    }

    private func makeBlock(_ card: Card) -> BlockNode {
        let block = BlockNode(card: card, textures: textures)
        block.zPosition = Layer.heldBlock
        addChild(block)
        return block
    }

    /// Ties the rope to the piece of the tower under the finger, if any.
    private func catchBlock(at viewPoint: CGPoint) -> Bool {
        let point = convertPoint(fromView: viewPoint)
        let reach = Tuning.Abilities.pullCatchRadius * cameraRig.scale
        let catchable = tower.blocks.filter { !$0.isFrozen && !$0.hasFallenOff && $0.physicsBody != nil }
        var caught = (physicsWorld.body(at: point)?.node as? BlockNode).flatMap { hit in
            catchable.contains { $0 === hit } ? hit : nil
        }
        if caught == nil {
            caught = catchable
                .map { block in (block: block, distance: block.placement.distance(to: point)) }
                .filter { $0.distance <= reach }
                .min { $0.distance < $1.distance }?.block
        }
        guard let caught else { return false }
        rope.attach(to: caught, at: point, fingerInView: viewPoint)
        haptics.play(Tuning.Haptics.pickup)
        return true
    }

    /// The waiting piece follows the tower, changes when the piece to place changes, and fades while the rope
    /// is out (it cannot be taken then).
    private func updateReadyBlock() {
        let card = session.isPlaying && !drag.isDragging ? session.activeCard : nil
        if let ready = readyBlock {
            let isStale = card.map {
                ready.cardID != $0.id || ready.definition.kind != $0.kind || ready.finalShape != $0.shape
            } ?? true
            if isStale {
                ready.dismiss()
                readyBlock = nil
            }
        }
        guard let card else { return }
        let zone = holdZone()
        if readyBlock == nil {
            let block = makeBlock(card)
            block.position = restingPoint(for: block, in: zone)
            block.appear()
            readyBlock = block
        }
        guard let ready = readyBlock else { return }
        ready.position = Smoothing.approach(ready.position, to: restingPoint(for: ready, in: zone),
                                            sharpness: Tuning.Drag.readySharpness, deltaTime: deltaTime)
        ready.alpha = session.isPulling ? 0.35 : 1
    }

    private func restingPoint(for block: BlockNode, in zone: HoldZone) -> CGPoint {
        let center = CGPoint(x: Platform.frame.midX,
                             y: zone.floorY + Tuning.Drag.readyLift + block.footprint.height / 2)
        return zone.clamp(center, size: block.footprint)
    }

    func startNewGame() {
        cameraRig.showsWholeTower = false
        clearWorld()
        session.startNewGame()
    }

    /// La partie perdue reprend (pub regardée) : les pièces déjà tombées de la plateforme disparaissent sans
    /// coûter de vie, ce qui bouge encore se fige comme avec le pouvoir de gel (une tour en train de s'écrouler
    /// ne doit pas reprendre aussitôt la vie rendue), et la caméra revient au sommet.
    /// - Returns: Whether the game is back on.
    @discardableResult
    func continueAfterLoss() -> Bool {
        guard session.continueAfterLoss() else { return false }
        cameraRig.showsWholeTower = false
        tower.discardFallenBlocks()
        if tower.hasLooseBlocks {
            freezeTower()
        }
        celebrateAbility()
        return true
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
        readyBlock?.removeFromParent()
        readyBlock = nil
        rope.release()
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
        fadingSky.zPosition = Layer.background + 0.5
        fadingSky.alpha = 0
        cameraRig.node.addChild(fadingSky)
        setUpMotes()
        cameraRig.node.addChild(motes)
        for node in [platform.node, guide.node, dust.node, powers.node, bird.node, effects.node, rope.node,
                     windEffect.node] {
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
        if !isPaused {
            session.tickPull(deltaTime)
        }
        if !session.isPulling {
            rope.release()
        }
        rope.pull(in: self, deltaTime: deltaTime)
    }

    override func didSimulatePhysics() {
        impacts.playPending(at: currentTime)
        powers.firePendingSprings(using: textures)
        react(to: tower.update(deltaTime: deltaTime, viewBottom: cameraRig.visibleRect.minY))
        updateEdgeNudge()
        cameraRig.follow(towerTop: cameraRig.showsWholeTower ? max(tower.stableTop, tower.landedTop) : tower.stableTop,
                         deltaTime: deltaTime)
        updateReadyBlock()
        updateHeldBlock()
        rope.draw(in: self, cameraScale: cameraRig.scale)
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
        windEffect.show(state, visible: cameraRig.visibleRect, viewWidth: size.width, deltaTime: deltaTime, in: self)
        windEffect.push(tower.blocks, wind: state,
                        pressure: Tuning.Wind.pressure(level: session.climb.milestonesReached),
                        gravity: abs(physicsWorld.gravity.dy), in: self)
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
        session.reportLooseBlocks(tower.hasLooseBlocks)
        updateSkyStage()
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
                audio.play(.perfect, volume: Tuning.Celebration.chimeVolume, semitones: semitones)
                haptics.play(Tuning.Haptics.perfect)
            }
        }
    }

    /// The score just beat the best one ever: a shower of sparkles and a fanfare over the tower.
    func celebrateRecord() {
        let top = CGPoint(x: Platform.frame.midX, y: tower.stableTop + Tuning.World.unit)
        effects.shower(at: top, count: Tuning.Celebration.recordSparkles)
        effects.announce(String(localized: "Nouveau record !"), at: CGPoint(x: top.x, y: top.y + Tuning.World.unit))
        audio.play(.record, volume: Tuning.Celebration.recordVolume)
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
        if session.isPlaying {
            audio.play(.lifeLost, volume: Tuning.Sound.lifeLostVolume)
        } else {
            playNotes(Tuning.Sound.gameOverNotes, effect: .gameOver, volume: Tuning.Sound.gameOverVolume,
                      spacing: Tuning.Sound.gameOverSpacing)
        }
        haptics.play(Tuning.Haptics.lifeLost, spacing: Tuning.Haptics.lifeLostSpacing)
        cameraRig.shake(strength: Tuning.Juice.lostPieceShake)
        if !session.isPlaying {
            if drag.isDragging {
                cancelDrag()
            }
            tension.silence()
            run(.sequence([
                .wait(forDuration: Tuning.Camera.overviewDelay),
                .run { [weak self] in
                    guard let self, !self.session.isPlaying else { return }
                    self.cameraRig.showsWholeTower = true
                },
            ]))
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

    /// Finger held at the very edge of the screen: the camera peeks a little to that side.
    private func updateEdgeNudge() {
        let fingerX = drag.isDragging ? drag.fingerInView.x : nil
        let push = edgeNudge.update(fingerX: fingerX, width: view?.bounds.width ?? size.width, deltaTime: deltaTime)
        cameraRig.nudge(push)
    }

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
        return HoldZone(floorY: tower.landedTop + Tuning.Drag.clearanceAboveTower, bounds: bounds,
                        overhang: abs(cameraRig.sidePush) * Tuning.Drag.edgeOverhang)
    }

    // MARK: - Layout and appearance

    /// The first layout places the camera at once; later changes (the interface settling) ease in.
    private func setUpMotes() {
        let look = Tuning.Look.self
        motes.zPosition = Layer.background + 1
        motes.particleBirthRate = look.motesPerSecond
        motes.particleLifetime = look.moteLifetime
        motes.particleLifetimeRange = look.moteLifetime / 2
        motes.emissionAngle = .pi / 2
        motes.emissionAngleRange = .pi / 3
        motes.particleSpeed = look.moteRiseSpeed
        motes.particleSpeedRange = look.moteRiseSpeed
        motes.particleScale = look.moteScale
        motes.particleScaleRange = look.moteScale * 0.6
        motes.particleRotationSpeed = 0.4
        motes.particleColorBlendFactor = 1
        motes.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, look.moteOpacity, look.moteOpacity * 0.4,
                                                                     look.moteOpacity, 0].map { NSNumber(value: Double($0)) },
                                                         times: [0, 0.25, 0.5, 0.75, 1])
    }

    private func layoutViewport() {
        guard isBuilt, size.width > 0, size.height > 0 else { return }
        sky.size = size
        fadingSky.size = size
        motes.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        let viewport = CameraFraming.Viewport(size: size, topInset: safeArea.top, bottomInset: safeArea.bottom)
        if hasLaidOut {
            cameraRig.setViewport(viewport)
        } else {
            cameraRig.snap(to: viewport, towerTop: tower.stableTop)
            // The sky starts already filled with motes.
            motes.advanceSimulationTime(TimeInterval(Tuning.Look.moteLifetime))
            hasLaidOut = true
        }
    }

    private func paintSky() {
        let colors = Palette.skies[skyStage]
        backgroundColor = textures.resolve(colors.bottom)
        sky.texture = textures.verticalGradient(top: colors.top, bottom: colors.bottom)
    }

    /// A new sky every few thousand points: the old one stays on top and fades away.
    private func updateSkyStage() {
        let stage = SkyStage.index(forScore: session.score, step: Tuning.Sky.pointsPerStage,
                                   count: Palette.skies.count)
        guard stage != skyStage, isBuilt else { return }
        skyStage = stage
        fadingSky.removeAllActions()
        fadingSky.texture = sky.texture
        fadingSky.alpha = 1
        paintSky()
        fadingSky.run(.fadeOut(withDuration: Tuning.Sky.transitionDuration))
    }

    private func refreshAppearance() {
        guard isBuilt, let view else { return }
        textures.configure(style: style, displayScale: view.contentScaleFactor)
        fadingSky.removeAllActions()
        fadingSky.alpha = 0
        paintSky()
        motes.particleTexture = textures.sparkle(size: Tuning.Look.moteSize)
        motes.particleColor = textures.resolve(Palette.mote)
        platform.refreshTextures(using: textures)
        guide.refreshColors(using: textures)
        dust.refresh(using: textures)
        powers.refresh(using: textures)
        windEffect.refresh(using: textures)
        bird.refresh(using: textures)
        effects.refresh(using: textures)
        drag.block?.refreshTexture(using: textures)
        readyBlock?.refreshTexture(using: textures)
        rope.refresh(using: textures)
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

