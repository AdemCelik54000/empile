import SpriteKit
import SwiftUI

/// The game screen: the SpriteKit world full screen, the climb header on top with the ad for a power on the
/// left and the next two pieces on the right, and the powers (or the end of the game) at the bottom. Touching the world
/// takes the waiting piece; the world keeps clear of the interface. Using a power freezes the world while it
/// takes the stage.
struct GameView: View {
    let session: GameSession
    let scene: TowerScene
    let settings: GameSettings
    let ads: AdManager
    let isPaused: Bool
    let onPause: () -> Void
    /// Une nouvelle partie après une défaite : l'écran racine décide (une mise à jour exigée renvoie à l'accueil).
    let onReplay: () -> Void
    let onHome: () -> Void
    @State private var headerBottom: CGFloat = 0
    /// Top of everything drawn at the bottom (hint included): the world keeps clear below it.
    @State private var bottomAreaTop: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    /// A power on stage over the frozen world.
    @State private var abilityStage: AbilityStage?
    /// Changes with every power put on stage, so an old stage can never close or steer a newer one.
    @State private var stageID = UUID()
    /// An ad for a power is on screen, or about to be.
    @State private var isWatchingAd = false
    @State private var bannerMilestone: Milestone?
    @State private var isNewRecord = false
    /// The record when the current game started, to tell whether this game beat it.
    @State private var recordBeforeGame = 0
    /// The "new record" banner is on screen.
    @State private var showsRecordBanner = false
    /// Pieces placed in this game, while it is the first one ever (for the tutorial).
    @State private var tutorialPlacements = 0
    /// This game has already celebrated beating the record.
    @State private var hasCelebratedRecord = false
    /// The freeze power just went off: frost covers the edges of the screen for a few seconds.
    @State private var showsFrost = false
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

            if let tutorialStep {
                TutorialRings(step: tutorialStep, scene: scene)
            }

            playingOverlay

            FrostFrame(scene: scene, isShown: showsFrost)

            if let abilityStage {
                AbilityStageView(
                    stage: abilityStage,
                    session: session,
                    scene: scene,
                    onPick: change,
                    onClose: { [stageID] in closeStage(stageID) }
                )
                .id(stageID)
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: session.phase)
        .animation(.spring(duration: 0.35), value: abilityStage == nil)
        .animation(.spring(duration: 0.4), value: session.isPulling)
        .animation(.spring(duration: 0.4), value: tutorialStep)
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
                tutorialPlacements = 0
                return
            }
            tutorialPlacements += 1
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
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // Dragging is the core gesture: a first swipe from the top or bottom edge should neither leave the game nor
        // open the notification or control center (which pauses the game and puts the held block back).
        .defersSystemGestures(on: .vertical)
    }

    /// Header on top with the ad and the next pieces under it, banners under them, powers or end of game at the
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
                    UpcomingPieces(session: session, scene: scene)
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
                if let tutorialStep {
                    TutorialBubble(step: tutorialStep)
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
                onReplay: { leaveGameOver(then: onReplay) },
                onHome: { leaveGameOver(then: onHome) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The first game ever (no record when it started) shows how to play, for its first few pieces.
    private var tutorialStep: TutorialStep? {
        guard recordBeforeGame == 0, tutorialPlacements < Tuning.Tutorial.placements, session.isPlaying,
              abilityStage == nil, !session.isPulling
        else { return nil }
        return session.heldCardID == nil ? .take : .aim(canTurn: session.canRotate)
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

    /// Every power takes the stage the same way, then acts: a shape change asks for the piece, the others act
    /// at once.
    private func use(_ ability: Ability) {
        guard abilityStage == nil, session.canUse(ability) else { return }
        scene.prepareForPause()
        showStage(.activating(ability))
        let id = stageID
        Task {
            try? await Task.sleep(for: .seconds(Tuning.Abilities.activationDuration))
            guard stageID == id, abilityStage == .activating(ability) else { return }
            switch ability {
            case .reshape:
                showStage(.picking(ability))
            case .freeze:
                if session.useFreeze() {
                    scene.freezeTower()
                    showFrost()
                }
                abilityStage = nil
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

    /// Frost creeps in fast from the edges of the screen, stays a moment, then melts away.
    private func showFrost() {
        withAnimation(.easeOut(duration: Tuning.Freeze.frameFadeIn)) { showsFrost = true }
        Task {
            try? await Task.sleep(for: .seconds(Tuning.Freeze.frameFadeIn + Tuning.Freeze.frameHold))
            withAnimation(.easeIn(duration: Tuning.Freeze.frameFadeOut)) { showsFrost = false }
        }
    }

    /// Puts a power on stage: always a fresh stage, whatever was there before.
    private func showStage(_ stage: AbilityStage) {
        stageID = UUID()
        abilityStage = stage
    }

    /// Closes the stage `id`, unless another one has taken its place since.
    private func closeStage(_ id: UUID) {
        guard stageID == id else { return }
        abilityStage = nil
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
                showStage(.roulette(won: won))
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

/// Frost on the edges of the whole screen, interface included, while the freeze power goes off. Nothing to touch.
private struct FrostFrame: View {
    let scene: TowerScene
    let isShown: Bool

    var body: some View {
        GeometryReader { proxy in
            if isShown {
                Image(uiImage: scene.frostFrame(size: proxy.size))
                    .resizable()
                    .transition(.scale(scale: 1.08).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
