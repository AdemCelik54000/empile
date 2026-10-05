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
    @State private var screen = Screen.home
    @State private var isPauseMenuShown = false
    @State private var isSettingsShown = false
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
                    onSettings: { isSettingsShown = true }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: screen)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isPauseMenuShown)
        .tint(Color(uiColor: Palette.accent))
        .sheet(isPresented: $isSettingsShown) {
            SettingsView(settings: settings)
                // Sheets do not inherit the tint of the screen that presents them.
                .tint(Color(uiColor: Palette.accent))
        }
        .task { await ads.start() }
        .onChange(of: settings.isSoundOn, initial: true) { _, _ in applyFeedbackSettings() }
        .onChange(of: settings.isHapticsOn) { _, _ in applyFeedbackSettings() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scene.resumeFeedback()
            } else if screen == .game && session.isPlaying {
                // Leaving the app mid-round: come back to the pause menu, never to a running tower.
                pause()
            }
        }
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

    private func goHome() {
        scene.prepareForPause()
        isPauseMenuShown = false
        screen = .home
    }

    private func applyFeedbackSettings() {
        scene.setFeedback(sound: settings.isSoundOn, haptics: settings.isHapticsOn)
    }
}
