import HaishinKit
import SwiftUI

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.debug!.audioOutputToInputChannelsMap!.channel0 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated()
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.debug!.audioOutputToInputChannelsMap!.channel1 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Output channel 1 (Left)"),
                    value: String(model.database.debug!.audioOutputToInputChannelsMap!.channel0 + 1),
                    onSubmit: submitOutputChannel1
                )
                .disabled(model.isLive || model.isRecording)
                TextEditNavigationView(
                    title: String(localized: "Output channel2 2 (Right)"),
                    value: String(model.database.debug!.audioOutputToInputChannelsMap!.channel1 + 1),
                    onSubmit: submitOutputChannel2
                )
                .disabled(model.isLive || model.isRecording)
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
