import SwiftUI

private let defaultDeepLink = "moblin://?{}"

struct DeepLinkCreatorSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var deepLinkCreator: DeepLinkCreator
    @State var deepLink = defaultDeepLink

    private func createDeepLinkStream(stream: DeepLinkCreatorStream) -> MoblinSettingsUrlStream {
        let newStream = MoblinSettingsUrlStream(name: stream.name, url: stream.url)
        if stream.selected {
            newStream.selected = true
        }
        newStream.video = .init()
        if stream.video.resolution != .r1920x1080 {
            newStream.video!.resolution = stream.video.resolution
        }
        if stream.video.fps != 30 {
            newStream.video!.fps = stream.video.fps
        }
        if stream.video.bitrate != 5_000_000 {
            newStream.video!.bitrate = stream.video.bitrate
        }
        newStream.video!.codec = stream.video.codec
        if stream.video.bFrames {
            newStream.video!.bFrames = stream.video.bFrames
        }
        if stream.video.maxKeyFrameInterval != 2 {
            newStream.video!.maxKeyFrameInterval = stream.video.maxKeyFrameInterval
        }
        if stream.audio.bitrate != 128_000 {
            newStream.audio = .init()
            if stream.audio.bitrate != 128_000 {
                newStream.audio!.bitrate = stream.audio.bitrate
            }
        }
        newStream.srt = .init()
        newStream.srt!.latency = stream.srt.latency
        newStream.srt!.adaptiveBitrateEnabled = stream.srt.adaptiveBitrateEnabled
        newStream.srt!.dnsLookupStrategy = stream.srt.dnsLookupStrategy
        if !stream.obs.webSocketUrl.isEmpty {
            newStream.obs = .init(
                webSocketUrl: stream.obs.webSocketUrl,
                webSocketPassword: stream.obs.webSocketPassword
            )
        }
        if !stream.twitch.channelName.isEmpty || !stream.twitch.channelId.isEmpty {
            newStream.twitch = .init(
                channelName: stream.twitch.channelName,
                channelId: stream.twitch.channelId
            )
        }
        if !stream.kick.channelName.isEmpty {
            newStream.kick = .init(channelName: stream.kick.channelName)
        }
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
        guard deepLinkCreator.quickButtonsEnabled else {
            return
        }
        settings.quickButtons = .init()
        settings.quickButtons!.enableScroll = deepLinkCreator.quickButtons.enableScroll
        settings.quickButtons!.twoColumns = deepLinkCreator.quickButtons.twoColumns
        settings.quickButtons!.showName = deepLinkCreator.quickButtons.showName
        settings.quickButtons!.disableAllButtons = true
        for button in deepLinkCreator.quickButtons.buttons where button.enabled {
            settings.quickButtons = settings.quickButtons ?? .init()
            settings.quickButtons!.buttons = settings.quickButtons!.buttons ?? .init()
            let newButton = MoblinSettingsButton(type: button.type)
            newButton.enabled = true
            settings.quickButtons!.buttons!.append(newButton)
        }
    }

    private func updateDeepLinkWebBrowser(settings: MoblinSettingsUrl) {
        guard deepLinkCreator.webBrowserEnabled else {
            return
        }
        settings.webBrowser = .init()
        settings.webBrowser!.home = deepLinkCreator.webBrowser.home
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
                    NavigationLink {
                        DeepLinkCreatorStreamsSettingsView(deepLinkCreator: deepLinkCreator)
                    } label: {
                        Text("Streams")
                    }
                    NavigationLink {
                        DeepLinkCreatorQuickButtonsSettingsView(quickButtons: deepLinkCreator.quickButtons)
                    } label: {
                        Toggle(isOn: $deepLinkCreator.quickButtonsEnabled) {
                            Text("Quick buttons")
                        }
                        .onChange(of: deepLinkCreator.quickButtonsEnabled) { _ in
                            updateDeepLink()
                        }
                    }
                    NavigationLink {
                        DeepLinkCreatorWebBrowserSettingsView(webBrowser: deepLinkCreator.webBrowser)
                    } label: {
                        Toggle(isOn: $deepLinkCreator.webBrowserEnabled) {
                            Text("Web browser")
                        }
                        .onChange(of: deepLinkCreator.webBrowserEnabled) { _ in
                            updateDeepLink()
                        }
                    }
                }
                if deepLink != defaultDeepLink {
                    Section {
                        HStack {
                            Spacer()
                            Button("Copy to clipboard") {
                                UIPasteboard.general.string = deepLink
                                model.makeToast(title: String(localized: "Deep link copied to clipboard"))
                            }
                            Spacer()
                        }
                    }
                    Section {
                        HStack {
                            Spacer()
                            Image(uiImage: generateQrCode(from: deepLink)!)
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
        }
    }
}
