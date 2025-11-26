import SwiftUI

private struct DeepLinkCreatorStreamVideoBitrateView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    @ObservedObject var video: DeepLinkCreatorStreamVideo

    var body: some View {
        Form {
            Section {
                Picker("", selection: $video.bitrate) {
                    ForEach(model.database.bitratePresets) { preset in
                        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                            .tag(preset.bitrate)
                    }
                }
                .onChange(of: video.bitrate) { _ in
                    dismiss()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
    }
}

private struct DeepLinkCreatorStreamVideoView: View {
    @ObservedObject var video: DeepLinkCreatorStreamVideo

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0, interval <= 10 else {
            return
        }
        video.maxKeyFrameInterval = interval
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Resolution"),
                        onChange: { video.resolution = SettingsStreamResolution(rawValue: $0)! },
                        items: resolutions.map { .init(id: $0.rawValue, text: $0.shortString()) },
                        selectedId: video.resolution.rawValue
                    )
                } label: {
                    TextItemView(name: String(localized: "Resolution"), value: video.resolution.shortString())
                }
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "FPS"),
                        onChange: { video.fps = Int($0)! },
                        items: InlinePickerItem.fromStrings(values: fpss.map { String($0) }),
                        selectedId: String(video.fps)
                    )
                } label: {
                    TextItemView(name: "FPS", value: String(video.fps))
                }
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Codec"),
                        onChange: { video.codec = SettingsStreamCodec(rawValue: $0)! },
                        items: InlinePickerItem.fromStrings(values: codecs),
                        selectedId: video.codec.rawValue
                    )
                } label: {
                    TextItemView(name: String(localized: "Codec"), value: video.codec.rawValue)
                }
                NavigationLink {
                    DeepLinkCreatorStreamVideoBitrateView(video: video)
                } label: {
                    TextItemView(
                        name: String(localized: "Bitrate"),
                        value: formatBytesPerSecond(speed: Int64(video.bitrate))
                    )
                }
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Key frame interval"),
                        value: String(video.maxKeyFrameInterval),
                        footers: [
                            String(localized: "Maximum key frame interval in seconds. Set to 0 for automatic."),
                        ],
                        keyboardType: .numbersAndPunctuation
                    ) {
                        submitMaxKeyFrameInterval(value: $0)
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "Key frame interval"),
                        value: "\(video.maxKeyFrameInterval) s"
                    )
                }
                Toggle(isOn: $video.bFrames) {
                    Text("B-frames")
                }
            }
        }
        .navigationTitle("Video")
    }
}

private struct DeepLinkCreatorStreamAudioView: View {
    @ObservedObject var audio: DeepLinkCreatorStreamAudio

    private func calcBitrate() -> Int {
        return Int((audio.bitrateFloat * 1000).rounded(.up))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $audio.bitrateFloat,
                        in: 32 ... 320,
                        step: 32,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            audio.bitrate = calcBitrate()
                        }
                    )
                    Text(formatBytesPerSecond(speed: Int64(calcBitrate())))
                        .frame(width: 90)
                }
                .navigationTitle("Audio")
            }
        }
    }
}

private struct DeepLinkCreatorStreamSrtView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srt: DeepLinkCreatorStreamSrt

    private func changeLatency(value: String) -> String? {
        if Int32(value) != nil {
            return nil
        } else {
            return String(localized: "Not a number")
        }
    }

    private func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency >= 0 else {
            return
        }
        srt.latency = latency
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(srt.latency),
                    onChange: changeLatency,
                    onSubmit: submitLatency,
                    footers: [
                        String(localized: """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """),
                    ],
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                Toggle("Adaptive bitrate", isOn: $srt.adaptiveBitrateEnabled)
                Picker("DNS lookup strategy", selection: $srt.dnsLookupStrategy) {
                    ForEach(SettingsDnsLookupStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue)
                    }
                }
                .onChange(of: srt.dnsLookupStrategy) { strategy in
                    srt.dnsLookupStrategy = strategy
                }
            }
        }
        .navigationTitle("SRT(LA)")
    }
}

private struct DeepLinkCreatorStreamObsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var obs: DeepLinkCreatorStreamObs

    private func changeWebSocketUrl(value: String) -> String? {
        return isValidWebSocketUrl(url: cleanUrl(url: value))
    }

    private func submitWebSocketUrl(value: String) {
        let url = cleanUrl(url: value)
        if let message = isValidWebSocketUrl(url: url) {
            model.makeErrorToast(title: message)
            return
        }
        obs.webSocketUrl = url
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: obs.webSocketUrl,
                    onChange: changeWebSocketUrl,
                    onSubmit: submitWebSocketUrl,
                    footers: [String(localized: "For example ws://232.32.45.332:4567.")]
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: obs.webSocketPassword,
                    onSubmit: { obs.webSocketPassword = $0 },
                    sensitive: true
                )
            } header: {
                Text("WebSocket")
            } footer: {
                Text("Source name is the name of the Source in OBS that receives the stream from Moblin.")
            }
        }
        .navigationTitle("OBS remote control")
    }
}

private struct DeepLinkCreatorStreamTwitchView: View {
    @ObservedObject var twitch: DeepLinkCreatorStreamTwitch

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: twitch.channelName,
                    onSubmit: { twitch.channelName = $0 },
                    capitalize: true
                )
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: twitch.channelId,
                    onSubmit: { twitch.channelId = $0 }
                )
            }
        }
        .navigationTitle("Twitch")
    }
}

private struct DeepLinkCreatorStreamKickView: View {
    @ObservedObject var kick: DeepLinkCreatorStreamKick

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: kick.channelName,
                    onSubmit: { kick.channelName = $0 },
                    capitalize: true
                )
            }
        }
        .navigationTitle("Kick")
    }
}

struct DeepLinkCreatorStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var deepLinkCreator: DeepLinkCreator
    @ObservedObject var stream: DeepLinkCreatorStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: deepLinkCreator.streams)
                    TextEditNavigationView(title: String(localized: "URL"),
                                           value: stream.url,
                                           onSubmit: {
                                               stream.url = $0
                                           })
                    NavigationLink {
                        DeepLinkCreatorStreamVideoView(video: stream.video)
                    } label: {
                        Text("Video")
                    }
                    NavigationLink {
                        DeepLinkCreatorStreamAudioView(audio: stream.audio)
                    } label: {
                        Text("Audio")
                    }
                    if let url = URL(string: stream.url), ["srt", "srtla"].contains(url.scheme) {
                        NavigationLink {
                            DeepLinkCreatorStreamSrtView(srt: stream.srt)
                        } label: {
                            Text("SRT(LA)")
                        }
                    }
                } header: {
                    Text("Media")
                }
                Section {
                    NavigationLink {
                        DeepLinkCreatorStreamTwitchView(twitch: stream.twitch)
                    } label: {
                        TwitchLogoAndNameView()
                    }
                    NavigationLink {
                        DeepLinkCreatorStreamKickView(kick: stream.kick)
                    } label: {
                        KickLogoAndNameView()
                    }
                } header: {
                    Text("Chat and viewers")
                }
                Section {
                    NavigationLink {
                        DeepLinkCreatorStreamObsView(obs: stream.obs)
                    } label: {
                        Text("OBS remote control")
                    }
                }
                Section {
                    Toggle(isOn: $stream.selected) {
                        Text("Selected")
                    }
                }
            }
            .navigationTitle("Stream")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(stream.name)
                Spacer()
            }
        }
    }
}
