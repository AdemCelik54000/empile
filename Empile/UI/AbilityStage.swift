import SwiftUI

/// What takes the screen when a power comes into play.
enum AbilityStage: Equatable {
    /// Every power starts the same way: the screen dims and its icon bursts out in the middle.
    case activating(Ability)
    /// A shape or material change: the player picks the piece to change.
    case picking(Ability)
    /// After an ad: a roulette over the four powers stops on the one won.
    case roulette(won: Ability)
}

/// Over the frozen game: a dimmed screen with the power in the middle.
struct AbilityStageView: View {
    let stage: AbilityStage
    let session: GameSession
    let scene: TowerScene
    /// The player picked a piece: returns whether the change happened.
    let onPick: (Card.ID, Ability) -> Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.5))
                .ignoresSafeArea()
                .transition(.opacity)
            switch stage {
            case .activating(let ability):
                AbilityBurst(ability: ability)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            case .picking(let ability):
                PiecePicker(ability: ability, session: session, scene: scene, onPick: onPick, onClose: onClose)
                    .padding(.horizontal)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .roulette(let won):
                AbilityRoulette(won: won, scene: scene, onClose: onClose)
                    .padding(.horizontal)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.25), value: stage)
    }
}

/// The icon of a power bursting out: it pops up, a ring of light spreads out from it, and its name appears.
private struct AbilityBurst: View {
    let ability: Ability
    @State private var isOut = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.tint, lineWidth: 6)
                    .frame(width: 130, height: 130)
                    .scaleEffect(isOut ? 1.9 : 0.6)
                    .opacity(isOut ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.6), value: isOut)
                AbilityMedal(ability: ability, size: 120)
                    .keyframeAnimator(initialValue: 0.2, trigger: isOut) { content, scale in
                        content.scaleEffect(scale)
                    } keyframes: { _ in
                        SpringKeyframe(1.25, duration: 0.22)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
            }
            VStack(spacing: 4) {
                Text(ability.title)
                    .font(.largeTitle.weight(.heavy))
                    .fontDesign(.rounded)
                Text(ability.summary)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .opacity(isOut ? 1 : 0)
            .offset(y: isOut ? 0 : 12)
            .animation(.spring(duration: 0.4).delay(0.12), value: isOut)
        }
        .onAppear { isOut = true }
        .accessibilityElement(children: .combine)
    }
}

/// A power's icon in a glowing round medal.
struct AbilityMedal: View {
    let ability: Ability
    let size: CGFloat

    var body: some View {
        Image(systemName: ability.symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.tint, in: .circle)
            .shadow(color: Color(uiColor: Palette.accent).opacity(0.6), radius: size * 0.2)
    }
}

/// "Which piece?": the piece to place and the two in reserve. The changed piece shows its new look for a
/// moment, then the game goes on.
private struct PiecePicker: View {
    let ability: Ability
    let session: GameSession
    let scene: TowerScene
    let onPick: (Card.ID, Ability) -> Bool
    let onClose: () -> Void
    @State private var changedID: Card.ID?

    private var pieces: [Card] {
        session.activeCard.map { [$0] + session.reserve } ?? session.reserve
    }

    var body: some View {
        VStack(spacing: 20) {
            AbilityMedal(ability: ability, size: 64)
            Text(changedID == nil ? "Choisissez une pièce" : "C'est fait !")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            HStack(spacing: 10) {
                ForEach(Array(pieces.enumerated()), id: \.element.id) { index, card in
                    Button {
                        guard changedID == nil, onPick(card.id, ability) else { return }
                        changedID = card.id
                        Task {
                            guard (try? await Task.sleep(for: .seconds(Tuning.Abilities.changeDisplayDuration)))
                                    != nil
                            else { return }
                            onClose()
                        }
                    } label: {
                        VStack(spacing: 6) {
                            BlockImage(scene: scene, kind: card.kind, shape: card.shape, unit: 18)
                                .frame(height: 84)
                                .id("\(card.kind)\(card.shape)")
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                            PieceBadge(kind: card.kind)
                            Text(index == 0 ? "À poser" : "Réserve")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.tint, lineWidth: changedID == card.id ? 3 : 0)
                        }
                        .scaleEffect(changedID == card.id ? 1.08 : 1)
                        .opacity(changedID == nil || changedID == card.id ? 1 : 0.4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(PieceName.of(card.kind, card.shape)))
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.4), value: session.hand)
            .animation(.spring(duration: 0.35), value: changedID)
            Button("Annuler", action: onClose)
                .buttonStyle(.glass)
                .opacity(changedID == nil ? 1 : 0)
                .disabled(changedID != nil)
        }
    }
}

/// Spins over the four powers, slower and slower, and stops on the one won.
private struct AbilityRoulette: View {
    let won: Ability
    let scene: TowerScene
    let onClose: () -> Void
    @State private var highlighted = 0
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 22) {
            Text(isDone ? "+1 \(won.title)" : "Roulette des pouvoirs")
                .font(.title.weight(.heavy))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            HStack(spacing: 12) {
                ForEach(Array(Ability.allCases.enumerated()), id: \.element) { index, ability in
                    let isOn = index == highlighted
                    AbilityMedal(ability: ability, size: 62)
                        .saturation(isOn ? 1 : 0)
                        .opacity(isOn ? 1 : 0.45)
                        .scaleEffect(isOn ? (isDone ? 1.3 : 1.12) : 0.9)
                        .animation(.spring(duration: 0.18), value: highlighted)
                        .animation(.spring(duration: 0.5, bounce: 0.5), value: isDone)
                }
            }
            if isDone {
                Text(won.summary)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: isDone)
        .task { await spin() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDone ? "Vous gagnez : \(won.title)" : "La roulette tourne"))
    }

    private func spin() async {
        let all = Ability.allCases
        let target = all.firstIndex(of: won) ?? 0
        let steps = Tuning.Abilities.rouletteTurns * all.count + target
        let delays = Tuning.Abilities.rouletteStepDelay
        for step in 1...max(steps, 1) {
            // Eases out: each step lasts a little longer than the one before.
            let progress = Double(step) / Double(max(steps, 1))
            let delay = delays.lowerBound + (delays.upperBound - delays.lowerBound) * progress * progress
            guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return }
            highlighted = step % all.count
            scene.playTick()
        }
        isDone = true
        scene.celebrateAbility()
        guard (try? await Task.sleep(for: .seconds(Tuning.Abilities.rouletteResultDuration))) != nil else { return }
        onClose()
    }
}
