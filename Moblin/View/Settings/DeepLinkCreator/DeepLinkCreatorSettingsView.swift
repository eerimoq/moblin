import SwiftUI

private let defaultDeepLink = "moblin://?{}"

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

struct DeepLinkCreatorSettingsView: View {
    @EnvironmentObject var model: Model
    @State var deepLink = defaultDeepLink

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
        newStream.srt = .init()
        newStream.srt!.latency = stream.srt.latency
        newStream.srt!.adaptiveBitrateEnabled = false
        newStream.obs = .init(
            webSocketUrl: stream.obs.webSocketUrl,
            webSocketPassword: stream.obs.webSocketPassword
        )
        return newStream
    }

    private func updateDeepLinkStreams(settings: MoblinSettingsUrl) {
        guard !deepLinkCreator.streams.isEmpty else {
            return
        }
        settings.streams = []
        for stream in deepLinkCreator.streams {
            settings.streams!.append(createDeepLinkStream(stream: stream))
        }
    }

    private func updateDeepLinkQuickButtons(settings: MoblinSettingsUrl) {
        guard deepLinkCreator.quickButtonsEnabled! else {
            return
        }
        settings.quickButtons = .init()
        settings.quickButtons!.enableScroll = deepLinkCreator.quickButtons!.enableScroll
        settings.quickButtons!.twoColumns = deepLinkCreator.quickButtons!.twoColumns
        settings.quickButtons!.showName = deepLinkCreator.quickButtons!.showName
        settings.quickButtons!.disableAllButtons = true
        for button in deepLinkCreator.quickButtons!.buttons where button.enabled {
            settings.quickButtons = settings.quickButtons ?? .init()
            settings.quickButtons!.buttons = settings.quickButtons!.buttons ?? .init()
            let newButton = MoblinSettingsButton(type: button.type)
            newButton.enabled = true
            settings.quickButtons!.buttons!.append(newButton)
        }
    }

    private func updateDeepLinkWebBrowser(settings: MoblinSettingsUrl) {
        guard deepLinkCreator.webBrowserEnabled! else {
            return
        }
        settings.webBrowser = .init()
        settings.webBrowser!.home = deepLinkCreator.webBrowser!.home
    }

    private func updateDeepLink() {
        let settings = MoblinSettingsUrl()
        updateDeepLinkStreams(settings: settings)
        updateDeepLinkQuickButtons(settings: settings)
        updateDeepLinkWebBrowser(settings: settings)
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
                    NavigationLink(destination: DeepLinkCreatorStreamsSettingsView()) {
                        Text("Streams")
                    }
                    NavigationLink(destination: DeepLinkCreatorQuickButtonsSettingsView()) {
                        Toggle(isOn: Binding(get: {
                            deepLinkCreator.quickButtonsEnabled!
                        }, set: {
                            deepLinkCreator.quickButtonsEnabled = $0
                            model.store()
                            updateDeepLink()
                        })) {
                            Text("Quick buttons")
                        }
                    }
                    NavigationLink(
                        destination: DeepLinkCreatorWebBrowserSettingsView(webBrowser: deepLinkCreator
                            .webBrowser!)
                    ) {
                        Toggle(isOn: Binding(get: {
                            deepLinkCreator.webBrowserEnabled!
                        }, set: {
                            deepLinkCreator.webBrowserEnabled = $0
                            model.store()
                            updateDeepLink()
                        })) {
                            Text("Web browser")
                        }
                    }
                }
                if deepLink != defaultDeepLink {
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
                } else {
                    Section {
                        Text("""
                        A QR code and copy to clipboard button will show up here when the \
                        settings above have been modified (and are not all default values).
                        """)
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
