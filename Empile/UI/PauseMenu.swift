import SwiftUI

/// Shown over the frozen game: resume, start over, change the settings, or leave the game.
struct PauseMenu: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.25))
                .ignoresSafeArea()
                .onTapGesture(perform: onResume)
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                Text("Pause")
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        Button(action: onResume) {
                            Label("Reprendre", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        Group {
                            Button(action: onRestart) {
                                Label("Nouvelle partie", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            Button(action: onSettings) {
                                Label("Réglages", systemImage: "gearshape")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            Button(role: .destructive, action: onQuit) {
                                Label("Quitter la partie", systemImage: "xmark")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .tint(.red)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .padding(.horizontal, 24)
        }
    }
}
