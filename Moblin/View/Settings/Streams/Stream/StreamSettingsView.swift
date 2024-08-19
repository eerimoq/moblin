import SwiftUI

struct StreamSettingsView: View {
    @EnvironmentObject private var model: Model
    var stream: SettingsStream
    @State var name: String

    func submitName(name: String) {
        stream.name = name
        self.name = name
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: NameEditView(name: name, onSubmit: submitName)) {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
            }
            Section {
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
                if model.database.showAllSettings! {
                    NavigationLink(destination: StreamAudioSettingsView(
                        stream: stream,
                        bitrate: Float(stream.audioBitrate! / 1000)
                    )) {
                        Text("Audio")
                    }
                    NavigationLink(destination: StreamRecordingSettingsView(stream: stream)) {
                        Text("Recording")
                    }
                }
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Toggle(isOn: Binding(get: {
                        stream.portrait!
                    }, set: { value in
                        stream.portrait = value
                        model.store()
                        model.updateOrientationLock()
                        model.objectWillChange.send()
                    })) {
                        Text("Portrait")
                    }
                }
                if model.database.showAllSettings! {
                    if stream.getProtocol() == .srt {
                        NavigationLink(destination: StreamSrtSettingsView(stream: stream)) {
                            Text("SRT(LA)")
                        }
                    }
                    if stream.getProtocol() == .rtmp {
                        NavigationLink(destination: StreamRtmpSettingsView(stream: stream)) {
                            Text("RTMP")
                        }
                    }
                    if stream.getProtocol() == .rist {
                        NavigationLink(destination: StreamRistSettingsView(stream: stream)) {
                            Text("RIST")
                        }
                    }
                }
            } header: {
                Text("Media")
            } footer: {
                Text("""
                The streamed (and recorded) video is always in landscape, even if the portrait toggle \
                is enabled. Rotate it in to portrait in OBS. To be improved in the future.
                """)
                Text("")
                Text("Widgets will be wrongly rotated when the portrait toggle is enabled.")
            }
            Section {
                NavigationLink(destination: StreamTwitchSettingsView(
                    stream: stream,
                    loggedIn: stream.twitchLoggedIn!
                )) {
                    Text("Twitch")
                }
                NavigationLink(destination: StreamKickSettingsView(stream: stream)) {
                    Text("Kick")
                }
                NavigationLink(destination: StreamYouTubeSettingsView(stream: stream)) {
                    Text("YouTube")
                }
                NavigationLink(destination: StreamAfreecaTvSettingsView(stream: stream)) {
                    Text("AfreecaTV")
                }
                NavigationLink(destination: StreamOpenStreamingPlatformSettingsView(stream: stream)) {
                    Text("Open Streaming Platform")
                }
                NavigationLink(destination: StreamEmotesSettingsView(stream: stream)) {
                    Text("Emotes")
                }
            } header: {
                Text("Chat and viewers")
            }
            Section {
                NavigationLink(destination: StreamObsRemoteControlSettingsView(stream: stream)) {
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
                if model.database.showAllSettings! {
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
                }
            }
            if model.database.showAllSettings! {
                if !ProcessInfo().isiOSAppOnMac {
                    Section {
                        Toggle("Background streaming", isOn: Binding(get: {
                            stream.backgroundStreaming!
                        }, set: { value in
                            stream.backgroundStreaming = value
                            model.store()
                        }))
                    } footer: {
                        Text("Live stream and record when the app is in background mode.")
                    }
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
