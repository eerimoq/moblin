import SwiftUI

private struct DeepLinkCreatorStreamVideoView: View {
    @EnvironmentObject var model: Model
    var video: DeepLinkCreatorStreamVideo

    private func onCodecChange(codec: String) {
        video.codec = SettingsStreamCodec(rawValue: codec)!
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Codec"),
                    onChange: onCodecChange,
                    items: InlinePickerItem.fromStrings(values: codecs),
                    selectedId: video.codec.rawValue
                )) {
                    TextItemView(name: String(localized: "Codec"), value: video.codec.rawValue)
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
                Toggle(isOn: Binding(get: {
                    stream.selected
                }, set: { value in
                    stream.selected = value
                    model.store()
                }), label: {
                    Text("Selected")
                })
                NavigationLink(destination: DeepLinkCreatorStreamVideoView(video: stream.video)) {
                    Text("Video")
                }
                if let url = URL(string: stream.url), ["srt", "srtla"].contains(url.scheme) {
                    NavigationLink(destination: DeepLinkCreatorStreamSrtView(srt: stream.srt)) {
                        Text("SRT(LA)")
                    }
                }
            }
            Section {
                NavigationLink(destination: DeepLinkCreatorStreamObsView(obs: stream.obs)) {
                    Text("OBS remote control")
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
