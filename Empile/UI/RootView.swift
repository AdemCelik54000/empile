import SwiftUI

/// Holds the game for the whole app life and moves between the home screen, the game and the pause menu.
/// The game view stays underneath the home screen, frozen, so the world is never rebuilt.
struct RootView: View {
    private enum Screen {
        case home
        case game
    }

    @State private var settings = GameSettings()
    @State private var session: GameSession
    @State private var scene: TowerScene
    @State private var ads = AdManager()
    @State private var gameCenter = GameCenterManager()
    @State private var connectivity = ConnectivityMonitor()
    @State private var updates = UpdateChecker()
    @State private var screen = Screen.home
    @State private var isPauseMenuShown = false
    @State private var isSettingsShown = false
    @State private var isLeaderboardShown = false
    /// A game is being given up: the ad, if one is due, is on screen or about to be.
    @State private var isAbandoningGame = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let session = GameSession()
        _session = State(initialValue: session)
        _scene = State(initialValue: TowerScene(session: session, haptics: HapticsManager(), audio: AudioManager()))
    }

    var body: some View {
        ZStack {
            GameView(
                session: session,
                scene: scene,
                settings: settings,
                ads: ads,
                isPaused: screen == .home || isPauseMenuShown,
                onPause: pause,
                onHome: goHome
            )
            .accessibilityHidden(screen == .home || isPauseMenuShown)

            if isPauseMenuShown {
                PauseMenu(
                    onResume: { isPauseMenuShown = false },
                    onRestart: { abandonGame(then: restart) },
                    onSettings: { isSettingsShown = true },
                    onQuit: { abandonGame(then: goHome) }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }

            if screen == .home {
                HomeView(
                    scene: scene,
                    record: settings.bestScore,
                    onPlay: play,
                    onLeaderboard: { openLeaderboard() },
                    onSettings: { isSettingsShown = true }
                )
                .accessibilityHidden(blocker != nil)
                .transition(.opacity)
            }

            if let blocker {
                BlockerView(blocker: blocker)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: screen)
        .animation(.easeInOut(duration: 0.3), value: blocker)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isPauseMenuShown)
        .tint(Color(uiColor: Palette.accent))
        .sheet(isPresented: $isSettingsShown) {
            SettingsView(settings: settings, ads: ads)
                // Sheets do not inherit the tint of the screen that presents them.
                .tint(Color(uiColor: Palette.accent))
        }
        .sheet(isPresented: $isLeaderboardShown) {
            LeaderboardView(gameCenter: gameCenter)
                .tint(Color(uiColor: Palette.accent))
        }
        // Consentement (et demande de suivi) seulement depuis l'accueil, quand rien ne bloque l'accès au jeu :
        // jamais par-dessus une partie, ni par-dessus l'écran « pas de connexion » ou « mise à jour requise ».
        // Revenir à l'accueil, ou retrouver la connexion, relance ce qui n'a pas pu se faire.
        .task(id: mayShowAdPrompts) {
            ads.canInterruptPlayer = mayShowAdPrompts
            if mayShowAdPrompts { await ads.start() }
        }
        .task {
            connectivity.start()
            await updates.check()
        }
        .onChange(of: connectivity.isOnline) { _, isOnline in
            // The check at launch fails without a connection: try again as soon as it is back.
            if isOnline { Task { await updates.check() } }
        }
        .task {
            gameCenter.authenticate()
            gameCenter.submit(settings.bestScore)
        }
        .onChange(of: gameCenter.isAuthenticated) { _, isSignedIn in
            // A reinstalled game starts without a record: Game Center still has it.
            guard isSignedIn else { return }
            Task {
                if let remote = await gameCenter.loadMyScore() {
                    settings.recordScore(remote)
                }
            }
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .gameOver { gameCenter.submit(settings.bestScore) }
        }
        .onChange(of: settings.isSoundOn, initial: true) { _, _ in applyFeedbackSettings() }
        .onChange(of: settings.isHapticsOn) { _, _ in applyFeedbackSettings() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scene.resumeFeedback()
                // A game left open for days may have been updated on the store in the meantime.
                if screen == .home { Task { await updates.check() } }
            } else if screen == .game && session.isPlaying {
                // Leaving the app mid-round: come back to the pause menu, never to a running tower.
                pause()
            }
        }
    }

    /// Only blocks from the home screen: a game already started is never cut, the block waits for its end.
    private var blocker: PlayBlocker? {
        PlayBlocker.current(
            isOnline: connectivity.isOnline,
            requiredUpdate: updates.requiredUpdate,
            isInGame: screen == .game
        )
    }

    /// Le joueur est sur l'accueil et peut jouer : un formulaire de consentement ou l'alerte de suivi ne coupe rien.
    private var mayShowAdPrompts: Bool {
        screen == .home && blocker == nil
    }

    private func play() {
        scene.startNewGame()
        isPauseMenuShown = false
        screen = .game
    }

    /// Starting over or quitting in the middle of a game counts as a finished game, so the ads cannot be dodged
    /// by never losing.
    private func abandonGame(then action: @escaping () -> Void) {
        guard !isAbandoningGame else { return }
        isAbandoningGame = true
        settings.registerFinishedGame()
        gameCenter.submit(settings.bestScore)
        Task {
            await ads.presentIfDue(settings)
            isAbandoningGame = false
            action()
        }
    }

    private func restart() {
        scene.startNewGame()
        isPauseMenuShown = false
    }

    private func pause() {
        scene.prepareForPause()
        isPauseMenuShown = true
    }

    private func openLeaderboard() {
        gameCenter.submit(settings.bestScore)
        isLeaderboardShown = true
    }

    private func goHome() {
        gameCenter.submit(settings.bestScore)
        scene.prepareForPause()
        isPauseMenuShown = false
        screen = .home
    }

    private func applyFeedbackSettings() {
        scene.setFeedback(sound: settings.isSoundOn, haptics: settings.isHapticsOn)
    }
}
