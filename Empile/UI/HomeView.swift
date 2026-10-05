import SwiftUI

/// The first screen: the game's name over a little tower that stacks itself, and the way in.
struct HomeView: View {
    let scene: TowerScene
    /// The best score ever, in points.
    let record: Int
    let onPlay: () -> Void
    let onLeaderboard: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: Palette.skyTop), Color(uiColor: Palette.skyBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                TowerLogo(scene: scene)
                VStack(spacing: 6) {
                    Text("Empile")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text("Empilez. Combinez. Visez haut.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if record > 0 {
                        Label("Record : \(record.formatted()) points", systemImage: "trophy.fill")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(.tint)
                            .padding(.top, 10)
                    }
                }
                .padding(.top, 28)
                Spacer(minLength: 24)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private var buttons: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                Button(action: onPlay) {
                    Label("Jouer", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.glassProminent)
                HStack(spacing: 12) {
                    Button(action: onLeaderboard) {
                        Label("Classement", systemImage: "trophy")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    Button(action: onSettings) {
                        Label("Réglages", systemImage: "gearshape")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}

/// Four blocks dropping onto a platform one after the other, like a first tower.
private struct TowerLogo: View {
    private struct Layer: Identifiable {
        let id: Int
        let kind: BlockKind
        let shape: BlockShape
        let tilt: Angle
    }

    private static let unit: CGFloat = 34
    /// Top to bottom.
    private static let layers = [
        Layer(id: 3, kind: .gold, shape: .mono, tilt: .degrees(-7)),
        Layer(id: 2, kind: .glass, shape: .domino, tilt: .zero),
        Layer(id: 1, kind: .spring, shape: .domino, tilt: .zero),
        Layer(id: 0, kind: .stone, shape: .bar3, tilt: .zero),
    ]

    let scene: TowerScene
    @State private var isStacked = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: BlockImage.shadowOverlap(unit: Self.unit)) {
                ForEach(Self.layers) { layer in
                    BlockImage(scene: scene, kind: layer.kind, shape: layer.shape, unit: Self.unit)
                        .rotationEffect(layer.tilt)
                        .offset(y: isStacked ? 0 : -420)
                        .opacity(isStacked ? 1 : 0)
                        .animation(
                            .spring(duration: 0.6, bounce: 0.35).delay(0.15 + Double(layer.id) * 0.14),
                            value: isStacked
                        )
                }
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(uiColor: Palette.platform))
                .frame(width: Self.unit * 5, height: 16)
        }
        .onAppear { isStacked = true }
        .accessibilityHidden(true)
    }
}
