import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.audio!.audioOutputToInputChannelsMap!.channel1 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated()
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        model.database.audio!.audioOutputToInputChannelsMap!.channel2 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Output channel 1"),
                    value: String(model.database.audio!.audioOutputToInputChannelsMap!.channel1 + 1),
                    onSubmit: submitOutputChannel1
                )
                .disabled(model.isLive || model.isRecording)
                TextEditNavigationView(
                    title: String(localized: "Output channel 2"),
                    value: String(model.database.audio!.audioOutputToInputChannelsMap!.channel2 + 1),
                    onSubmit: submitOutputChannel2
                )
                .disabled(model.isLive || model.isRecording)
            } header: {
                Text("Input to output channel mapping")
            } footer: {
                Text("Mono audio only uses output channel 1. Stereo audio uses both output channels.")
            }
        }
        .navigationTitle("Audio")
    }
}
