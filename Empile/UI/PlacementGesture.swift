import SwiftUI

extension View {
    /// Touch the world to take the waiting piece, slide to aim, let go to drop it. While the rope is out,
    /// the same touch catches a piece of the tower and pulls it instead.
    func worldGesture(scene: TowerScene) -> some View {
        modifier(WorldGesture(scene: scene))
    }
}

/// Remembers whether this finger took something, so two fingers never fight over the piece.
private struct WorldGesture: ViewModifier {
    private enum Ownership {
        case idle
        case holding
        /// The finger came down while nothing could be taken: ignore it until it lifts.
        case declined
    }

    let scene: TowerScene
    @State private var ownership = Ownership.idle
    /// Where and when the finger was last seen, in case the system cancels the touch instead of ending it.
    @State private var lastTouch: (location: CGPoint, time: TimeInterval)?
    @GestureState private var isPressing = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($isPressing) { _, pressing, _ in
                        pressing = true
                    }
                    .onChanged { value in
                        let time = value.time.timeIntervalSinceReferenceDate
                        lastTouch = (value.location, time)
                        switch ownership {
                        case .holding:
                            scene.touchMoved(to: value.location, time: time)
                        case .idle:
                            ownership = scene.touchBegan(at: value.location, time: time) ? .holding : .declined
                        case .declined:
                            break
                        }
                    }
                    .onEnded { value in
                        defer { ownership = .idle }
                        guard case .holding = ownership else { return }
                        scene.touchEnded(at: value.location, time: value.time.timeIntervalSinceReferenceDate)
                    }
            )
            .onChange(of: isPressing) { _, pressing in
                // The system cancelled the gesture (no `onEnded`), which happens with a thumb at the very edge
                // of the screen: the piece drops where the finger was last seen.
                guard !pressing else { return }
                if case .holding = ownership, let lastTouch {
                    scene.touchEnded(at: lastTouch.location, time: lastTouch.time)
                }
                ownership = .idle
            }
    }
}
