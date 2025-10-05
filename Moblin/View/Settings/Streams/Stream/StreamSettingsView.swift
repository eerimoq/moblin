import SwiftUI

struct PlatformLogoAndNameView: View {
    let logo: String
    let name: String

    var body: some View {
        HStack {
            Image(logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 25)
            Text(name)
        }
    }
}

struct TwitchLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "TwitchLogo", name: String(localized: "Twitch"))
    }
}

struct KickLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "KickLogo", name: String(localized: "Kick"))
    }
}

struct YouTubeLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "YouTubeLogo", name: String(localized: "YouTube"))
    }
}

struct DLiveLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "DLiveLogo", name: String(localized: "DLive"))
    }
}

struct StreamPlatformsSettingsView: View {
    let stream: SettingsStream

    var body: some View {
        NavigationLink {
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        } label: {
            TwitchLogoAndNameView()
        }
        NavigationLink {
            StreamKickSettingsView(stream: stream)
        } label: {
            KickLogoAndNameView()
        }
        NavigationLink {
            StreamYouTubeSettingsView(stream: stream)
        } label: {
            YouTubeLogoAndNameView()
        }
        NavigationLink {
            StreamDLiveSettingsView(stream: stream)
        } label: {
            DLiveLogoAndNameView()
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
                    StreamUrlSettingsView(stream: stream)
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
                }
                NavigationLink {
                    StreamReplaySettingsView(stream: stream, replay: stream.replay)
                } label: {
                    Text("Replay")
                }
                if database.showAllSettings {
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
                    switch stream.getProtocol() {
                    case .srt:
                        NavigationLink {
                            StreamSrtSettingsView(
                                debug: database.debug,
                                stream: stream,
                                dnsLookupStrategy: stream.srt.dnsLookupStrategy.rawValue
                            )
                        } label: {
                            Text("SRT(LA)")
                        }
                    case .rtmp:
                        NavigationLink {
                            StreamRtmpSettingsView(stream: stream)
                        } label: {
                            Text("RTMP")
                        }
                        StreamMultiStreamingSettingsView(stream: stream, multiStreaming: stream.multiStreaming)
                    case .rist:
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
                if database.showAllSettings {
                    NavigationLink {
                        GoLiveNotificationSettingsView(stream: stream)
                    } label: {
                        Text("Go live notification")
                    }
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
                NavigationLink {
                    StreamEmotesSettingsView(stream: stream)
                } label: {
                    Text("Emotes")
                }
            }
            if database.showAllSettings {
                if !isMac() {
                    Section {
                        Toggle("Background streaming", isOn: $stream.backgroundStreaming)
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
