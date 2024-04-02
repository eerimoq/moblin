import HaishinKit
import SwiftUI

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.debug!.audioOutputToInputChannelsMap!.channel0 = max(channel - 1, -1)
        model.store()
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.debug!.audioOutputToInputChannelsMap!.channel1 = max(channel - 1, -1)
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: "Output channel 1",
                    value: String(model.database.debug!.audioOutputToInputChannelsMap!.channel0 + 1),
                    onSubmit: submitOutputChannel1
                )
                TextEditNavigationView(
                    title: "Output channel 2",
                    value: String(model.database.debug!.audioOutputToInputChannelsMap!.channel1 + 1),
                    onSubmit: submitOutputChannel2
                )
            } header: {
                Text("Channels mapping")
            }
            Section {
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
