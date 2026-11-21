import SwiftUI

struct SettingsSearchItem: Identifiable {
    let title: String
    let path: [String]
    let breadcrumb: [String]
    let image: String
    let keywords: [String]
    let destination: () -> AnyView

    var id: String {
        (path + [title]).joined(separator: "/")
    }
}

private func settingsSearchWords(_ text: String) -> [Substring] {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .split { !$0.isLetter && !$0.isNumber }
}

func settingsSearchMatches(text: String, title: String, path: [String], keywords: [String]) -> Bool {
    let filterWords = settingsSearchWords(text)
    guard !filterWords.isEmpty else {
        return false
    }
    let words = settingsSearchWords(([title] + path + keywords).joined(separator: " "))
    return filterWords.allSatisfy { filterWord in
        words.contains { $0.hasPrefix(filterWord) }
    }
}

private func searchKeywords(_ values: String.LocalizationValue...) -> [String] {
    values.map { String(localized: $0) }
}

private struct SettingsSearchItemsBuilder {
    var items: [SettingsSearchItem] = []
    var name: String?

    mutating func add(
        _ title: String,
        _ path: [String],
        _ image: String,
        _ keywords: [String],
        @ViewBuilder destination: @escaping () -> some View
    ) {
        let breadcrumb = if let name, let first = path.first {
            [first, name] + path.dropFirst()
        } else {
            path
        }
        items.append(SettingsSearchItem(title: title,
                                        path: path,
                                        breadcrumb: breadcrumb,
                                        image: image,
                                        keywords: keywords,
                                        destination: { AnyView(destination()) }))
    }
}

