import SwiftUI

struct StreamSettingsView: View {
    @EnvironmentObject private var model: Model
    var stream: SettingsStream

    func submitName(name: String) {
        stream.name = name
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: stream.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: stream.name)
            }
            NavigationLink(destination: StreamUrlSettingsView(
                stream: stream,
                value: stream.url
            )) {
                TextItemView(name: String(localized: "URL"), value: schemeAndAddress(url: stream.url))
            }
            .disabled(stream.enabled && model.isLive)
            NavigationLink(destination: StreamVideoSettingsView(stream: stream)) {
                Text("Video")
            }
            NavigationLink(destination: StreamAudioSettingsView(
                stream: stream,
                bitrate: Float(stream.audioBitrate! / 1000)
            )) {
                Text("Audio")
            }
            NavigationLink(destination: StreamRecordingSettingsView(stream: stream)) {
                Text("Recording")
            }
            NavigationLink(destination: StreamTwitchSettingsView(stream: stream)) {
                Toggle("Twitch", isOn: Binding(get: {
                    stream.twitchEnabled!
                }, set: { value in
                    stream.twitchEnabled = value
                    model.store()
                    if stream.enabled {
                        model.twitchEnabledUpdated()
                    }
                }))
            }
            NavigationLink(destination: StreamKickSettingsView(stream: stream)) {
                Toggle("Kick", isOn: Binding(get: {
                    stream.kickEnabled!
                }, set: { value in
                    stream.kickEnabled = value
                    model.store()
                    if stream.enabled {
                        model.kickEnabledUpdated()
                    }
                }))
            }
            NavigationLink(destination: StreamYouTubeSettingsView(stream: stream)) {
                Toggle("YouTube", isOn: Binding(get: {
                    stream.youTubeEnabled!
                }, set: { value in
                    stream.youTubeEnabled = value
                    model.store()
                    if stream.enabled {
                        model.youTubeEnabledUpdated()
                    }
                }))
            }
            NavigationLink(destination: StreamAfreecaTvSettingsView(stream: stream)) {
                Toggle("AfreecaTV", isOn: Binding(get: {
                    stream.afreecaTvEnabled!
                }, set: { value in
                    stream.afreecaTvEnabled = value
                    model.store()
                    if stream.enabled {
                        model.afreecaTvEnabledUpdated()
                    }
                }))
            }
            NavigationLink(destination: StreamChatSettingsView(stream: stream)) {
                Text("Chat")
            }
            NavigationLink(destination: StreamObsSettingsView(stream: stream)) {
                Toggle("OBS remote control", isOn: Binding(get: {
                    stream.obsWebSocketEnabled!
                }, set: { value in
                    stream.obsWebSocketEnabled = value
                    model.store()
                    if stream.enabled {
                        model.obsWebSocketEnabledUpdated()
                    }
                }))
            }
            NavigationLink(destination: StreamRealtimeIrlSettingsView(stream: stream)) {
                Toggle("RealtimeIRL", isOn: Binding(get: {
                    stream.realtimeIrlEnabled!
                }, set: { value in
                    stream.realtimeIrlEnabled = value
                    model.store()
                    if stream.enabled {
                        model.reloadLocation()
                    }
                }))
            }
            if stream.getProtocol() == .srt {
                NavigationLink(destination: StreamSrtSettingsView(stream: stream)) {
                    Text("SRT(LA)")
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
