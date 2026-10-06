import SwiftUI

/// At the bottom while playing: the four powers, each with how many are left, and the rotate button.
struct AbilityBar: View {
    let session: GameSession
    let scene: TowerScene
    let onUse: (Ability) -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Ability.allCases) { ability in
                    AbilityButton(
                        ability: ability,
                        count: session.abilities.count(of: ability),
                        isEnabled: session.canUse(ability)
                    ) {
                        onUse(ability)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Button {
                scene.rotateActiveCard()
            } label: {
                Image(systemName: "rotate.right")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(!session.canRotate)
            .accessibilityLabel(Text("Pivoter la pièce"))
            .accessibilityHint(Text("Tourne d'un quart de tour la pièce à poser."))
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

/// One power: its icon and name, and a badge with how many are left.
private struct AbilityButton: View {
    let ability: Ability
    let count: Int
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: ability.symbol)
                    .font(.title2.weight(.semibold))
                    .frame(height: 28)
                Text(ability.title)
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(.fill.quaternary, in: .rect(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                CountBadge(count: count)
                    .padding(4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: count)
        .accessibilityLabel(Text("\(ability.title), \(count) restant"))
        .accessibilityHint(Text(ability.summary))
    }
}

/// A small, discreet count in a corner: how many are left.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(Color.secondary)
            .contentTransition(.numericText(value: Double(count)))
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(.fill.tertiary, in: .capsule)
            .accessibilityHidden(true)
    }
}

/// Top right: a small preview of the next two pieces, in the order they come. Nothing to touch.
struct UpcomingPieces: View {
    let session: GameSession
    let scene: TowerScene

    var body: some View {
        HStack(spacing: 8) {
            Text("Ensuite")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ForEach(session.upcoming) { card in
                BlockImage(scene: scene, kind: card.kind, shape: card.shape, unit: 8)
                    .frame(width: 34, height: 34)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Text(PieceName.of(card.kind, card.shape)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .allowsHitTesting(false)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: session.upcoming.map(\.id))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Pièces suivantes"))
    }
}

/// Top left: watch an ad for a power drawn at random, with how many ads are left this game.
struct AdRewardButton: View {
    let left: Int
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: Tuning.Ads.isEnabled ? "play.rectangle.fill" : "gift.fill")
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .disabled(!isEnabled)
        .overlay(alignment: .topTrailing) {
            CountBadge(count: left)
                .padding(5)
                .allowsHitTesting(false)
        }
        .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 4)), isActive: isEnabled)
        .accessibilityLabel(Text("Regarder une pub pour gagner un pouvoir, \(left) restantes"))
    }
}

/// Under the header while the rope is out: how long is left.
struct PullTimer: View {
    let timeLeft: TimeInterval

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: timeLeft / Tuning.Abilities.pullDuration)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timeLeft)
            }
            .frame(width: 26, height: 26)
            Text("Touchez une pièce et tirez")
                .font(.subheadline.weight(.semibold))
            Text("\(Int(timeLeft.rounded(.up))) s")
                .font(.headline)
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Grappin : \(Int(timeLeft.rounded(.up))) secondes. Touchez une pièce et tirez."))
    }
}
