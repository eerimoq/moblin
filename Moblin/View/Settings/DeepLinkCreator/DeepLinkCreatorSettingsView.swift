import SwiftUI

private func generateQRCode(from string: String) -> UIImage {
    let data = string.data(using: String.Encoding.ascii)
    let filter = CIFilter.qrCodeGenerator()
    filter.message = data!
    filter.correctionLevel = "M"
    let output = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
    let context = CIContext()
    let cgImage = context.createCGImage(output, from: output.extent)
    return UIImage(cgImage: cgImage!)
}

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
                NavigationLink(destination: InlinePickerView(title: String(localized: "Codec"),
                                                             onChange: onCodecChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(values: codecs),
                                                             selectedId: video.codec.rawValue))
                {
                    TextItemView(name: String(localized: "Codec"), value: video.codec.rawValue)
                }
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

private struct DeepLinkCreatorStreamView: View {
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

struct DeepLinkCreatorSettingsView: View {
    @EnvironmentObject var model: Model
    @State var deepLink = "moblin://?{}"

    private var deepLinkCreator: DeepLinkCreator {
        return model.database.deepLinkCreator!
    }

    private func createDeepLinkStream(stream: DeepLinkCreatorStream) -> MoblinSettingsUrlStream {
        let newStream = MoblinSettingsUrlStream(name: stream.name, url: stream.url)
        if stream.selected {
            newStream.selected = true
        }
        newStream.video = .init()
        newStream.video!.codec = stream.video.codec
        if stream.srt.latency != 2000 {
            newStream.srt = newStream.srt ?? .init()
            newStream.srt!.latency = stream.srt.latency
        }
        if !stream.srt.adaptiveBitrateEnabled {
            newStream.srt = newStream.srt ?? .init()
            newStream.srt!.adaptiveBitrateEnabled = false
        }
        if !stream.obs.webSocketUrl.isEmpty && !stream.obs.webSocketPassword.isEmpty {
            newStream.obs = .init(
                webSocketUrl: stream.obs.webSocketUrl,
                webSocketPassword: stream.obs.webSocketPassword
            )
        }
        return newStream
    }

    private func updateDeepLink() {
        let settings = MoblinSettingsUrl()
        if !deepLinkCreator.streams.isEmpty {
            settings.streams = []
            for stream in deepLinkCreator.streams {
                settings.streams!.append(createDeepLinkStream(stream: stream))
            }
        }
        do {
            let jsonBlob = try settings.toString()
            if var encodedJsonBlob = jsonBlob
                .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            {
                // Hack to make it shorter and easier to read. When does this fail?
                encodedJsonBlob.replace("%7B", with: "{")
                encodedJsonBlob.replace("%7D", with: "}")
                encodedJsonBlob.replace("%5B", with: "[")
                encodedJsonBlob.replace("%5D", with: "]")
                encodedJsonBlob.replace("%22", with: "\"")
                deepLink = "moblin://?\(encodedJsonBlob)"
            }
        } catch {
            logger.info("Failed to create deep link")
        }
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    List {
                        ForEach(deepLinkCreator.streams) { stream in
                            NavigationLink(destination: DeepLinkCreatorStreamView(stream: stream)) {
                                Text(stream.name)
                            }
                        }
                        .onMove(perform: { froms, to in
                            deepLinkCreator.streams.move(fromOffsets: froms, toOffset: to)
                            model.store()
                            updateDeepLink()
                        })
                        .onDelete(perform: { offsets in
                            deepLinkCreator.streams.remove(atOffsets: offsets)
                            model.store()
                            updateDeepLink()
                        })
                    }
                    CreateButtonView(action: {
                        deepLinkCreator.streams.append(DeepLinkCreatorStream())
                        model.store()
                        model.objectWillChange.send()
                        updateDeepLink()
                    })
                } header: {
                    Text("Streams")
                }
                Section {
                    HStack {
                        Spacer()
                        Button("Copy to clipboard") {
                            UIPasteboard.general.string = deepLink
                            model.makeToast(title: "Deep link copied to clipboard")
                        }
                        Spacer()
                    }
                }
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: generateQRCode(from: deepLink))
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxHeight: metrics.size.height)
                        Spacer()
                    }
                }
            }
            .onAppear {
                updateDeepLink()
            }
            .navigationTitle("Deep link creator")
            .toolbar {
                SettingsToolbar()
            }
        }
    }
}
