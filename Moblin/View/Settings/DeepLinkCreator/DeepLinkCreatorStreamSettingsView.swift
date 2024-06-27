import SwiftUI

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
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Resolution"),
                    onChange: onResolutionChange,
                    items: InlinePickerItem.fromStrings(values: resolutions),
                    selectedId: video.resolution!.rawValue
                )) {
                    TextItemView(name: String(localized: "Resolution"), value: video.resolution!.rawValue)
                }
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "FPS"),
                    onChange: onFpsChange,
                    items: InlinePickerItem.fromStrings(values: fpss),
                    selectedId: String(video.fps!)
                )) {
                    TextItemView(name: "FPS", value: String(video.fps!))
                }
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Codec"),
                    onChange: onCodecChange,
                    items: InlinePickerItem.fromStrings(values: codecs),
                    selectedId: video.codec.rawValue
                )) {
                    TextItemView(name: String(localized: "Codec"), value: video.codec.rawValue)
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Key frame interval"),
                    value: String(video.maxKeyFrameInterval!),
                    onSubmit: submitMaxKeyFrameInterval,
                    footer: Text("Maximum key frame interval in seconds. Set to 0 for automatic."),
                    keyboardType: .numbersAndPunctuation
                )) {
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
        .toolbar {
            SettingsToolbar()
        }
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
                .toolbar {
                    SettingsToolbar()
                }
            }
        }
    }
}

private struct DeepLinkCreatorStreamSrtView: View {
    @EnvironmentObject var model: Model
    var srt: DeepLinkCreatorStreamSrt

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
                    footer: Text(
                        """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """
                    ),
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    srt.adaptiveBitrateEnabled
                }, set: { value in
                    srt.adaptiveBitrateEnabled = value
                    model.store()
                }))
            }
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            SettingsToolbar()
        }
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
                    footer: Text("For example ws://232.32.45.332:4567."),
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
        .toolbar {
            SettingsToolbar()
        }
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
        .toolbar {
            SettingsToolbar()
        }
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
        .toolbar {
            SettingsToolbar()
        }
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
                NavigationLink(destination: DeepLinkCreatorStreamVideoView(video: stream.video)) {
                    Text("Video")
                }
                NavigationLink(destination: DeepLinkCreatorStreamAudioView(
                    audio: stream.audio!,
                    bitrate: Float(stream.audio!.bitrate / 1000)
                )) {
                    Text("Audio")
                }
                if let url = URL(string: stream.url), ["srt", "srtla"].contains(url.scheme) {
                    NavigationLink(destination: DeepLinkCreatorStreamSrtView(srt: stream.srt)) {
                        Text("SRT(LA)")
                    }
                }
            } header: {
                Text("Media")
            }
            Section {
                NavigationLink(destination: DeepLinkCreatorStreamTwitchView(stream: stream)) {
                    Text("Twitch")
                }
                NavigationLink(destination: DeepLinkCreatorStreamKickView(stream: stream)) {
                    Text("Kick")
                }
            } header: {
                Text("Chat and viewers")
            }
            Section {
                NavigationLink(destination: DeepLinkCreatorStreamObsView(obs: stream.obs)) {
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
