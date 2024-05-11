import SwiftUI

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Enable RTMP audio", isOn: Binding(get: {
                    model.database.debug!.enableRtmpAudio!
                }, set: { value in
                    model.database.debug!.enableRtmpAudio = value
                    model.store()
                }))
                Toggle("Bluetooth output only", isOn: Binding(get: {
                    model.database.debug!.bluetoothOutputOnly!
                }, set: { value in
                    model.database.debug!.bluetoothOutputOnly = value
                    model.store()
                }))
            } footer: {
                Text("App restart needed to take effect.")
            }
        }
        .navigationTitle("Audio")
        .toolbar {
            SettingsToolbar()
        }
    }
}
