import Foundation

enum SettingsSearchPage {
    case streams
    case stream
    case streamUrl
    case streamSrt
    case streamRtmp
    case streamRist
    case streamWhip
    case streamMobcam
    case streamVideo
    case streamAudio
    case streamRecording
    case streamReplay
    case streamSnapshot
    case streamPreviewStream
    case streamTwitch
    case streamKick
    case streamYouTube
    case streamSoop
    case streamOpenStreamingPlatform
    case streamObsRemoteControl
    case streamGoLiveNotification
    case streamRealtimeIrl
    case streamEmotes
    case scenes
    case chat
    case chatBot
    case chatTextToSpeech
    case display
    case displayQuickButtons
    case displayStreamButton
    case displayLocalOverlays
    case displayNetworkInterfaceNames
    case camera
    case cameraZoom
    case cameraLuts
    case audio
    case audioDelays
    case audioGains
    case macros
    case location
    case store
    case ingests
    case talkback
    case moblink
    case mediaPlayers
    case appleMusic
    case gimbal
    case selfieStick
    case gameControllers
    case keyboard
    case streamDecks
    case remoteControl
    case moblinCloud
    case djiDevices
    case goPro
    case catPrinters
    case tesla
    case workoutDevices
    case blackSharkCoolers
    case recordings
    case streamingHistory
    case watch
    case watchChat
    case watchDisplay
    case watchLocalOverlays
    case helpAndSupport
    case about
    case aboutAttributions
    case debug
    case debugVideo
    case debugHttpProxy
    case importExport
    case deepLinkCreator
}

struct SettingsSearchSetting {
    let title: String
    let visible: (Database) -> Bool

    init(_ title: String, visible: @escaping (Database) -> Bool = { _ in true }) {
        self.title = title
        self.visible = visible
    }
}

struct SettingsSearchNode {
    let title: String
    let image: String?
    let page: SettingsSearchPage?
    let visible: (Database) -> Bool
    let settings: [SettingsSearchSetting]
    let children: [SettingsSearchNode]

    init(
        _ title: String,
        image: String? = nil,
        page: SettingsSearchPage? = nil,
        visible: @escaping (Database) -> Bool = { _ in true },
        settings: [SettingsSearchSetting] = [],
        children: [SettingsSearchNode] = []
    ) {
        self.title = title
        self.image = image
        self.page = page
        self.visible = visible
        self.settings = settings
        self.children = children
    }
}

struct SettingsSearchResult: Identifiable {
    let id: Int
    let title: String
    let path: String
    let image: String
    let page: SettingsSearchPage
}

private func appendSettingsSearchResults(
    node: SettingsSearchNode,
    parentPath: [String],
    parentImage: String,
    parentPage: SettingsSearchPage?,
    words: [String],
    database: Database,
    results: inout [SettingsSearchResult]
) {
    guard node.visible(database), let page = node.page ?? parentPage else {
        return
    }
    let image = node.image ?? parentImage
    let path = parentPath + [node.title]
    let titles = [(node.title, parentPath)] + node.settings
        .filter { $0.visible(database) }
        .map { ($0.title, path) }
    for (title, path) in titles {
        let lowercasedTitle = title.lowercased()
        guard words.allSatisfy({ lowercasedTitle.contains($0) }) else {
            continue
        }
        results.append(SettingsSearchResult(id: results.count,
                                            title: title,
                                            path: path.joined(separator: " › "),
                                            image: image,
                                            page: page))
    }
    for child in node.children {
        appendSettingsSearchResults(node: child,
                                    parentPath: path,
                                    parentImage: image,
                                    parentPage: page,
                                    words: words,
                                    database: database,
                                    results: &results)
    }
}

func searchSettings(text: String, nodes: [SettingsSearchNode], database: Database) -> [SettingsSearchResult] {
    let words = text.lowercased().split(separator: " ").map { String($0) }
    guard !words.isEmpty else {
        return []
    }
    var results: [SettingsSearchResult] = []
    for node in nodes {
        appendSettingsSearchResults(node: node,
                                    parentPath: [],
                                    parentImage: "",
                                    parentPage: nil,
                                    words: words,
                                    database: database,
                                    results: &results)
    }
    return sortedBySearchPrefix(results, searchText: words.joined(separator: " ")) { $0.title }
}

