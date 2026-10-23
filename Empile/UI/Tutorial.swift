import SwiftUI

/// The first game ever (no record yet) shows how to play: a ring pulses on the waiting piece with "touch the
/// screen to take it", then, once a finger holds it, how to aim, drop and turn it with a second finger.
enum TutorialStep: Equatable {
    case take
    case aim(canTurn: Bool)
}

/// The app runs on a Mac (Apple silicon): a mouse and the keyboard replace the fingers.
enum MacInput {
    static let isActive = ProcessInfo.processInfo.isiOSAppOnMac
}

/// A pulsing ring, drawn where the player should touch.
struct TutorialRing: View {
    var label: String?
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: Palette.accent), lineWidth: 4)
                .scaleEffect(isPulsing ? 1.35 : 0.85)
                .opacity(isPulsing ? 0 : 0.9)
            Circle()
                .fill(Color(uiColor: Palette.accent).opacity(0.18))
                .overlay(Circle().stroke(Color(uiColor: Palette.accent), lineWidth: 3))
                .scaleEffect(isPulsing ? 1 : 0.9)
            if let label {
                Text(label)
                    .font(.title3.weight(.heavy))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color(uiColor: Palette.accent))
            }
        }
        .frame(width: Tuning.Tutorial.ringSize, height: Tuning.Tutorial.ringSize)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

/// The rings over the world: on the waiting piece, then where to tap with a second finger.
struct TutorialRings: View {
    let step: TutorialStep
    let scene: TowerScene

    var body: some View {
        GeometryReader { proxy in
            switch step {
            case .take:
                TimelineView(.animation) { _ in
                    if let point = scene.readyPointInView {
                        TutorialRing()
                            .position(point)
                    }
                }
            case .aim(let canTurn):
                if canTurn && !MacInput.isActive {
                    TutorialRing(label: "2")
                        .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.55)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// What to do now, in a bubble above the powers.
struct TutorialBubble: View {
    let step: TutorialStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch step {
            case .take:
                if MacInput.isActive {
                    Label("Cliquez sur la pièce pour la prendre", systemImage: "cursorarrow.click")
                } else {
                    Label("Touchez l'écran pour prendre la pièce", systemImage: "hand.tap.fill")
                }
            case .aim(let canTurn):
                if MacInput.isActive {
                    Label("Glissez pour viser, relâchez pour poser", systemImage: "cursorarrow.motionlines")
                    if canTurn {
                        Label("Appuyez sur Espace pour tourner la pièce", systemImage: "rotate.right.fill")
                    }
                } else {
                    Label("Glissez pour viser, lâchez pour poser", systemImage: "hand.draw.fill")
                    if canTurn {
                        Label("Gardez le doigt posé et touchez avec un 2ᵉ doigt pour tourner la pièce",
                              systemImage: "rotate.right.fill")
                    }
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(Color(uiColor: Palette.accent).opacity(0.15)), in: .rect(cornerRadius: 20))
    }
}
