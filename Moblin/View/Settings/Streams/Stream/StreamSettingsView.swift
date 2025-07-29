import SwiftUI

struct StreamPlatformsSettingsView: View {
    let stream: SettingsStream

    var body: some View {
        NavigationLink {
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        } label: {
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
    }
}

struct StreamSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                NameEditView(name: $stream.name, existingNames: database.streams)
            }
            Section {
                NavigationLink {
                    StreamUrlSettingsView(stream: stream, value: stream.url)
                } label: {
                    TextItemView(name: String(localized: "URL"), value: schemeAndAddress(url: stream.url))
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink {
                    StreamVideoSettingsView(database: database, stream: stream)
                } label: {
                    Text("Video")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamAudioSettingsView(
                            stream: stream,
                            bitrate: Float(stream.audioBitrate / 1000)
                        )
                    } label: {
                        Text("Audio")
                    }
                    NavigationLink {
                        StreamRecordingSettingsView(stream: stream, recording: stream.recording)
                    } label: {
                        Text("Recording")
                    }
                    NavigationLink {
                        StreamReplaySettingsView(stream: stream)
                    } label: {
                        Text("Replay")
                    }
                    NavigationLink {
                        StreamSnapshotSettingsView(stream: stream, recording: stream.recording)
                    } label: {
                        Text("Snapshot")
                    }
                }
                if isPhone() || isPad() {
                    Toggle(isOn: $stream.portrait) {
                        Text("Portrait")
                    }
                    .disabled(stream.enabled && (model.isLive || model.isRecording))
                    .onChange(of: stream.portrait) { _ in
                        if stream.enabled {
                            model.setCurrentStream(stream: stream)
                            model.reloadStream()
                            model.resetSelectedScene(changeScene: false)
                            model.updateOrientation()
                        }
                    }
                }
                if database.showAllSettings {
                    if stream.getProtocol() == .srt {
                        NavigationLink {
                            StreamSrtSettingsView(
                                stream: stream,
                                dnsLookupStrategy: stream.srt.dnsLookupStrategy!.rawValue
                            )
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
                        StreamMultiStreamingSettingsView(stream: stream, multiStreaming: stream.multiStreaming)
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
            }
            Section {
                StreamPlatformsSettingsView(stream: stream)
            } header: {
                Text("Streaming platforms")
            }
            Section {
                NavigationLink {
                    StreamObsRemoteControlSettingsView(stream: stream)
                } label: {
                    Toggle("OBS remote control", isOn: $stream.obsWebSocketEnabled)
                        .onChange(of: stream.obsWebSocketEnabled) { _ in
                            if stream.enabled {
                                model.obsWebSocketEnabledUpdated()
                            }
                        }
                }
                NavigationLink {
                    GoLiveNotificationSettingsView(stream: stream)
                } label: {
                    Text("Go live notification")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamRealtimeIrlSettingsView(stream: stream)
                    } label: {
                        Toggle("RealtimeIRL", isOn: Binding(get: {
                            stream.realtimeIrlEnabled
                        }, set: { value in
                            stream.realtimeIrlEnabled = value
                            if stream.enabled {
                                model.reloadLocation()
                            }
                        }))
                    }
                }
            }
            if database.showAllSettings {
                if !isMac() {
                    Section {
                        Toggle("Background streaming", isOn: Binding(get: {
                            stream.backgroundStreaming
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
                            value: formatOneDecimal(stream.estimatedViewerDelay),
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
                            value: "\(formatOneDecimal(stream.estimatedViewerDelay)) s"
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
