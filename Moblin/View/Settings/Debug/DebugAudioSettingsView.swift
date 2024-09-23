import SwiftUI

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Bluetooth output only", isOn: Binding(get: {
                    model.database.debug!.bluetoothOutputOnly!
                }, set: { value in
                    model.database.debug!.bluetoothOutputOnly = value
                }))
            } footer: {
                Text("App restart needed to take effect.")
            }
            Section {
                Toggle("Prefer stereo mic", isOn: Binding(get: {
                    model.database.debug!.preferStereoMic!
                }, set: { value in
                    model.database.debug!.preferStereoMic = value
                }))
            } footer: {
                Text("Switching between mono and stereo mics may not work.")
            }
        }
        .navigationTitle("Audio")
    }
}
