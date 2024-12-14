import SwiftUI

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Remove wind noise", isOn: Binding(get: {
                    model.database.debug.removeWindNoise!
                }, set: { value in
                    model.database.debug.removeWindNoise = value
                }))
            } footer: {
                Text("App restart needed to take effect.")
            }
        }
        .navigationTitle("Audio")
    }
}
