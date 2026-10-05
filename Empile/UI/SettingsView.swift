import SwiftUI

/// Sound and vibration switches.
struct SettingsView: View {
    @Bindable var settings: GameSettings
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
