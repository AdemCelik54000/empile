import SpriteKit
import SwiftUI

/// The game screen: the SpriteKit world full screen, the climb header on top and the hand (or the end of the
/// game) at the bottom. Touching the world places the selected piece; the world keeps clear of the interface.
/// The shop opens over the frozen world at any time.
struct GameView: View {
    let session: GameSession
    let scene: TowerScene
    let settings: GameSettings
    let ads: AdManager
    let isPaused: Bool
    let onPause: () -> Void
    let onHome: () -> Void
    @State private var headerBottom: CGFloat = 0
    @State private var bottomPanelFrame = CGRect.zero
    /// Top of everything drawn at the bottom (hint included): the world keeps clear below it.
    @State private var bottomAreaTop: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var isShopOpen = false
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
            .placementGesture(scene: scene, minimumDistance: 0, handFrame: bottomPanelFrame) {
                session.selectedCardID
            }
            .accessibilityLabel(Text("Aire de construction"))
            .accessibilityHint(Text("Touchez pour poser le bloc choisi, glissez pour viser."))

            if isShopOpen {
                // The tower stays visible behind, blurred, so the shop reads cleanly.
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                    .transition(.opacity)
                ShopView(session: session, scene: scene) { isShopOpen = false }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                playingOverlay
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: session.phase)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: isShopOpen)
        .animation(.spring(duration: 0.4), value: showsHint)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: bannerMilestone)
        .animation(.spring(duration: 0.4), value: session.windAlert)
        .animation(.spring(duration: 0.4, bounce: 0.35), value: session.combo.streak > 0)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: showsRecordBanner)
        .animation(.spring(duration: 0.4), value: ads.isRewardedReady)
        .onChange(of: isPaused || isShopOpen, initial: true) { _, isFrozen in
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
                isShopOpen = false
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

    /// Header on top, milestone banner under it, hand or end of game at the bottom.
    private var playingOverlay: some View {
        VStack(spacing: 12) {
            ClimbHeader(session: session, record: settings.bestScore, onPause: onPause, onShop: openShop)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { headerBottom = $0 }
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
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bottomPanelFrame = $0 }
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
            HandTray(session: session, scene: scene, frame: bottomPanelFrame)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .gameOver:
            GameOverPanel(
                score: session.score,
                record: settings.bestScore,
                isNewRecord: isNewRecord,
                canContinue: session.canContinue && ads.isRewardedReady,
                onContinue: continueWithAd,
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

    /// The player watches an ad; if they watch it through, every life comes back and the tower goes on.
    private func continueWithAd() {
        guard !isLeavingGameOver else { return }
        isLeavingGameOver = true
        Task {
            if await ads.presentRewarded() {
                session.continueAfterAd()
            }
            isLeavingGameOver = false
        }
    }

    private func openShop() {
        scene.prepareForPause()
        isShopOpen = true
    }

    /// Screen areas the world keeps clear: the header on top, the hand (and its hint) at the bottom.
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
