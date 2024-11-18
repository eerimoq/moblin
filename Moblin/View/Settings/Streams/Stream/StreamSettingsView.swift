import SwiftUI

struct StreamSettingsView: View {
    @EnvironmentObject private var model: Model
    var stream: SettingsStream
    @State var name: String

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    NameEditView(name: $name)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
                .onChange(of: name) { name in
                    stream.name = name
                }
            }
            Section {
                NavigationLink {
                    StreamUrlSettingsView(
                        stream: stream,
                        value: stream.url
                    )
                } label: {
                    TextItemView(name: String(localized: "URL"), value: schemeAndAddress(url: stream.url))
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink {
                    StreamVideoSettingsView(
                        stream: stream,
                        codec: stream.codec.rawValue,
                        bitrate: stream.bitrate
                    )
                } label: {
                    Text("Video")
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        StreamAudioSettingsView(
                            stream: stream,
                            bitrate: Float(stream.audioBitrate! / 1000)
                        )
                    } label: {
                        Text("Audio")
                    }
                    NavigationLink {
                        StreamRecordingSettingsView(
                            stream: stream,
                            videoCodec: stream.recording!.videoCodec.rawValue
                        )
                    } label: {
                        Text("Recording")
                    }
                }
                if isPhone() {
                    Toggle(isOn: Binding(get: {
                        stream.portrait!
                    }, set: { value in
                        stream.portrait = value
                        model.updateOrientationLock()
                        model.objectWillChange.send()
                    })) {
                        Text("Portrait")
                    }
                }
                if model.database.showAllSettings! {
                    if stream.getProtocol() == .srt {
                        NavigationLink {
                            StreamSrtSettingsView(stream: stream)
                        } label: {
                            Text("SRT(LA)")
                        }
                    }
                    if stream.getProtocol() == .rtmp {
                        NavigationLink {
                            StreamRtmpSettingsView(stream: stream)
                        } label: {
                            Text("RTMP")
                        }
                    }
                    if stream.getProtocol() == .rist {
                        NavigationLink {
                            StreamRistSettingsView(stream: stream)
                        } label: {
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
                NavigationLink { StreamTwitchSettingsView(
                    stream: stream,
                    loggedIn: stream.twitchLoggedIn!
                ) } label: {
                    Text("Twitch")
                }
                NavigationLink {
                    StreamKickSettingsView(stream: stream)
                } label: {
                    Text("Kick")
                }
                NavigationLink {
                    StreamYouTubeSettingsView(stream: stream)
                } label: {
                    Text("YouTube")
                }
                NavigationLink {
                    StreamAfreecaTvSettingsView(stream: stream)
                } label: {
                    Text("AfreecaTV")
                }
                NavigationLink {
                    StreamOpenStreamingPlatformSettingsView(stream: stream)
                } label: {
                    Text("Open Streaming Platform")
                }
                NavigationLink {
                    StreamEmotesSettingsView(stream: stream)
                } label: {
                    Text("Emotes")
                }
            } header: {
                Text("Chat and viewers")
            }
            Section {
                NavigationLink {
                    StreamObsRemoteControlSettingsView(stream: stream)
                } label: {
                    Toggle("OBS remote control", isOn: Binding(get: {
                        stream.obsWebSocketEnabled!
                    }, set: { value in
                        stream.obsWebSocketEnabled = value
                        if stream.enabled {
                            model.obsWebSocketEnabledUpdated()
                        }
                    }))
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        StreamRealtimeIrlSettingsView(stream: stream)
                    } label: {
                        Toggle("RealtimeIRL", isOn: Binding(get: {
                            stream.realtimeIrlEnabled!
                        }, set: { value in
                            stream.realtimeIrlEnabled = value
                            if stream.enabled {
                                model.reloadLocation()
                            }
                        }))
                    }
                }
                NavigationLink {
                    StreamDiscordSettingsView(stream: stream)
                } label: {
                    Text("Discord")
                }
            }
            if model.database.showAllSettings! {
                if !ProcessInfo().isiOSAppOnMac {
                    Section {
                        Toggle("Background streaming", isOn: Binding(get: {
                            stream.backgroundStreaming!
                        }, set: { value in
                            stream.backgroundStreaming = value
                        }))
                    } footer: {
                        Text("Live stream and record when the app is in background mode.")
                    }
                }
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Estimated viewer delay"),
                            value: formatOneDecimal(value: stream.estimatedViewerDelay!),
                            keyboardType: .numbersAndPunctuation
                        ) {
                            guard let latency = Float($0), latency >= 0.0, latency <= 15.0 else {
                                return
                            }
                            stream.estimatedViewerDelay = latency
                        }
                    } label: {
                        TextItemView(
                            name: String(localized: "Estimated viewer delay"),
                            value: "\(formatOneDecimal(value: stream.estimatedViewerDelay!)) s"
                        )
                    }
                } footer: {
                    Text("""
                    Estimated viewer delay, for example used to make it easier to take \
                    snapshots using the chat bot. It does not delay the stream.
                    """)
                }
            }
        }
        .navigationTitle("Stream")
    }
}
