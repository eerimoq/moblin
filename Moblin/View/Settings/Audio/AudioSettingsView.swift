import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        database.audio.audioOutputToInputChannelsMap!.channel1 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated(updateRemoteScene: false)
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        database.audio.audioOutputToInputChannelsMap!.channel2 = max(channel - 1, -1)
        model.reloadStream()
        model.sceneUpdated(updateRemoteScene: false)
    }

    var body: some View {
        Form {
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        StreamAudioSettingsView(
                            stream: model.stream,
                            bitrate: Float(model.stream.audioBitrate / 1000)
                        )
                    } label: {
                        Label("Audio", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                Toggle("Bluetooth output only", isOn: Binding(get: {
                    database.debug.bluetoothOutputOnly
                }, set: {
                    database.debug.bluetoothOutputOnly = $0
                    model.reloadAudioSession()
                }))
            } footer: {
                Text("Makes most Bluetooth speakers work better.")
            }
            Section {
                Toggle("Prefer stereo mic", isOn: Binding(get: {
                    database.debug.preferStereoMic
                }, set: {
                    database.debug.preferStereoMic = $0
                    model.reloadAudioSession()
                    // model.setMic()
                }))
            } footer: {
                VStack(alignment: .leading) {
                    Text("Only works when front or back mic is selected.")
                    Text("")
                    Text("Switching between mono and stereo mics may not work.")
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Output channel 1"),
                    value: String(database.audio.audioOutputToInputChannelsMap!.channel1 + 1),
                    onSubmit: submitOutputChannel1
                )
                .disabled(model.isLive || model.isRecording)
                TextEditNavigationView(
                    title: String(localized: "Output channel 2"),
                    value: String(database.audio.audioOutputToInputChannelsMap!.channel2 + 1),
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
