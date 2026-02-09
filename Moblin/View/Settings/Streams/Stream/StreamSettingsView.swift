import SwiftUI

private struct PlatformLogoAndNameView: View {
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
        PlatformLogoAndNameView(
            logo: "OpenStreamingPlatform",
            name: String(localized: "Open Streaming Platform")
        )
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

struct GithubLogoAndNameView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PlatformLogoAndNameView(logo: colorScheme == .light ? "GithubLogo" : "GithubWhiteLogo",
                                name: String(localized: "Github"))
    }
}

struct GrayTextView: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.gray)
            .lineLimit(1)
    }
}

struct StreamPlatformsSettingsView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        NavigationLink {
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        } label: {
            HStack {
                TwitchLogoAndNameView()
                Spacer()
                GrayTextView(text: stream.twitchChannelName)
            }
        }
        NavigationLink {
            StreamKickSettingsView(stream: stream)
        } label: {
            HStack {
                KickLogoAndNameView()
                Spacer()
                GrayTextView(text: stream.kickChannelName)
            }
        }
        NavigationLink {
            StreamYouTubeSettingsView(debug: model.database.debug, stream: stream)
        } label: {
            HStack {
                YouTubeLogoAndNameView()
                Spacer()
                GrayTextView(text: stream.youTubeHandle)
            }
        }
        NavigationLink {
            StreamDLiveSettingsView(stream: stream)
        } label: {
            HStack {
                DLiveLogoAndNameView()
                Spacer()
                GrayTextView(text: stream.dLiveUsername)
            }
        }
        NavigationLink {
            StreamSoopSettingsView(stream: stream)
        } label: {
            HStack {
                SoopLogoAndNameView()
                Spacer()
                GrayTextView(text: stream.soopChannelName)
            }
        }
        NavigationLink {
            StreamOpenStreamingPlatformSettingsView(stream: stream)
        } label: {
            OpenStreamingPlatformLogoAndNameView()
        }
    }
}

struct BackgroundStreamingToggleView: View {
    @Binding var enabled: Bool

    var body: some View {
        Section {
            Toggle("Background streaming", isOn: $enabled)
        } footer: {
            VStack(alignment: .leading) {
                Text("Live stream and record when the app is in background mode.")
                Text("")
                Text("""
                Built-in camera and USB sources blur the last frame in background mode \
                (Apple limitation), but audio stays active. Both audio and video from \
                ingests (RTMP/SRT/...) stay active in background mode.
                """)
            }
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
                    TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                }
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
                            StreamSrtSettingsView(stream: stream, srt: stream.srt)
                        } label: {
                            Text("SRT(LA)")
                        }
                    case .rtmp:
                        NavigationLink {
                            StreamRtmpSettingsView(stream: stream)
                        } label: {
                            Text("RTMP")
                        }
                        StreamMultiStreamingSettingsView(
                            stream: stream,
                            multiStreaming: stream.multiStreaming
                        )
                    case .rist:
                        NavigationLink {
                            StreamRistSettingsView(stream: stream)
                        } label: {
                            Text("RIST")
                        }
                    case .whip:
                        EmptyView()
                    }
                }
            } header: {
                Text("Media")
            }
            Section {
                StreamPlatformsSettingsView(model: model, stream: stream)
            } header: {
                Text("Streaming platforms")
            }
            if !isMac() {
                BackgroundStreamingToggleView(enabled: $stream.backgroundStreaming)
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
                        TextItemLocalizedView(
                            name: "Estimated viewer delay",
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
