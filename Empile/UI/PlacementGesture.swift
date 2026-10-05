import SwiftUI

extension View {
    /// Touch to take a block, slide to aim, let go to drop it. Used on the whole screen (the selected card)
    /// and on each card of the hand (that card).
    /// - Parameters:
    ///   - minimumDistance: 0 takes the block as soon as the finger touches down.
    ///   - handFrame: Letting go over the hand puts the block back, as long as it never left the hand.
    ///   - card: The card to take when the finger comes down, if any.
    func placementGesture(
        scene: TowerScene,
        minimumDistance: CGFloat,
        handFrame: CGRect,
        card: @escaping () -> Card.ID?
    ) -> some View {
        modifier(PlacementGesture(scene: scene, minimumDistance: minimumDistance, handFrame: handFrame, card: card))
    }
}

/// Each gesture remembers whether it is the one holding the block, so two fingers never fight over it.
private struct PlacementGesture: ViewModifier {
    private enum Ownership {
        case idle
        /// Once the block has been taken out of the hand, it can no longer go back.
        case holding(hasLeftHand: Bool)
        /// The finger came down while nothing could be taken: ignore it until it lifts.
        case declined
    }

    let scene: TowerScene
    let minimumDistance: CGFloat
    let handFrame: CGRect
    let card: () -> Card.ID?
    @State private var ownership = Ownership.idle
    /// Where and when the finger was last seen, in case the system cancels the touch instead of ending it.
    @State private var lastTouch: (location: CGPoint, time: TimeInterval)?
    @GestureState private var isPressing = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
                    .updating($isPressing) { _, pressing, _ in
                        pressing = true
                    }
                    .onChanged { value in
                        let time = value.time.timeIntervalSinceReferenceDate
                        let isOverHand = handFrame.contains(value.location)
                        lastTouch = (value.location, time)
                        switch ownership {
                        case .holding(let hasLeftHand):
                            scene.moveDrag(to: value.location, time: time)
                            if !hasLeftHand && !isOverHand {
                                ownership = .holding(hasLeftHand: true)
                            }
                        case .idle:
                            let taken = card().map { scene.beginDrag(cardID: $0, at: value.location, time: time) }
                            ownership = taken == true ? .holding(hasLeftHand: !isOverHand) : .declined
                        case .declined:
                            break
                        }
                    }
                    .onEnded { value in
                        defer { ownership = .idle }
                        guard case .holding(let hasLeftHand) = ownership else { return }
                        // Letting go over the hand puts the block back, unless it was already taken out.
                        scene.endDrag(at: value.location, time: value.time.timeIntervalSinceReferenceDate,
                                      returnsToHand: !hasLeftHand && handFrame.contains(value.location))
                    }
            )
            .onChange(of: isPressing) { _, pressing in
                // The system cancelled the gesture (no `onEnded`), which happens with a thumb at the very bottom
                // of the screen. A block still in the hand goes back; one already taken out is dropped where the
                // finger was, never put back.
                guard !pressing else { return }
                if case .holding(let hasLeftHand) = ownership {
                    if hasLeftHand, let lastTouch {
                        scene.endDrag(at: lastTouch.location, time: lastTouch.time, returnsToHand: false)
                    } else {
                        scene.cancelDrag()
                    }
                }
                ownership = .idle
            }
    }
}
