import SwiftUI

struct DebugAudioSettingsView: View {
    @ObservedObject var debug: SettingsDebug

    var body: some View {
        Form {
            Section {
                Toggle("Remove wind noise", isOn: $debug.removeWindNoise)
            } footer: {
                Text("App restart needed to take effect.")
            }
        }
        .navigationTitle("Audio")
    }
}
