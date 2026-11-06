import SwiftUI

/// Sound and vibration switches, and the privacy choices for ads when the law requires them.
struct SettingsView: View {
    @Bindable var settings: GameSettings
    let ads: AdManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $settings.isSoundOn) {
                        Label("Sons", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $settings.isHapticsOn) {
                        Label("Vibrations", systemImage: "iphone.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Retours")
                } footer: {
                    Text("Les sons suivent aussi le mode silencieux de l'iPhone.")
                }

                // Exigé par le formulaire de consentement Google (Europe notamment) : le joueur doit pouvoir
                // revenir sur ses choix à tout moment. Ailleurs, la ligne n'apparaît pas.
                if ads.isPrivacyOptionsRequired {
                    Section {
                        Button {
                            Task { await ads.presentPrivacyOptions() }
                        } label: {
                            Label("Gérer mes choix de confidentialité", systemImage: "hand.raised.fill")
                        }
                    } header: {
                        Text("Publicités")
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension Bundle {
    var versionDescription: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }
}
