import SwiftUI

/// What takes the screen when a power comes into play.
enum AbilityStage: Equatable {
    /// Every power starts the same way: the screen dims and its icon bursts out in the middle.
    case activating(Ability)
    /// A shape change: the player picks the piece to change.
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

/// The power bursting out in its own color: rays spin behind it, shockwaves and sparks fly out, the medal spins
/// in and its name slams down. Nothing more to read.
private struct AbilityBurst: View {
    let ability: Ability
    @State private var isOut = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [ability.color.opacity(0.55), .clear], center: .center, startRadius: 10,
                           endRadius: 320)
                .scaleEffect(isOut ? 1.15 : 0.3)
                .opacity(isOut ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: isOut)
                .ignoresSafeArea()
            BurstRays(color: ability.color)
                .frame(width: 520, height: 520)
                .scaleEffect(isOut ? 1 : 0.2)
                .opacity(isOut ? 0.9 : 0)
                .animation(.spring(duration: 0.6, bounce: 0.3), value: isOut)
                // Wider than the screen: drawn over the edges without widening the layout.
                .frame(width: 0, height: 0)
            ForEach(0..<3) { wave in
                Circle()
                    .stroke(ability.color, lineWidth: 8 - CGFloat(wave) * 2)
                    .frame(width: 130, height: 130)
                    .scaleEffect(isOut ? 3.2 : 0.5)
                    .opacity(isOut ? 0 : 0.95)
                    .animation(.easeOut(duration: 0.75).delay(Double(wave) * 0.12), value: isOut)
            }
            BurstSparks(color: ability.color, isOut: isOut)
            VStack(spacing: 22) {
                AbilityMedal(ability: ability, size: 128)
                    .keyframeAnimator(initialValue: BurstPose(), trigger: isOut) { content, pose in
                        content
                            .scaleEffect(pose.scale)
                            .rotationEffect(.degrees(pose.spin))
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.4, duration: 0.22)
                            SpringKeyframe(0.92, duration: 0.18)
                            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                        }
                        KeyframeTrack(\.spin) {
                            CubicKeyframe(20, duration: 0.3)
                            SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                        }
                    }
                    .symbolEffect(.bounce, value: isOut)
                Text(ability.title)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: ability.color, radius: 18)
                    .shadow(color: ability.color.opacity(0.8), radius: 4)
                    .scaleEffect(isOut ? 1 : 2.6)
                    .opacity(isOut ? 1 : 0)
                    .animation(.spring(duration: 0.35, bounce: 0.45).delay(0.15), value: isOut)
            }
        }
        .onAppear { isOut = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ability.title))
    }
}

/// The medal's pop: how big it is and how far it has turned.
private struct BurstPose {
    var scale: CGFloat = 0.1
    var spin: Double = -200
}

/// Light rays turning slowly behind a power.
private struct BurstRays: View {
    let color: Color
    private let count = 14

    var body: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) / 12 * 360
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let half = Double.pi / Double(count) * 0.45
                for ray in 0..<count {
                    let middle = Double(ray) / Double(count) * 2 * .pi
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addArc(center: center, radius: radius, startAngle: .radians(middle - half),
                                 endAngle: .radians(middle + half), clockwise: false)
                    wedge.closeSubpath()
                    context.fill(wedge, with: .radialGradient(
                        Gradient(colors: [color.opacity(0.7), color.opacity(0)]),
                        center: center, startRadius: 0, endRadius: radius))
                }
            }
            .rotationEffect(.degrees(angle))
        }
        .allowsHitTesting(false)
    }
}

/// Sparks thrown out in every direction, each its own distance and size, fading as they go.
private struct BurstSparks: View {
    let color: Color
    let isOut: Bool
    private let count = 22

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = Double(index) / Double(count) * 2 * .pi + Double(index % 3) * 0.2
                let distance = 140 + CGFloat((index * 37) % 90)
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "circle.fill")
                    .font(.system(size: index.isMultiple(of: 3) ? 22 : CGFloat(6 + index % 4 * 2)))
                    .foregroundStyle(index.isMultiple(of: 2) ? color : .white)
                    .shadow(color: color, radius: 6)
                    .offset(x: isOut ? cos(angle) * distance : 0, y: isOut ? sin(angle) * distance : 0)
                    .scaleEffect(isOut ? 0.4 : 1.2)
                    .opacity(isOut ? 0 : 1)
                    .animation(.easeOut(duration: 0.8 + Double(index % 5) * 0.06), value: isOut)
            }
        }
        .allowsHitTesting(false)
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
            .background(
                LinearGradient(colors: [ability.color.mix(with: .white, by: 0.25), ability.color],
                               startPoint: .top, endPoint: .bottom),
                in: .circle
            )
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: max(2, size * 0.03)))
            .shadow(color: ability.color.opacity(0.8), radius: size * 0.25)
    }
}

/// "Which piece?": the piece to place and the next two. The changed piece shows its new look for a
/// moment, then the game goes on.
private struct PiecePicker: View {
    let ability: Ability
    let session: GameSession
    let scene: TowerScene
    let onPick: (Card.ID, Ability) -> Bool
    let onClose: () -> Void
    @State private var changedID: Card.ID?

    private var pieces: [Card] {
        session.activeCard.map { [$0] + session.upcoming } ?? session.upcoming
    }

    var body: some View {
        VStack(spacing: 20) {
            AbilityMedal(ability: ability, size: 64)
            Text(changedID == nil ? "Laquelle ?" : "Hop !")
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
                            Text(index == 0 ? "À poser" : "Ensuite")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(ability.color, lineWidth: changedID == card.id ? 3 : 0)
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

extension Ability {
    /// Each power has its own color, from its button to its burst.
    var color: Color {
        switch self {
        case .reshape: Color(red: 0.62, green: 0.38, blue: 1)
        case .freeze: Color(red: 0.2, green: 0.75, blue: 1)
        case .pull: Color(red: 1, green: 0.55, blue: 0.15)
        case .extraLife: Color(red: 1, green: 0.27, blue: 0.42)
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
            Text(isDone ? "+1 \(won.title)" : "Roulette !")
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
