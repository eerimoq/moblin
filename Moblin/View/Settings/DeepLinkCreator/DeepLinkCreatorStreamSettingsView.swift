import SwiftUI

struct DeepLinkCreatorStreamVideoBitrateView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var video: DeepLinkCreatorStreamVideo
    @State var selection: UInt32

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(model.database.bitratePresets) { preset in
                        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                            .tag(preset.bitrate)
                    }
                }
                .onChange(of: selection) { bitrate in
                    video.bitrate = bitrate
                    model.store()
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
    @EnvironmentObject var model: Model
    var video: DeepLinkCreatorStreamVideo

    private func onResolutionChange(resolution: String) {
        video.resolution = SettingsStreamResolution(rawValue: resolution)!
        model.store()
    }

    private func onFpsChange(fps: String) {
        video.fps = Int(fps)!
        model.store()
    }

    private func onCodecChange(codec: String) {
        video.codec = SettingsStreamCodec(rawValue: codec)!
        model.store()
    }

    private func submitMaxKeyFrameInterval(value: String) {
        guard let interval = Int32(value) else {
            return
        }
        guard interval >= 0 && interval <= 10 else {
            return
        }
        video.maxKeyFrameInterval = interval
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Resolution"),
                        onChange: onResolutionChange,
                        items: resolutions.map { .init(id: $0.rawValue, text: $0.shortString()) },
                        selectedId: video.resolution!.rawValue
                    )
                } label: {
                    TextItemView(name: String(localized: "Resolution"), value: video.resolution!.shortString())
                }
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "FPS"),
                        onChange: onFpsChange,
                        items: InlinePickerItem.fromStrings(values: fpss),
                        selectedId: String(video.fps!)
                    )
                } label: {
                    TextItemView(name: "FPS", value: String(video.fps!))
                }
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Codec"),
                        onChange: onCodecChange,
                        items: InlinePickerItem.fromStrings(values: codecs),
                        selectedId: video.codec.rawValue
                    )
                } label: {
                    TextItemView(name: String(localized: "Codec"), value: video.codec.rawValue)
                }
                NavigationLink {
                    DeepLinkCreatorStreamVideoBitrateView(
                        video: video,
                        selection: video.bitrate!
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Bitrate"),
                        value: formatBytesPerSecond(speed: Int64(video.bitrate!))
                    )
                }
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Key frame interval"),
                        value: String(video.maxKeyFrameInterval!),
                        footers: [
                            String(
                                localized: "Maximum key frame interval in seconds. Set to 0 for automatic."
                            ),
                        ],
                        keyboardType: .numbersAndPunctuation
                    ) {
                        submitMaxKeyFrameInterval(value: $0)
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "Key frame interval"),
                        value: "\(video.maxKeyFrameInterval!) s"
                    )
                }
                Toggle(isOn: Binding(get: {
                    video.bFrames!
                }, set: { value in
                    video.bFrames = value
                    model.store()
                }), label: {
                    Text("B-frames")
                })
            }
        }
        .navigationTitle("Video")
    }
}

private struct DeepLinkCreatorStreamAudioView: View {
    @EnvironmentObject var model: Model
    var audio: DeepLinkCreatorStreamAudio
    @State var bitrate: Float

    private func calcBitrate() -> Int {
        return Int((bitrate * 1000).rounded(.up))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $bitrate,
                        in: 32 ... 320,
                        step: 32,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            audio.bitrate = calcBitrate()
                            model.store()
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
    var srt: DeepLinkCreatorStreamSrt
    @State var dnsLookupStrategy: String

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency >= 0 else {
            return
        }
        srt.latency = latency
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(srt.latency),
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
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    srt.adaptiveBitrateEnabled
                }, set: { value in
                    srt.adaptiveBitrateEnabled = value
                    model.store()
                }))
                Picker("DNS lookup strategy", selection: $dnsLookupStrategy) {
                    ForEach(dnsLookupStrategies, id: \.self) { strategy in
                        Text(strategy)
                    }
                }
                .onChange(of: dnsLookupStrategy) { strategy in
                    srt.dnsLookupStrategy = SettingsDnsLookupStrategy(rawValue: strategy) ?? .system
                }
            }
        }
        .navigationTitle("SRT(LA)")
    }
}

private struct DeepLinkCreatorStreamObsView: View {
    @EnvironmentObject var model: Model
    var obs: DeepLinkCreatorStreamObs

    func submitWebSocketUrl(value: String) {
        let url = cleanUrl(url: value)
        if let message = isValidWebSocketUrl(url: url) {
            model.makeErrorToast(title: message)
            return
        }
        obs.webSocketUrl = url
        model.store()
    }

    func submitWebSocketPassword(value: String) {
        obs.webSocketPassword = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: obs.webSocketUrl,
                    onSubmit: submitWebSocketUrl,
                    footers: [String(localized: "For example ws://232.32.45.332:4567.")],
                    keyboardType: .URL
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: obs.webSocketPassword,
                    onSubmit: submitWebSocketPassword,
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

struct DeepLinkCreatorStreamTwitchView: View {
    @EnvironmentObject var model: Model
    var stream: DeepLinkCreatorStream

    func submitChannelName(value: String) {
        stream.twitch!.channelName = value
        model.store()
    }

    func submitChannelId(value: String) {
        stream.twitch!.channelId = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.twitch!.channelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.twitch!.channelId,
                    onSubmit: submitChannelId
                )
            }
        }
        .navigationTitle("Twitch")
    }
}

struct DeepLinkCreatorStreamKickView: View {
    @EnvironmentObject var model: Model
    var stream: DeepLinkCreatorStream

    func submitChannelName(value: String) {
        stream.kick!.channelName = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kick!.channelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
            }
        }
        .navigationTitle("Kick")
    }
}

struct DeepLinkCreatorStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: DeepLinkCreatorStream

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: stream.name,
                    onSubmit: {
                        stream.name = $0
                        model.store()
                    }
                )
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: stream.url,
                    onSubmit: {
                        stream.url = $0
                        model.store()
                    }
                )
                NavigationLink {
                    DeepLinkCreatorStreamVideoView(video: stream.video)
                } label: {
                    Text("Video")
                }
                NavigationLink {
                    DeepLinkCreatorStreamAudioView(
                        audio: stream.audio!,
                        bitrate: Float(stream.audio!.bitrate / 1000)
                    )
                } label: {
                    Text("Audio")
                }
                if let url = URL(string: stream.url), ["srt", "srtla"].contains(url.scheme) {
                    NavigationLink {
                        DeepLinkCreatorStreamSrtView(
                            srt: stream.srt,
                            dnsLookupStrategy: stream.srt.dnsLookupStrategy!.rawValue
                        )
                    } label: {
                        Text("SRT(LA)")
                    }
                }
            } header: {
                Text("Media")
            }
            Section {
                NavigationLink {
                    DeepLinkCreatorStreamTwitchView(stream: stream)
                } label: {
                    Text("Twitch")
                }
                NavigationLink {
                    DeepLinkCreatorStreamKickView(stream: stream)
                } label: {
                    Text("Kick")
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
                Toggle(isOn: Binding(get: {
                    stream.selected
                }, set: { value in
                    stream.selected = value
                    model.store()
                }), label: {
                    Text("Selected")
                })
            }
        }
        .navigationTitle("Stream")
    }
}