private func showAll(database: Database) -> Bool {
    database.showAllSettings
}

private func notMac(_: Database) -> Bool {
    !isMac()
}

private func showAllNotMac(database: Database) -> Bool {
    database.showAllSettings && !isMac()
}

private func streamSettingsSearchNode(stream: SettingsStream) -> SettingsSearchNode {
    SettingsSearchNode(
        stream.name,
        page: .stream,
        visible: { _ in stream !== fallbackStream },
        settings: [
            .init(String(localized: "Name")),
            .init(String(localized: "Portrait"), visible: notMac),
            .init(String(localized: "Background streaming"), visible: notMac),
            .init(String(localized: "Show PiP"), visible: notMac),
            .init(String(localized: "Auto go live"), visible: { _ in stream.getProtocol() == .mobcam }),
            .init(String(localized: "Estimated viewer delay"), visible: showAll),
        ],
        children: [
            SettingsSearchNode(String(localized: "URL"), page: .streamUrl),
            SettingsSearchNode(
                String(localized: "SRT(LA)"),
                page: .streamSrt,
                visible: { $0.showAllSettings && stream.getProtocol() == .srt },
                settings: [
                    .init(String(localized: "Latency")),
                    .init(String(localized: "Adaptive bitrate")),
                    .init(String(localized: "Connection priorities")),
                    .init(String(localized: "Max bandwidth follows input"),
                          visible: { _ in stream.srt.implementation == .official }),
                    .init(String(localized: "Overhead bandwidth"),
                          visible: { _ in stream.srt.implementation == .official }),
                    .init(String(localized: "Big packets")),
                    .init(String(localized: "DNS lookup strategy")),
                    .init(String(localized: "Implementation")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "RTMP"),
                page: .streamRtmp,
                visible: { $0.showAllSettings && stream.getProtocol() == .rtmp },
                settings: [
                    .init(String(localized: "Adaptive bitrate")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Multi streaming"),
                visible: { $0.showAllSettings && stream.getProtocol() == .rtmp }
            ),
            SettingsSearchNode(
                String(localized: "RIST"),
                page: .streamRist,
                visible: { $0.showAllSettings && stream.getProtocol() == .rist },
                settings: [
                    .init(String(localized: "Adaptive bitrate")),
                    .init(String(localized: "Bonding")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "WHIP"),
                page: .streamWhip,
                visible: { $0.showAllSettings && stream.getProtocol() == .whip },
                settings: [
                    .init(String(localized: "Bearer token")),
                    .init(String(localized: "HTTP transport")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Mobcam"),
                page: .streamMobcam,
                visible: { $0.showAllSettings && stream.getProtocol() == .mobcam },
                settings: [
                    .init(String(localized: "Port")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Video"),
                page: .streamVideo,
                settings: [
                    .init(String(localized: "Resolution")),
                    .init(String(localized: "FPS")),
                    .init(String(localized: "Low light boost (LLB)"), visible: { _ in
                        if #available(iOS 18, *) {
                            true
                        } else {
                            false
                        }
                    }),
                    .init(String(localized: "Codec")),
                    .init(String(localized: "Rate control"), visible: showAll),
                    .init(String(localized: "Bitrate"), visible: showAll),
                    .init(String(localized: "Bitrate presets"), visible: showAll),
                    .init(String(localized: "Key frame interval"), visible: showAll),
                    .init(String(localized: "B-frames"), visible: showAll),
                    .init(String(localized: "Color range"), visible: showAll),
                    .init(String(localized: "Adaptive resolution"), visible: showAll),
                    .init(String(localized: "Timecodes"), visible: showAll),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Audio"),
                page: .streamAudio,
                visible: showAll,
                settings: [
                    .init(String(localized: "Codec")),
                    .init(String(localized: "Bitrate")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Recording"),
                page: .streamRecording,
                visible: showAll,
                settings: [
                    .init(String(localized: "Override")),
                    .init(String(localized: "Resolution")),
                    .init(String(localized: "Video codec")),
                    .init(String(localized: "Video bitrate")),
                    .init(String(localized: "Key frame interval")),
                    .init(String(localized: "Audio bitrate")),
                    .init(String(localized: "Recording path")),
                    .init(String(localized: "Clean recordings")),
                    .init(String(localized: "Auto start recording when going live")),
                    .init(String(localized: "Auto stop recording when ending stream")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Replay"),
                page: .streamReplay,
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Transition"), visible: showAll),
                    .init(String(localized: "In video"), visible: showAll),
                    .init(String(localized: "Out video"), visible: showAll),
                    .init(String(localized: "Post trigger delay"), visible: showAll),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Snapshot"),
                page: .streamSnapshot,
                visible: showAll,
                settings: [
                    .init(String(localized: "Clean snapshots")),
                    .init(String(localized: "Webhook URL")),
                    .init(String(localized: "Chat bot webhook URL")),
                    .init(String(localized: "Only when live")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Preview stream"),
                page: .streamPreviewStream,
                visible: showAll,
                settings: [
                    .init(String(localized: "URL")),
                    .init(String(localized: "Resolution")),
                    .init(String(localized: "Video bitrate")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Twitch"),
                page: .streamTwitch,
                settings: [
                    .init(String(localized: "Channel name")),
                    .init(String(localized: "Channel id")),
                    .init(String(localized: "Alerts")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Kick"),
                page: .streamKick,
                settings: [
                    .init(String(localized: "Channel name")),
                    .init(String(localized: "Alerts")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "YouTube"),
                page: .streamYouTube,
                settings: [
                    .init(String(localized: "Channel handle")),
                    .init(String(localized: "Video IDs")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "SOOP"),
                page: .streamSoop,
                settings: [
                    .init(String(localized: "Channel name")),
                    .init(String(localized: "Video id")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Open Streaming Platform"),
                page: .streamOpenStreamingPlatform,
                settings: [
                    .init(String(localized: "URL")),
                    .init(String(localized: "Channel id")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "OBS remote control"),
                page: .streamObsRemoteControl,
                settings: [
                    .init(String(localized: "URL")),
                    .init(String(localized: "Password")),
                    .init(String(localized: "Main scene")),
                    .init(String(localized: "BRB scene")),
                    .init(String(localized: "Streaming directly to OBS")),
                    .init(String(localized: "BRB scene when video source is broken"), visible: showAll),
                    .init(String(localized: "Source name"), visible: showAll),
                    .init(String(localized: "Auto start streaming when going live"), visible: showAll),
                    .init(String(localized: "Auto stop streaming when ending stream"), visible: showAll),
                    .init(String(localized: "Auto start recording when going live"), visible: showAll),
                    .init(String(localized: "Auto stop recording when ending stream"), visible: showAll),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Go live notification"),
                page: .streamGoLiveNotification,
                visible: showAll,
                settings: [
                    .init(String(localized: "Discord")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "RealtimeIRL"),
                page: .streamRealtimeIrl,
                visible: showAll,
                settings: [
                    .init(String(localized: "Base URL")),
                    .init(String(localized: "Push key")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Emotes"),
                page: .streamEmotes,
                settings: [
                    .init(String(localized: "BTTV")),
                    .init(String(localized: "FFZ")),
                    .init(String(localized: "7TV")),
                ]
            ),
        ]
    )
}

private func scenesSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Scenes"),
        image: "photo.on.rectangle",
        page: .scenes,
        settings: [
            .init(String(localized: "Widgets")),
            .init(String(localized: "Remote scene"), visible: showAll),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Scene switching"),
                visible: showAll,
                settings: [
                    .init(String(localized: "Transition")),
                    .init(String(localized: "Force transition")),
                    .init(String(localized: "Video blackish")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Auto scene switchers"),
                visible: showAll,
                settings: [
                    .init(String(localized: "Current")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Disconnect protection"),
                visible: showAll,
                settings: [
                    .init(String(localized: "Live scene")),
                    .init(String(localized: "Fallback scene")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Graphics"),
                visible: showAll,
                settings: [
                    .init(String(localized: "Implementation")),
                    .init(String(localized: "High quality downsampling")),
                ]
            ),
        ]
    )
}

private func chatSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Chat"),
        image: "message",
        page: .chat,
        settings: [
            .init(String(localized: "Enabled")),
            .init(String(localized: "Activity feed")),
            .init(String(localized: "Maximum age"), visible: showAll),
            .init(String(localized: "Show deleted messages"), visible: showAll),
            .init(String(localized: "Background chat"), visible: showAll),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Appearance"),
                settings: [
                    .init(String(localized: "Size")),
                    .init(String(localized: "Font"), visible: showAll),
                    .init(String(localized: "Bold name"), visible: showAll),
                    .init(String(localized: "Bold message"), visible: showAll),
                    .init(String(localized: "Big GIF scale"), visible: showAll),
                    .init(String(localized: "Display style"), visible: showAll),
                    .init(String(localized: "Timestamp"), visible: showAll),
                    .init(String(localized: "Badges"), visible: showAll),
                    .init(String(localized: "Animated emotes"), visible: showAll),
                    .init(String(localized: "Shared chat icons"), visible: showAll),
                    .init(String(localized: "Compact events"), visible: showAll),
                    .init(String(localized: "Same color for all names"), visible: showAll),
                    .init(String(localized: "Background")),
                    .init(String(localized: "Border")),
                    .init(String(localized: "Me in name color"), visible: showAll),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Layout"),
                settings: [
                    .init(String(localized: "Height")),
                    .init(String(localized: "Width")),
                    .init(String(localized: "Bottom")),
                    .init(String(localized: "New messages at top"), visible: showAll),
                    .init(String(localized: "Mirrored"), visible: showAll),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Bot"),
                page: .chatBot,
                settings: [
                    .init(String(localized: "Commands")),
                    .init(String(localized: "Custom commands")),
                    .init(String(localized: "Aliases")),
                    .init(String(localized: "Send low battery message")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Text to speech"),
                page: .chatTextToSpeech,
                settings: [
                    .init(String(localized: "Voices")),
                    .init(String(localized: "Pause between messages")),
                    .init(String(localized: "Default language")),
                    .init(String(localized: "Detect language per message")),
                    .init(String(localized: "Say username")),
                    .init(String(localized: "Say emotes")),
                    .init(String(localized: "Subscribers only")),
                    .init(String(localized: "Filter")),
                    .init(String(localized: "Filter mentions")),
                    .init(String(localized: "Bluetooth speaker only")),
                ]
            ),
            SettingsSearchNode(String(localized: "Filters"), visible: showAll),
            SettingsSearchNode(String(localized: "Nicknames"), visible: showAll),
        ]
    )
}

private func displaySettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Display"),
        image: "rectangle.inset.topright.fill",
        page: .display,
        settings: [
            .init(String(localized: "Big buttons")),
            .init(String(localized: "Big audio level meter")),
            .init(String(localized: "Vertical buttons")),
            .init(String(localized: "External monitor content"), visible: showAll),
            .init(String(localized: "Low bitrate warning"), visible: showAll),
            .init(String(localized: "Recording confirmations"), visible: showAll),
            .init(String(localized: "Vibrate")),
            .init(String(localized: "Auto rotate to portrait"), visible: notMac),
            .init(String(localized: "Portrait"), visible: showAllNotMac),
            .init(String(localized: "Video position"), visible: showAllNotMac),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Quick buttons"),
                page: .displayQuickButtons,
                settings: [
                    .init(String(localized: "Scroll"), visible: showAll),
                    .init(String(localized: "Two columns"), visible: showAll),
                    .init(String(localized: "Big buttons")),
                    .init(String(localized: "Show name")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Stream button"),
                page: .displayStreamButton,
                settings: [
                    .init(String(localized: "Background")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Background"),
                settings: [
                    .init(String(localized: "Opacity")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Local overlays"),
                page: .displayLocalOverlays,
                visible: showAll,
                settings: [
                    .init(String(localized: "Stream")),
                    .init(String(localized: "Camera")),
                    .init(String(localized: "Mic")),
                    .init(String(localized: "Zoom")),
                    .init(String(localized: "OBS remote control")),
                    .init(String(localized: "Events (alerts)")),
                    .init(String(localized: "Chat")),
                    .init(String(localized: "Viewers")),
                    .init(String(localized: "Audio level")),
                    .init(String(localized: "System monitor")),
                    .init(String(localized: "Location")),
                    .init(String(localized: "Ingests")),
                    .init(String(localized: "Moblink")),
                    .init(String(localized: "Remote control")),
                    .init(String(localized: "Moblin Cloud"), visible: notMac),
                    .init(String(localized: "DJI devices")),
                    .init(String(localized: "Game controllers")),
                    .init(String(localized: "Bitrate")),
                    .init(String(localized: "Uptime")),
                    .init(String(localized: "Browser widgets")),
                    .init(String(localized: "Bonding")),
                    .init(String(localized: "Bonding RTTs")),
                    .init(String(localized: "Cat printers")),
                    .init(String(localized: "Workout devices")),
                    .init(String(localized: "Zoom presets")),
                    .init(String(localized: "Zoom slider")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Network interface names"),
                page: .displayNetworkInterfaceNames,
                visible: showAll
            ),
        ]
    )
}

private func cameraSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Camera"),
        image: "camera",
        page: .camera,
        settings: [
            .init(String(localized: "Video stabilization")),
            .init(String(localized: "Fixed horizon"), visible: showAll),
            .init(String(localized: "Mirror front camera on stream")),
            .init(String(localized: "Tap screen to focus"), visible: showAll),
            .init(String(localized: "Camera controls"), visible: showAll),
            .init(String(localized: "Instant camera preview"), visible: showAll),
            .init(String(localized: "Instant photo shoot"), visible: showAll),
            .init(String(localized: "Color space"), visible: showAll),
            .init(String(localized: "Apple Log LUT"), visible: showAll),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Zoom"),
                page: .cameraZoom,
                visible: showAll,
                settings: [
                    .init(String(localized: "Speed")),
                    .init(String(localized: "Back camera presets")),
                    .init(String(localized: "Front camera presets")),
                    .init(String(localized: "Camera switching")),
                    .init(String(localized: "Background")),
                ]
            ),
            SettingsSearchNode(String(localized: "LUTs"), page: .cameraLuts, visible: showAll),
        ]
    )
}

private func audioSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Audio"),
        image: "waveform",
        page: .audio,
        visible: showAll,
        settings: [
            .init(String(localized: "Mic")),
            .init(String(localized: "Input gain")),
            .init(String(localized: "Output gain")),
            .init(String(localized: "Bluetooth output only")),
            .init(String(localized: "Prefer stereo mic")),
            .init(String(localized: "Output channel 1")),
            .init(String(localized: "Output channel 2")),
        ],
        children: [
            SettingsSearchNode(String(localized: "Delays"), page: .audioDelays),
            SettingsSearchNode(String(localized: "Gains"), page: .audioGains),
        ]
    )
}

private func ingestsSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Ingests"),
        image: "server.rack",
        page: .ingests,
        visible: showAll,
        settings: [
            .init(String(localized: "Software video decoding")),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "RTMP server"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Port")),
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "SRT(LA) server"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "SRT port")),
                    .init(String(localized: "SRTLA port")),
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "SRT client"),
                settings: [
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "RIST server"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Port")),
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "RTSP client"),
                settings: [
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "WHIP server"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Port")),
                    .init(String(localized: "Streams")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "WHEP client"),
                settings: [
                    .init(String(localized: "Streams")),
                ]
            ),
        ]
    )
}

private func moblinkSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Moblink"),
        image: "app.connected.to.app.below.fill",
        page: .moblink,
        settings: [
            .init(String(localized: "Password")),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Relay"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Name")),
                    .init(String(localized: "Manual")),
                    .init(String(localized: "Streamer URL")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Streamer"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Server port")),
                ]
            ),
        ]
    )
}

private func remoteControlSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Remote control"),
        image: "appletvremote.gen1",
        page: .remoteControl,
        visible: showAll,
        settings: [
            .init(String(localized: "Password")),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Streamer"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Reliable chat and events")),
                    .init(String(localized: "Preview FPS")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Assistant"),
                settings: [
                    .init(String(localized: "Current streamer")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Web"),
                settings: [
                    .init(String(localized: "Enabled")),
                    .init(String(localized: "Server port")),
                ]
            ),
        ]
    )
}

@MainActor
private func watchSettingsSearchNode() -> SettingsSearchNode {
    let phone = isPhone()
    return SettingsSearchNode(
        String(localized: "Apple Watch"),
        image: "applewatch",
        page: .watch,
        visible: { $0.showAllSettings && phone },
        settings: [
            .init(String(localized: "Remote control assistant")),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Chat"),
                page: .watchChat,
                settings: [
                    .init(String(localized: "Font size")),
                    .init(String(localized: "Timestamp")),
                    .init(String(localized: "Badges")),
                    .init(String(localized: "Notification on message")),
                    .init(String(localized: "Notification rate")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "Display"),
                page: .watchDisplay,
                children: [
                    SettingsSearchNode(
                        String(localized: "Local overlays"),
                        page: .watchLocalOverlays,
                        settings: [
                            .init(String(localized: "Thermal state")),
                            .init(String(localized: "Audio level")),
                            .init(String(localized: "Bitrate")),
                        ]
                    ),
                ]
            ),
        ]
    )
}

private func debugSettingsSearchNode() -> SettingsSearchNode {
    SettingsSearchNode(
        String(localized: "Debug"),
        image: "ladybug",
        page: .debug,
        visible: showAll,
        settings: [
            .init(String(localized: "Log")),
            .init(String(localized: "Logs directory")),
            .init(String(localized: "Debug logging")),
            .init(String("Maximum log lines")),
            .init(String(localized: "Debug overlay")),
            .init(String(localized: "Bitrate drop fix")),
            .init(String(localized: "Data rate limit")),
            .init(String(localized: "Relaxed bitrate decrement after scene switch")),
            .init(String(localized: "Twitch rewards")),
            .init(String(localized: "Builtin audio and video delay")),
            .init(String("Enhanced Moblin SRT")),
            .init(String(localized: "SRT(LA) packet padding")),
            .init(String(localized: "Camera man")),
        ],
        children: [
            SettingsSearchNode(
                String(localized: "Video"),
                page: .debugVideo,
                settings: [
                    .init(String(localized: "Native low light boost")),
                    .init(String(localized: "External camera video range")),
                    .init(String(localized: "Periodic video bitrate change")),
                    .init(String(localized: "Photos image quality")),
                ]
            ),
            SettingsSearchNode(
                String(localized: "HTTP proxy"),
                page: .debugHttpProxy,
                settings: [
                    .init(String(localized: "Port")),
                    .init(String(localized: "This device")),
                    .init(String(localized: "Local network")),
                ]
            ),
        ]
    )
}

@MainActor
func settingsSearchNodes(stream: SettingsStream) -> [SettingsSearchNode] {
    let pad = isPad()
    return [
        SettingsSearchNode(
            String(localized: "Streams"),
            image: "dot.radiowaves.left.and.right",
            page: .streams,
            children: [
                streamSettingsSearchNode(stream: stream),
            ]
        ),
        scenesSettingsSearchNode(),
        chatSettingsSearchNode(),
        displaySettingsSearchNode(),
        cameraSettingsSearchNode(),
        audioSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Macros"),
            image: "increase.indent",
            page: .macros,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Location"),
            image: "location",
            page: .location,
            settings: [
                .init(String(localized: "Enabled")),
                .init(String(localized: "Desired accuracy"), visible: showAll),
                .init(String(localized: "Distance filter"), visible: showAll),
                .init(String(localized: "Reset when going live")),
                .init(String(localized: "Privacy regions")),
            ]
        ),
        SettingsSearchNode(String(localized: "Store (support us) ❤️"), image: "cart", page: .store),
        ingestsSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Talkback"),
            image: "speaker.wave.2.bubble.left",
            page: .talkback,
            visible: showAll,
            settings: [
                .init(String(localized: "Enabled")),
                .init(String(localized: "Mic")),
            ]
        ),
        moblinkSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Media players"),
            image: "play.rectangle.on.rectangle",
            page: .mediaPlayers,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Apple Music"),
            image: "music.note",
            page: .appleMusic,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Gimbal"),
            image: "iphone.dock.motorized.viewfinder",
            page: .gimbal,
            visible: showAll,
            settings: [
                .init(String(localized: "Zoom")),
                .init(String(localized: "Natural")),
                .init(String(localized: "Tracking")),
                .init(String(localized: "Shutter button")),
                .init(String(localized: "Flip button")),
                .init(String(localized: "Presets")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "Selfie stick"),
            image: "line.diagonal",
            page: .selfieStick,
            visible: showAll,
            settings: [
                .init(String(localized: "Enabled")),
                .init(String(localized: "Button")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "Game controllers"),
            image: "gamecontroller",
            page: .gameControllers,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Keyboard"),
            image: "keyboard",
            page: .keyboard,
            visible: {
                if #available(iOS 17.0, *) {
                    $0.showAllSettings
                } else {
                    false
                }
            }
        ),
        SettingsSearchNode(
            String(localized: "Stream decks"),
            image: "square.grid.3x3.square",
            page: .streamDecks,
            visible: { $0.showAllSettings && !isMac() && pad }
        ),
        remoteControlSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Moblin Cloud"),
            image: "cloud",
            page: .moblinCloud,
            visible: showAllNotMac,
            settings: [
                .init(String(localized: "Enabled")),
                .init(String(localized: "Moblin Cloud key")),
                .init(String(localized: "Message")),
                .init(String(localized: "Wheel of luck")),
                .init(String(localized: "URL")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "DJI devices"),
            image: "appletvremote.gen1",
            page: .djiDevices,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "GoPro"),
            image: "appletvremote.gen1",
            page: .goPro,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Cat printers"),
            image: "pawprint",
            page: .catPrinters,
            visible: showAll,
            settings: [
                .init(String(localized: "Background printing")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "Tesla"),
            image: "car.side",
            page: .tesla,
            visible: showAll,
            settings: [
                .init(String(localized: "Enabled")),
                .init(String(localized: "Configuration")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "Workout devices"),
            image: "figure.walk.motion",
            page: .workoutDevices,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Black Shark coolers"),
            image: "fan",
            page: .blackSharkCoolers,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Recordings"),
            image: "photo.on.rectangle.angled",
            page: .recordings,
            settings: [
                .init(String(localized: "Default recordings directory")),
                .init(String(localized: "Current recordings directory")),
                .init(String(localized: "Replays directory")),
            ]
        ),
        SettingsSearchNode(
            String(localized: "Streaming history"),
            image: "text.book.closed",
            page: .streamingHistory,
            visible: showAll
        ),
        watchSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Help and support"),
            image: "questionmark.circle",
            page: .helpAndSupport
        ),
        SettingsSearchNode(
            String(localized: "About"),
            image: "info.circle",
            page: .about,
            visible: showAll,
            settings: [
                .init(String(localized: "Version")),
                .init(String(localized: "Version history")),
                .init(String(localized: "Privacy policy")),
                .init(String(localized: "End-user license agreement (EULA)")),
            ],
            children: [
                SettingsSearchNode(String(localized: "Attributions"), page: .aboutAttributions),
            ]
        ),
        debugSettingsSearchNode(),
        SettingsSearchNode(
            String(localized: "Import and export settings"),
            image: "gearshape",
            page: .importExport,
            visible: showAll
        ),
        SettingsSearchNode(
            String(localized: "Deep link creator"),
            image: "link.badge.plus",
            page: .deepLinkCreator,
            visible: showAll
        ),
    ]
}
