import SwiftUI

/// Open at any time from the header, the world frozen behind: spend gems to improve the pieces in the hand,
/// or to win back a life.
struct ShopView: View {
    let session: GameSession
    let scene: TowerScene
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    pieces
                    life
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            Button(action: onClose) {
                Label("Reprendre", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .padding(20)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .animation(.spring(duration: 0.35, bounce: 0.2), value: session.gems)
        .animation(.spring(duration: 0.4, bounce: 0.25), value: session.hand)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Boutique")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                Text("Chaque palier de \(Tuning.Climb.milestoneFloors) étages rapporte \(Tuning.Climb.milestoneGems) gemmes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GemsLabel(count: session.gems)
                .font(.title2.weight(.bold))
        }
    }

    private var pieces: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Améliorer une pièce", detail: "Choisissez une pièce de votre main.")
            HStack(spacing: 10) {
                ForEach(session.hand) { card in
                    PieceChoice(card: card, isSelected: card.id == session.activeCard?.id, scene: scene) {
                        session.select(card.id)
                    }
                }
            }
            PurchaseButton(title: "Changer de forme", symbol: "arrow.triangle.2.circlepath",
                           detail: "Même matière, une forme différente.",
                           price: Tuning.Shop.reshapePrice, isEnabled: session.canReshape) {
                buy(session.reshapeSelected())
            }
            PurchaseButton(title: "Changer de matière", symbol: "dice",
                           detail: "Même forme, une matière au hasard.",
                           price: Tuning.Shop.rematerialPrice, isEnabled: session.canChangeMaterial) {
                buy(session.changeSelectedMaterial())
            }
        }
    }

    private var life: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "Vies · \(session.lives) sur \(session.maxLives)",
                detail: session.lives < session.maxLives
                    ? "Chaque pièce qui tombe coûte une vie."
                    : "Vos vies sont au complet."
            )
            PurchaseButton(title: "Une vie de plus", symbol: "heart.fill",
                           detail: nil, price: Tuning.Shop.lifePrice, isEnabled: session.canBuyLife) {
                buy(session.buyLife())
            }
        }
    }

    private func buy(_ succeeded: Bool) {
        if succeeded {
            scene.celebratePurchase()
        }
    }
}

/// A headline with one line of explanation under it.
private struct SectionTitle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .monospacedDigit()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// One piece of the hand; the selected one is the one purchases change.
private struct PieceChoice: View {
    let card: Card
    let isSelected: Bool
    let scene: TowerScene
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                BlockImage(scene: scene, kind: card.kind, shape: card.shape, unit: 16)
                    .frame(height: 64)
                PieceBadge(kind: card.kind)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.tint.opacity(isSelected ? 0.18 : 0), in: .rect(cornerRadius: 20))
            .background(.fill.quaternary, in: .rect(cornerRadius: 20))
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(PieceName.of(card.kind, card.shape)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What a purchase does, and its price.
private struct PurchaseButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let detail: LocalizedStringKey?
    let price: Int
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                GemsLabel(count: price)
                    .font(.headline)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.glass)
        .disabled(!isEnabled)
        .accessibilityHint(Text("\(price) gemmes"))
    }
}
