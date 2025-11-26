import SwiftUI

private struct MicView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var mic: Mic

    var body: some View {
        NavigationLink {
            QuickButtonMicView(model: model, mics: mics, modelMic: mic)
        } label: {
            Label {
                HStack {
                    Text("Mic")
                    Spacer()
                    Text(mic.current.name)
                        .foregroundStyle(.gray)
                }
            } icon: {
                Image(systemName: "music.mic")
            }
        }
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    @ObservedObject var mic: Mic
    @ObservedObject var debug: SettingsDebug

    private func changeOutputChannel(value: String) -> String? {
        if Int(value) != nil {
            return nil
        } else {
            return String(localized: "Not a number")
        }
    }

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        database.audio.audioOutputToInputChannelsMap.channel1 = max(channel - 1, -1)
        model.reloadStreamIfEnabled(stream: stream)
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        database.audio.audioOutputToInputChannelsMap.channel2 = max(channel - 1, -1)
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            if database.showAllSettings, stream !== fallbackStream {
                Section {
                    NavigationLink {
                        StreamAudioSettingsView(
                            stream: stream,
                            bitrate: Float(stream.audioBitrate / 1000)
                        )
                    } label: {
                        Label("Audio", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                MicView(model: model, mics: database.mics, mic: model.mic)
            }
            Section {
                Toggle("Bluetooth output only", isOn: $debug.bluetoothOutputOnly)
                    .onChange(of: debug.bluetoothOutputOnly) { _ in
                        model.reloadAudioSession()
                    }
            } footer: {
                Text("Makes most Bluetooth speakers work better.")
            }
            Section {
                Toggle("Prefer stereo mic", isOn: $debug.preferStereoMic)
                    .onChange(of: debug.preferStereoMic) { _ in
                        if mic.current.isAudioSession() {
                            model.reloadAudioSession()
                            model.selectMicDefault(mic: mic.current)
                        }
                    }
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
                    value: String(database.audio.audioOutputToInputChannelsMap.channel1 + 1),
                    onChange: changeOutputChannel,
                    onSubmit: submitOutputChannel1
                )
                .disabled(model.isLive || model.isRecording)
                TextEditNavigationView(
                    title: String(localized: "Output channel 2"),
                    value: String(database.audio.audioOutputToInputChannelsMap.channel2 + 1),
                    onChange: changeOutputChannel,
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