@MainActor
func settingsSearchItems(model: Model, database: Database) -> [SettingsSearchItem] {
    var builder = SettingsSearchItemsBuilder()
    let showAll = database.showAllSettings
    let stream = model.stream
    let streams = String(localized: "Streams")
    let scenes = String(localized: "Scenes")
    let chat = String(localized: "Chat")
    let display = String(localized: "Display")
    let camera = String(localized: "Camera")
    let audio = String(localized: "Audio")
    let ingests = String(localized: "Ingests")
    let debug = String(localized: "Debug")
    let watch = String(localized: "Apple Watch")
    let streamImage = "dot.radiowaves.left.and.right"
    let streamBinding = Binding(get: { model.stream }, set: { model.stream = $0 })
    builder.add(
        streams,
        [],
        streamImage,
        searchKeywords("Stream", "Platform", "Server", "Destination") + ["url"]
    ) {
        StreamsSettingsView(createStreamWizard: model.createStreamWizard, database: database)
    }
    if stream !== fallbackStream {
        let streamPath = [streams]
        builder.name = stream.name
        builder.add(
            String(localized: "Video"),
            streamPath,
            streamImage,
            searchKeywords("Bitrate", "Resolution", "FPS", "Framerate", "Codec", "Adaptive", "Keyframe") + [
                "hevc",
                "h264",
            ]
        ) {
            StreamVideoSettingsView(database: database, stream: stream)
        }
        if showAll {
            builder.add(String(localized: "Audio"),
                        streamPath,
                        streamImage,
                        searchKeywords("Audio bitrate", "Codec") + ["aac", "opus"])
            {
                StreamAudioSettingsView(stream: stream, bitrate: Float(stream.audioBitrate / 1000))
            }
            switch stream.getProtocol() {
            case .srt:
                builder.add(String(localized: "SRT(LA)"),
                            streamPath,
                            streamImage,
                            searchKeywords("Latency", "Bonding", "Adaptive bitrate") + ["srt", "srtla"])
                {
                    StreamSrtSettingsView(stream: stream, srt: stream.srt)
                }
            case .rtmp:
                builder.add(String(localized: "RTMP"), streamPath, streamImage, ["rtmp", "rtmps"]) {
                    StreamRtmpSettingsView(stream: stream)
                }
            case .rist:
                builder.add(
                    String(localized: "RIST"),
                    streamPath,
                    streamImage,
                    searchKeywords("Bonding") + ["rist"]
                ) {
                    StreamRistSettingsView(stream: stream)
                }
            case .whip:
                builder.add(String(localized: "WHIP"), streamPath, streamImage, ["whip", "webrtc"]) {
                    StreamWhipSettingsView(model: model, stream: stream, whip: stream.whip)
                }
            case .mobcam:
                builder.add(String(localized: "Mobcam"), streamPath, streamImage, ["mobcam"]) {
                    StreamMobcamSettingsView(stream: stream)
                }
            }
            builder.add(String(localized: "Recording"),
                        streamPath,
                        streamImage,
                        searchKeywords("Record", "Save", "Quality"))
            {
                StreamRecordingSettingsView(stream: stream, recording: stream.recording)
            }
            builder.add(String(localized: "Snapshot"),
                        streamPath,
                        streamImage,
                        searchKeywords("Photo", "Screenshot"))
            {
                StreamSnapshotSettingsView(model: model, stream: stream, recording: stream.recording)
            }
            builder.add(String(localized: "Go live notification"),
                        streamPath,
                        streamImage,
                        searchKeywords("Announce") + ["discord"])
            {
                GoLiveNotificationSettingsView(stream: stream)
            }
        }
        builder.add(String(localized: "Replay"),
                    streamPath,
                    streamImage,
                    searchKeywords("Instant replay", "Clip"))
        {
            StreamReplaySettingsView(database: database, stream: stream, replay: stream.replay)
        }
        builder.add(String(localized: "Twitch"), streamPath, streamImage, searchKeywords(
            "Login",
            "Channel"
        )) {
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        }
        builder.add(
            String(localized: "YouTube"),
            streamPath,
            streamImage,
            searchKeywords("Login", "Channel")
        ) {
            StreamYouTubeSettingsView(debug: database.debug, stream: stream)
        }
        builder.add(String(localized: "Kick"), streamPath, streamImage, searchKeywords("Login", "Channel")) {
            StreamKickSettingsView(model: model, stream: stream)
        }
        builder.add(String(localized: "OBS remote control"),
                    streamPath,
                    streamImage,
                    searchKeywords("Scene") + ["obs", "websocket"])
        {
            StreamObsRemoteControlSettingsView(stream: stream)
        }
        builder.add(String(localized: "Emotes"),
                    streamPath,
                    streamImage,
                    searchKeywords("Emoji") + ["bttv", "ffz", "7tv"])
        {
            StreamEmotesSettingsView(stream: stream)
        }
        if !isMac() {
            builder.add(String(localized: "Background streaming"),
                        streamPath,
                        streamImage,
                        searchKeywords("Background", "Picture in picture") + ["pip"])
            {
                StreamSettingsView(database: database, stream: stream)
            }
        }
        builder.add(String(localized: "Bitrate presets"),
                    streamPath + [String(localized: "Video")],
                    streamImage,
                    searchKeywords("Bitrate", "Quick buttons"))
        {
            BitratePresetsSettingsView(database: database)
        }
    }
    builder.name = nil
    let scenesImage = "photo.on.rectangle"
    builder.add(
        scenes,
        [],
        scenesImage,
        searchKeywords("Scene", "Layout", "Widgets", "Overlay", "Browser source")
    ) {
        ScenesSettingsView(model: model, database: database)
    }
    if showAll {
        builder.add(String(localized: "Auto scene switchers"),
                    [scenes],
                    scenesImage,
                    searchKeywords("Rotate"))
        {
            ScenesSettingsView(model: model, database: database)
        }
        builder.add(String(localized: "Disconnect protection"),
                    [scenes],
                    scenesImage,
                    searchKeywords("Be right back", "Fallback", "Offline") + ["brb"])
        {
            ScenesSettingsView(model: model, database: database)
        }
    }
    let chatImage = "message"
    builder.add(chat, [], chatImage, searchKeywords("Messages", "Font") + ["twitch", "youtube", "kick"]) {
        ChatSettingsView(model: model, database: database, chat: database.chat, stream: model.stream)
    }
    builder.add(String(localized: "Bot"), [chat], chatImage, searchKeywords("Chat bot", "Commands")) {
        ChatBotSettingsView()
    }
    builder.add(String(localized: "Text to speech"),
                [chat],
                chatImage,
                searchKeywords("Voice", "Read aloud") + ["tts"])
    {
        ChatTextToSpeechSettingsView(model: model,
                                     chat: database.chat,
                                     ttsMonster: database.chat.ttsMonster,
                                     elevenLabs: database.chat.elevenLabs)
    }
    if showAll {
        builder.add(String(localized: "Filters"),
                    [chat],
                    chatImage,
                    searchKeywords("Filter", "Block", "Hide", "Nicknames"))
        {
            ChatSettingsView(model: model, database: database, chat: database.chat, stream: model.stream)
        }
    }
    let displayImage = "rectangle.inset.topright.fill"
    builder.add(display, [], displayImage, searchKeywords("Screen", "User interface", "Layout") + ["ui"]) {
        DisplaySettingsView(database: database)
    }
    builder.add(String(localized: "Quick buttons"),
                [display],
                displayImage,
                searchKeywords("Buttons", "Shortcuts", "Control bar"))
    {
        QuickButtonsSettingsView(model: model, showAll: true)
    }
    builder.add(String(localized: "Stream button"),
                [display],
                displayImage,
                searchKeywords("Go live", "Button", "Color"))
    {
        StreamButtonsSettingsView(database: database)
    }
    builder.add(String(localized: "Status"),
                [display],
                displayImage,
                searchKeywords("Local overlays", "Overlay", "Info", "Big audio level meter"))
    {
        LocalOverlaysStatusSettingsView(database: database, show: database.show)
    }
    builder.add(String(localized: "Zoom and scene controls"),
                [display],
                displayImage,
                searchKeywords(
                    "Local overlays",
                    "Big buttons",
                    "Large",
                    "Size",
                    "Layout",
                    "Vertical",
                    "One row"
                )) {
        LocalOverlaysZoomAndSceneControlsSettingsView(database: database, show: database.show)
    }
    builder.add(String(localized: "Vibrate"),
                [display],
                displayImage,
                searchKeywords("Haptics"))
    {
        DisplaySettingsView(database: database)
    }
    if !isMac() {
        builder.add(String(localized: "Auto rotate to portrait"),
                    [display],
                    displayImage,
                    searchKeywords("Rotation", "Orientation", "Portrait", "Landscape"))
        {
            DisplaySettingsView(database: database)
        }
    }
    if showAll {
        builder.add(String(localized: "Network interface names"),
                    [display],
                    displayImage,
                    searchKeywords("Cellular", "Ethernet", "Bonding") + ["wifi"])
        {
            LocalOverlaysNetworkInterfaceNamesSettingsView(model: model, database: database)
        }
        builder.add(String(localized: "Low bitrate warning"),
                    [display],
                    displayImage,
                    searchKeywords("Recording confirmations"))
        {
            DisplaySettingsView(database: database)
        }
    }
    let cameraImage = "camera"
    builder.add(camera, [], cameraImage, searchKeywords("Video", "Lens", "Color space")) {
        CameraSettingsView(database: database, stream: model.stream, color: database.color)
    }
    builder.add(String(localized: "Video stabilization"),
                [camera],
                cameraImage,
                searchKeywords("Mirror"))
    {
        CameraSettingsView(database: database, stream: model.stream, color: database.color)
    }
    if showAll {
        builder.add(
            String(localized: "Zoom"),
            [camera],
            cameraImage,
            searchKeywords("Zoom", "Presets", "Lens")
        ) {
            ZoomSettingsView(zoom: database.zoom)
        }
        builder.add(String(localized: "Tap screen to focus"),
                    [camera],
                    cameraImage,
                    searchKeywords(
                        "Focus",
                        "Exposure",
                        "Fixed horizon",
                        "Camera controls",
                        "Volume",
                        "Buttons"
                    )) {
            CameraSettingsView(database: database, stream: model.stream, color: database.color)
        }
        builder.add(String(localized: "LUTs"),
                    [camera],
                    cameraImage,
                    searchKeywords("Color", "Grading", "Filter") + ["lut", "cube"])
        {
            CameraSettingsLutsView(color: database.color)
        }
        if model.supportsAppleLog || model.supportsAppleLog2 {
            builder.add(String(localized: "Apple Log LUT"),
                        [camera],
                        cameraImage,
                        searchKeywords("Color space") + ["apple log", "hdr"])
            {
                CameraSettingsAppleLogLutView(model: model, color: database.color)
            }
        }
    }
    if showAll {
        let audioImage = "waveform"
        builder.add(audio, [], audioImage, searchKeywords("Sound", "Microphone", "Bluetooth", "Stereo")) {
            AudioSettingsView(database: database,
                              stream: model.stream,
                              mic: model.mic,
                              debug: database.debug,
                              audio: database.audio)
        }
        builder.add(String(localized: "Mic"),
                    [audio],
                    audioImage,
                    searchKeywords("Microphone", "Input") + ["usb"])
        {
            QuickButtonMicView(model: model, mics: database.mics, modelMic: model.mic)
        }
        builder.add(String(localized: "Delays"),
                    [audio],
                    audioImage,
                    searchKeywords("Sync"))
        {
            MicsDelaySettingsView(model: model, mics: database.mics)
        }
        builder.add(String(localized: "Gains"),
                    [audio],
                    audioImage,
                    searchKeywords("Volume", "Loudness"))
        {
            MicsGainSettingsView(model: model, mics: database.mics)
        }
        if database.debug.audioMixer {
            builder.add(String(localized: "Processing"),
                        [audio],
                        audioImage,
                        searchKeywords("Voice", "Effects", "Filter"))
            {
                MicsProcessingSettingsView(model: model, mics: database.mics)
            }
            builder.add(String(localized: "Outputs"),
                        [audio],
                        audioImage,
                        searchKeywords("Stream", "Recording"))
            {
                MicsOutputsSettingsView(model: model, mics: database.mics)
            }
        }
        builder.add(
            String(localized: "Macros"),
            [],
            "increase.indent",
            searchKeywords("Automation", "Actions")
        ) {
            MacrosSettingsView(model: model, database: database, macros: database.macros)
        }
    }
    builder.add(String(localized: "Location"),
                [],
                "location",
                searchKeywords("Map", "Speed", "Altitude", "Privacy") + ["gps"])
    {
        LocationSettingsView(database: database,
                             location: database.location,
                             locationManager: model.locationManager,
                             stream: streamBinding)
    }
    builder.add(String(localized: "Store (support us) ❤️"),
                [],
                "cart",
                searchKeywords("Donate", "Buy", "Icon"))
    {
        StoreSettingsView(model: model, store: model.store)
    }
    if showAll {
        let ingestsImage = "server.rack"
        builder.add(ingests,
                    [],
                    ingestsImage,
                    searchKeywords("Server", "Receive", "Input")
                        + ["rtmp", "srt", "srtla", "rist", "whip", "rtsp", "whep"])
        {
            IngestsSettingsView(model: model, database: database)
        }
        builder.add(String(localized: "Talkback"),
                    [],
                    "speaker.wave.2.bubble.left",
                    searchKeywords("Intercom", "Producer"))
        {
            TalkbackSettingsView(model: model, mics: database.mics, talkback: database.talkback)
        }
    }
    builder.add(String(localized: "Moblink"),
                [],
                "app.connected.to.app.below.fill",
                searchKeywords("Bonding", "Relay", "Phone", "Hotspot"))
    {
        MoblinkSettingsView(status: model.statusOther, streamer: database.moblink.streamer)
    }
    if showAll {
        builder.add(String(localized: "Media players"),
                    [],
                    "play.rectangle.on.rectangle",
                    searchKeywords("Video", "Playlist", "Play"))
        {
            MediaPlayersSettingsView(model: model, mediaPlayers: database.mediaPlayers)
        }
        builder.add(String(localized: "Apple Music"),
                    [],
                    "music.note",
                    searchKeywords("Music", "Song", "Playlist"))
        {
            AppleMusicSettingsView(model: model, musicPlaylist: model.musicPlaylist)
        }
        builder.add(String(localized: "Gimbal"),
                    [],
                    "iphone.dock.motorized.viewfinder",
                    searchKeywords("Stabilizer", "Tracking"))
        {
            GimbalSettingsView(model: model, gimbal: database.gimbal)
        }
        builder.add(
            String(localized: "Selfie stick"),
            [],
            "line.diagonal",
            searchKeywords("Button", "Remote")
        ) {
            SelfieStickSettingsView(model: model, selfieStick: database.selfieStick)
        }
        builder.add(String(localized: "Game controllers"),
                    [],
                    "gamecontroller",
                    searchKeywords("Gamepad", "Controller") + ["xbox", "playstation"])
        {
            GameControllersSettingsView(model: model, database: database)
        }
        if #available(iOS 17.0, *) {
            builder.add(String(localized: "Keyboard"),
                        [],
                        "keyboard",
                        searchKeywords("Hotkeys", "Shortcuts"))
            {
                KeyboardSettingsView(model: model, keyboard: database.keyboard)
            }
        }
        #if !targetEnvironment(macCatalyst)
        if isPad() {
            builder.add(String(localized: "Stream decks"),
                        [],
                        "square.grid.3x3.square",
                        searchKeywords("Buttons") + ["elgato"])
            {
                StreamDecksSettingsView(model: model,
                                        streamDeck: model.streamDeck,
                                        streamDecks: database.streamDecks)
            }
        }
        #endif
        builder.add(String(localized: "Remote control"),
                    [],
                    "appletvremote.gen1",
                    searchKeywords("Assistant", "Streamer", "Relay", "Web"))
        {
            RemoteControlSettingsView(database: database, stream: streamBinding)
        }
        if !isMac() {
            builder.add(String(localized: "Moblin Cloud"),
                        [],
                        "cloud",
                        searchKeywords("Account", "Server"))
            {
                MoblinCloudSettingsView(model: model, database: database, moblinCloud: database.moblinCloud)
            }
        }
        builder.add(String(localized: "DJI devices"),
                    [],
                    "appletvremote.gen1",
                    searchKeywords("Action camera", "Pocket") + ["dji", "osmo"])
        {
            DjiDevicesSettingsView(model: model, djiDevices: database.djiDevices)
        }
        builder.add(
            String(localized: "GoPro"),
            [],
            "appletvremote.gen1",
            searchKeywords("Action camera", "QR code")
        ) {
            GoProSettingsView()
        }
        builder.add(String(localized: "Cat printers"),
                    [],
                    "pawprint",
                    searchKeywords("Print", "Thermal"))
        {
            CatPrintersSettingsView(model: model, catPrinters: database.catPrinters)
        }
        builder.add(String(localized: "Tesla"), [], "car.side", searchKeywords("Car", "Vehicle")) {
            TeslaSettingsView(tesla: model.tesla)
        }
        builder.add(String(localized: "Workout devices"),
                    [],
                    "figure.walk.motion",
                    searchKeywords("Heart rate", "Cycling", "Bluetooth"))
        {
            WorkoutDevicesSettingsView(model: model, workoutDevices: database.workoutDevices)
        }
        builder.add(String(localized: "Black Shark coolers"),
                    [],
                    "fan",
                    searchKeywords("Cooler", "Fan", "Temperature", "Thermal", "Overheating"))
        {
            BlackSharkCoolerDevicesSettingsView(model: model,
                                                blackSharkCoolerDevices: database.blackSharkCoolerDevices)
        }
    }
    builder.add(String(localized: "Recordings"),
                [],
                "photo.on.rectangle.angled",
                searchKeywords("Video"))
    {
        RecordingsSettingsView(model: model)
    }
    if showAll {
        builder.add(String(localized: "Streaming history"),
                    [],
                    "text.book.closed",
                    searchKeywords("Statistics"))
        {
            StreamingHistorySettingsView(model: model)
        }
        if isPhone() {
            let watchImage = "applewatch"
            builder.add(watch, [], watchImage, []) {
                WatchSettingsView(model: model, watch: database.watch)
            }
            builder.add(String(localized: "Chat"), [watch], watchImage, []) {
                WatchChatSettingsView(model: model, chat: database.watch.chat)
            }
            builder.add(
                String(localized: "Display"),
                [watch],
                watchImage,
                []
            ) {
                WatchDisplaySettingsView(show: database.watch.show)
            }
        }
    }
    builder.add(String(localized: "Help and support"),
                [],
                "questionmark.circle",
                searchKeywords("Help", "Manual") + ["discord", "github", "faq"])
    {
        HelpAndSupportSettingsView()
    }
    if showAll {
        builder.add(String(localized: "About"), [], "info.circle", searchKeywords("Version", "License")) {
            AboutSettingsView()
        }
        builder.add(debug, [], "ladybug", searchKeywords("Log", "Logs", "Experimental")) {
            DebugSettingsView(model: model, debug: database.debug)
        }
        builder.add(String(localized: "HTTP proxy"), [debug], "ladybug", ["http"]) {
            HttpProxySettingsView(model: model, status: model.statusOther, httpProxy: database.httpProxy)
        }
        builder.add(String(localized: "Import and export settings"),
                    [],
                    "gearshape",
                    searchKeywords("Backup", "Restore", "Export"))
        {
            ImportExportSettingsView(model: model)
        }
        builder.add(String(localized: "Deep link creator"),
                    [],
                    "link.badge.plus",
                    searchKeywords("QR code", "Share settings") + ["url"])
        {
            DeepLinkCreatorSettingsView(deepLinkCreator: database.deepLinkCreator)
        }
    }
    return builder.items
}

struct SettingsSearchResultsView: View {
    let items: [SettingsSearchItem]
    let text: String

    var body: some View {
        let items = items.filter {
            settingsSearchMatches(text: text, title: $0.title, path: $0.path, keywords: $0.keywords)
        }
        if items.isEmpty {
            Text("No results")
                .foregroundStyle(.secondary)
        } else {
            Section {
                ForEach(items) { item in
                    NavigationLink {
                        item.destination()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                if !item.breadcrumb.isEmpty {
                                    Text(item.breadcrumb.joined(separator: " › "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: item.image)
                        }
                    }
                }
            }
        }
    }
}
