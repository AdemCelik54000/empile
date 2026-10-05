import SwiftUI

/// The pieces to choose from (each one placed is replaced at once), and the rotate button. Tap a block to select it (touching the screen
/// then places it), or drag it straight out of the hand.
struct HandTray: View {
    let session: GameSession
    let scene: TowerScene
    /// Where the hand is on screen, in global coordinates: letting go over it puts the block back.
    let frame: CGRect

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(session.hand) { card in
                    CardCell(card: card, session: session, scene: scene, handFrame: frame)
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
            .accessibilityLabel(Text("Pivoter le bloc"))
            .accessibilityHint(Text("Tourne d'un quart de tour le bloc choisi ou celui que vous tenez."))
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

/// One piece of the hand, drawn exactly as it looks in the game, with its material.
private struct CardCell: View {
    let card: Card
    let session: GameSession
    let scene: TowerScene
    let handFrame: CGRect

    private var isHeld: Bool { session.heldCardID == card.id }
    private var isSelected: Bool { session.selectedCardID == card.id && session.heldCardID == nil }

    var body: some View {
        VStack(spacing: 4) {
            BlockImage(scene: scene, kind: card.kind, shape: card.shape, unit: Tuning.HUD.previewUnit)
                .frame(maxHeight: .infinity)
            PieceBadge(kind: card.kind)
        }
        .frame(maxWidth: Tuning.HUD.cardSize)
        .frame(height: Tuning.HUD.cardSize + 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.tint.opacity(isSelected ? 0.18 : 0))
        }
        .contentShape(.rect)
        .opacity(isHeld ? 0 : 1)
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
        .animation(.spring(duration: 0.25), value: isHeld)
        .onTapGesture {
            session.select(card.id)
        }
        .placementGesture(scene: scene, minimumDistance: Tuning.HUD.dragThreshold, handFrame: handFrame) {
            card.id
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(PieceName.of(card.kind, card.shape)))
        .accessibilityHint(Text(card.definition.summary))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text("Lâcher sur la tour")) {
            scene.dropAboveTower(cardID: card.id)
        }
    }
}
