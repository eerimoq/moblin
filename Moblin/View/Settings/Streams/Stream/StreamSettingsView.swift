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
            Section {
                NavigationLink(destination: NameEditView(
                    name: stream.name,
                    onSubmit: submitName
                )) {
                    TextItemView(name: String(localized: "Name"), value: stream.name)
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
                NavigationLink(destination: StreamOpenStreamingPlatformSettingsView(stream: stream)) {
                    Toggle("Open Streaming Platform", isOn: Binding(get: {
                        stream.openStreamingPlatformEnabled!
                    }, set: { value in
                        stream.openStreamingPlatformEnabled = value
                        model.store()
                        if stream.enabled {
                            model.openStreamingPlatformEnabledUpdated()
                        }
                    }))
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
                        Text("Keep live streams running when the app is in background mode.")
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
