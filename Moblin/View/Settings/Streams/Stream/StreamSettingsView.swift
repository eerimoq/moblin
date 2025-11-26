import SwiftUI

struct PlatformLogoAndNameView: View {
    let logo: String
    let name: String
    var channel: String = ""

    var body: some View {
        HStack {
            Image(logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 25)
            if channel.isEmpty {
                Text(name)
            } else {
                Text(String("\(name) (\(channel))"))
            }
        }
    }
}

struct TwitchLogoAndNameView: View {
    var channel: String = ""

    var body: some View {
        PlatformLogoAndNameView(logo: "TwitchLogo", name: String(localized: "Twitch"), channel: channel)
    }
}

struct KickLogoAndNameView: View {
    var channel: String = ""

    var body: some View {
        PlatformLogoAndNameView(logo: "KickLogo", name: String(localized: "Kick"), channel: channel)
    }
}

struct YouTubeLogoAndNameView: View {
    var handle: String = ""

    var body: some View {
        PlatformLogoAndNameView(logo: "YouTubeLogo", name: String(localized: "YouTube"), channel: handle)
    }
}

struct DLiveLogoAndNameView: View {
    var username: String = ""

    var body: some View {
        PlatformLogoAndNameView(logo: "DLiveLogo", name: String(localized: "DLive"), channel: username)
    }
}

struct OpenStreamingPlatformLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "OpenStreamingPlatform", name: String(localized: "Open Streaming Platform"))
    }
}

struct SoopLogoAndNameView: View {
    var channel: String = ""

    var body: some View {
        PlatformLogoAndNameView(logo: "SoopLogo", name: String(localized: "SOOP"), channel: channel)
    }
}

struct ObsLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "ObsLogo", name: String(localized: "OBS"))
    }
}

struct DiscordLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "DiscordLogo", name: String(localized: "Discord"))
    }
}

struct TtsMonsterLogoAndNameView: View {
    var body: some View {
        PlatformLogoAndNameView(logo: "TtsMonster", name: String(localized: "TTS.Monster"))
    }
}

struct StreamPlatformsSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        NavigationLink {
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        } label: {
            HStack {
                TwitchLogoAndNameView()
                Spacer()
                Text(stream.twitchChannelName)
                    .foregroundStyle(.gray)
            }
        }
        NavigationLink {
            StreamKickSettingsView(stream: stream)
        } label: {
            HStack {
                KickLogoAndNameView()
                Spacer()
                Text(stream.kickChannelName)
                    .foregroundStyle(.gray)
            }
        }
        NavigationLink {
            StreamYouTubeSettingsView(stream: stream)
        } label: {
            HStack {
                YouTubeLogoAndNameView()
                Spacer()
                Text(stream.youTubeHandle)
                    .foregroundStyle(.gray)
            }
        }
        NavigationLink {
            StreamDLiveSettingsView(stream: stream)
        } label: {
            HStack {
                DLiveLogoAndNameView()
                Spacer()
                Text(stream.dLiveUsername)
                    .foregroundStyle(.gray)
            }
        }
        NavigationLink {
            StreamSoopSettingsView(stream: stream)
        } label: {
            HStack {
                SoopLogoAndNameView()
                Spacer()
                Text(stream.soopChannelName)
                    .foregroundStyle(.gray)
            }
        }
        NavigationLink {
            StreamOpenStreamingPlatformSettingsView(stream: stream)
        } label: {
            OpenStreamingPlatformLogoAndNameView()
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
                    TextItemView(name: String(localized: "URL"), value: stream.url, sensitive: true)
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
                        IconAndTextSettingView(image: "record.circle", text: "Recording")
                    }
                }
                NavigationLink {
                    StreamReplaySettingsView(stream: stream, replay: stream.replay)
                } label: {
                    IconAndTextSettingView(image: "play", text: "Replay")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamSnapshotSettingsView(stream: stream, recording: stream.recording)
                    } label: {
                        IconAndTextSettingView(image: "camera.aperture", text: "Snapshot")
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
