import SwiftUI

/// The all-time ranking of the players, straight from Game Center.
struct LeaderboardView: View {
    let gameCenter: GameCenterManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case loading
        case loaded([GameCenterManager.Row])
        case failed
    }

    @State private var phase = Phase.loading

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Classement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) { dismiss() }
                    }
                }
        }
        .task(id: gameCenter.isAuthenticated) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("Classement indisponible", systemImage: "trophy")
            } description: {
                Text(gameCenter.isAuthenticated
                    ? "Vérifiez votre connexion et réessayez."
                    : "Connectez-vous à Game Center dans les Réglages de l'iPhone.")
            } actions: {
                Button("Réessayer") { Task { await load() } }
                    .buttonStyle(.glass)
            }
        case .loaded(let rows) where rows.isEmpty:
            ContentUnavailableView(
                "Aucun score",
                systemImage: "trophy",
                description: Text("Soyez le premier du classement.")
            )
        case .loaded(let rows):
            List(rows) { row in
                HStack(spacing: 14) {
                    Text("\(row.rank)")
                        .font(.headline)
                        .monospacedDigit()
                        .frame(minWidth: 32, alignment: .leading)
                    Text(row.name).lineLimit(1)
                    Spacer()
                    Text(row.score)
                        .font(.headline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                }
                .fontWeight(row.isMe ? .bold : .regular)
                .foregroundStyle(row.isMe ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func load() async {
        guard gameCenter.isAuthenticated else {
            phase = .failed
            return
        }
        phase = .loading
        do {
            phase = .loaded(try await gameCenter.loadTop())
        } catch {
            phase = .failed
        }
    }
}
