import SwiftUI

/// Covers the home screen when the game cannot be played: no connection, or a newer version to install first.
struct BlockerView: View {
    let blocker: PlayBlocker
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: Palette.skyTop), Color(uiColor: Palette.skyBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, isActive: blocker == .offline)
                    .frame(width: 128, height: 128)
                    .glassEffect(.regular, in: .circle)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                Spacer()
                footer
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder private var footer: some View {
        switch blocker {
        case .offline:
            HStack(spacing: 10) {
                ProgressView()
                Text("En attente de connexion…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 52)
        case .updateRequired(let update):
            Button {
                openURL(update.storeURL)
            } label: {
                Label("Mettre à jour", systemImage: "arrow.down.circle.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var symbol: String {
        switch blocker {
        case .offline: "wifi.slash"
        case .updateRequired: "arrow.down.app.fill"
        }
    }

    private var title: String {
        switch blocker {
        case .offline: "Pas de connexion"
        case .updateRequired: "Mise à jour requise"
        }
    }

    private var message: String {
        switch blocker {
        case .offline: "Vous devez vous connecter à Internet pour jouer."
        case .updateRequired: "Une nouvelle version est disponible, vous devez la mettre à jour pour jouer."
        }
    }
}
