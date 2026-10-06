import SwiftUI
import UIKit

extension View {
    /// Touch the world to take the waiting piece, slide to aim, let go to drop it. While the rope is out,
    /// the same touch catches a piece of the tower and pulls it instead. While a finger holds the piece, a tap
    /// with a second finger turns it.
    func worldGesture(scene: TowerScene) -> some View {
        overlay(WorldTouchSurface(scene: scene).ignoresSafeArea())
    }
}

/// A clear surface over the world that follows each finger on its own, so a second finger never steals the
/// piece from the first one.
private struct WorldTouchSurface: UIViewRepresentable {
    let scene: TowerScene

    func makeUIView(context: Context) -> WorldTouchView {
        let view = WorldTouchView()
        view.scene = scene
        return view
    }

    func updateUIView(_ view: WorldTouchView, context: Context) {
        view.scene = scene
    }
}

final class WorldTouchView: UIView {
    weak var scene: TowerScene?
    /// The finger holding the piece (or the rope). Every other finger is only a tap to turn the piece.
    private var owner: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let scene else { return }
        for touch in touches {
            if owner == nil {
                // In window coordinates, the same as the world view, which fills the screen.
                if scene.touchBegan(at: touch.location(in: nil), time: touch.timestamp) {
                    owner = touch
                }
            } else {
                scene.secondFingerTapped()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let owner, touches.contains(owner) else { return }
        scene?.touchMoved(to: owner.location(in: nil), time: owner.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    /// The system can cancel a touch instead of ending it, with a thumb at the very edge of the screen: the piece
    /// drops where the finger was last seen.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        guard let owner, touches.contains(owner) else { return }
        self.owner = nil
        scene?.touchEnded(at: owner.location(in: nil), time: owner.timestamp)
    }
}
