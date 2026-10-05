import SpriteKit
import SwiftUI

/// The game screen: the SpriteKit world full screen, the climb header on top with the ad for a power on the
/// left and the reserve on the right, and the powers (or the end of the game) at the bottom. Touching the world
/// takes the waiting piece; the world keeps clear of the interface. Using a power freezes the world while it
/// takes the stage.
struct GameView: View {
    let session: GameSession
    let scene: TowerScene
    let settings: GameSettings
    let ads: AdManager
    let isPaused: Bool
    let onPause: () -> Void
    let onHome: () -> Void
    @State private var headerBottom: CGFloat = 0
    /// Top of everything drawn at the bottom (hint included): the world keeps clear below it.
    @State private var bottomAreaTop: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    /// A power on stage over the frozen world.
    @State private var abilityStage: AbilityStage?
    /// An ad for a power is on screen, or about to be.
    @State private var isWatchingAd = false
    @State private var bannerMilestone: Milestone?
    @State private var isNewRecord = false
    /// The record when the current game started, to tell whether this game beat it.
    @State private var recordBeforeGame = 0
    /// The "new record" banner is on screen.
    @State private var showsRecordBanner = false
    /// This game has already celebrated beating the record.
    @State private var hasCelebratedRecord = false
    /// An ad is on screen, or about to be: the buttons of the game over panel wait.
    @State private var isLeavingGameOver = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: Tuning.Display.preferredFramesPerSecond,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
                debugOptions: debugOptions
            )
            .ignoresSafeArea()
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { screenHeight = $0 }
            .worldGesture(scene: scene)
            .accessibilityLabel(Text("Aire de construction"))
            .accessibilityHint(Text("Touchez et glissez pour viser, lâchez pour poser la pièce."))
            .accessibilityAction(named: Text("Lâcher sur la tour")) {
                scene.dropAboveTower()
            }

            playingOverlay

            if let abilityStage {
                AbilityStageView(
                    stage: abilityStage,
                    session: session,
                    scene: scene,
                    onPick: change,
                    onClose: { self.abilityStage = nil }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: session.phase)
        .animation(.spring(duration: 0.35), value: abilityStage == nil)
        .animation(.spring(duration: 0.4), value: session.isPulling)
        .animation(.spring(duration: 0.4), value: showsHint)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: bannerMilestone)
        .animation(.spring(duration: 0.4), value: session.windAlert)
        .animation(.spring(duration: 0.4, bounce: 0.35), value: session.combo.streak > 0)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: showsRecordBanner)
        .onChange(of: isPaused || abilityStage != nil || isWatchingAd, initial: true) { _, isFrozen in
            scene.setFrozen(isFrozen)
        }
        .onChange(of: session.lastMilestone) { _, milestone in
            bannerMilestone = milestone
        }
        .task(id: bannerMilestone) {
            guard bannerMilestone != nil else { return }
            try? await Task.sleep(for: .seconds(Tuning.Climb.bannerDuration))
            bannerMilestone = nil
        }
        .onChange(of: session.score, initial: true) { _, score in
            // The record is saved the moment it is beaten, so quitting never loses it.
            guard score > 0 else {
                recordBeforeGame = settings.bestScore
                hasCelebratedRecord = false
                return
            }
            settings.recordScore(score)
            if recordBeforeGame > 0, score > recordBeforeGame, !hasCelebratedRecord {
                hasCelebratedRecord = true
                showsRecordBanner = true
                scene.celebrateRecord()
            }
        }
        .task(id: showsRecordBanner) {
            guard showsRecordBanner else { return }
            try? await Task.sleep(for: .seconds(Tuning.Climb.bannerDuration))
            showsRecordBanner = false
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .gameOver {
                abilityStage = nil
                isNewRecord = settings.bestScore > recordBeforeGame
            }
        }
        .onChange(of: worldInsets, initial: true) { _, insets in
            scene.setSafeAreaInsets(top: insets.top, bottom: insets.bottom)
        }
        .onChange(of: colorScheme, initial: true) { _, scheme in
            scene.setAppearance(scheme == .dark ? .dark : .light)
        }
        .onChange(of: session.climb.floors) { _, floors in
            if floors > 0 {
                settings.hasPlacedFirstBlock = true
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Dragging is the core gesture: a first swipe from the top or bottom edge should neither leave the game nor
        // open the notification or control center (which pauses the game and puts the held block back).
        .defersSystemGestures(on: .vertical)
    }

    /// Header on top with the ad and the reserve under it, banners under them, powers or end of game at the
    /// bottom.
    private var playingOverlay: some View {
        VStack(spacing: 12) {
            ClimbHeader(session: session, record: settings.bestScore, onPause: onPause)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { headerBottom = $0 }
            if session.isPlaying {
                HStack(alignment: .top) {
                    AdRewardButton(
                        left: session.adRewardsLeft,
                        isEnabled: session.canEarnAbility && (ads.isRewardedReady || !Tuning.Ads.isEnabled)
                            && !isWatchingAd,
                        action: watchAdForAbility
                    )
                    Spacer()
                    ReserveStack(session: session, scene: scene)
                }
                .transition(.opacity)
            }
            if let timeLeft = session.pullTimeLeft {
                PullTimer(timeLeft: timeLeft)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            if session.combo.streak > 0 && session.isPlaying {
                ComboBadge(combo: session.combo)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            if showsRecordBanner {
                RecordBanner()
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            if let bannerMilestone {
                MilestoneBanner(milestone: bannerMilestone)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            if let windAlert = session.windAlert {
                WindBanner(alert: windAlert)
                    .transition(.move(edge: windAlert.direction > 0 ? .leading : .trailing).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                if showsHint {
                    PlacementHint()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                bottomPanel
            }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { bottomAreaTop = $0 }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        switch session.phase {
        case .playing:
            AbilityBar(session: session, scene: scene, onUse: use)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .gameOver:
            GameOverPanel(
                score: session.score,
                record: settings.bestScore,
                isNewRecord: isNewRecord,
                onReplay: { leaveGameOver(then: scene.startNewGame) },
                onHome: { leaveGameOver(then: onHome) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var showsHint: Bool {
        !settings.hasPlacedFirstBlock && session.isPlaying && session.heldCardID == nil
    }

    /// Leaving the game over screen ends the game for good: it counts toward the next ad, which is shown now
    /// if one is due, never in the middle of a game.
    private func leaveGameOver(then action: @escaping () -> Void) {
        guard !isLeavingGameOver else { return }
        isLeavingGameOver = true
        settings.registerFinishedGame()
        Task {
            await ads.presentIfDue(settings)
            isLeavingGameOver = false
            action()
        }
    }

    /// Every power takes the stage the same way, then acts: a shape or material change asks for the piece,
    /// the others act at once.
    private func use(_ ability: Ability) {
        guard abilityStage == nil, session.canUse(ability) else { return }
        scene.prepareForPause()
        abilityStage = .activating(ability)
        Task {
            try? await Task.sleep(for: .seconds(Tuning.Abilities.activationDuration))
            guard abilityStage == .activating(ability) else { return }
            switch ability {
            case .reshape, .rematerial:
                abilityStage = .picking(ability)
            case .extraLife:
                if session.useExtraLife() {
                    scene.celebrateAbility()
                }
                abilityStage = nil
            case .pull:
                if session.startPull() {
                    scene.celebrateAbility()
                }
                abilityStage = nil
            }
        }
    }

    private func change(_ id: Card.ID, with ability: Ability) -> Bool {
        guard session.change(id, with: ability) else { return false }
        scene.celebrateAbility()
        return true
    }

    /// The player watches an ad; if they watch it through, the roulette draws a power for them.
    private func watchAdForAbility() {
        guard abilityStage == nil, !isWatchingAd, session.canEarnAbility else { return }
        scene.prepareForPause()
        isWatchingAd = true
        Task {
            // Without ads (testers' version), the power comes straight away.
            let earned = Tuning.Ads.isEnabled ? await ads.presentRewarded() : true
            if earned, let won = session.earnAbility() {
                abilityStage = .roulette(won: won)
            }
            isWatchingAd = false
        }
    }

    /// Screen areas the world keeps clear: the header on top, the powers (and the hint) at the bottom.
    private var worldInsets: EdgeInsets {
        EdgeInsets(top: headerBottom, leading: 0, bottom: max(0, screenHeight - bottomAreaTop), trailing: 0)
    }

    private var debugOptions: SpriteView.DebugOptions {
        var options: SpriteView.DebugOptions = []
        if Tuning.Debug.showsStatistics {
            options.formUnion([.showsFPS, .showsNodeCount, .showsDrawCount])
        }
        if Tuning.Debug.showsPhysicsOutlines {
            options.insert(.showsPhysics)
        }
        return options
    }
}
