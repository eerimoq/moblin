import Foundation

class DeepLinkCreatorStreamVideo: Codable, ObservableObject {
    @Published var resolution: SettingsStreamResolution = SettingsStream.defaultResolution
    @Published var fps: Int = SettingsStream.defaultFps
    @Published var bitrate: UInt32 = 5_000_000
    @Published var codec: SettingsStreamCodec = .h265hevc
    @Published var bFrames: Bool = false
    @Published var maxKeyFrameInterval: Int32 = 2

    enum CodingKeys: CodingKey {
        case resolution,
             fps,
             bitrate,
             codec,
             bFrames,
             maxKeyFrameInterval
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.codec, codec)
        try container.encode(.bFrames, bFrames)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = container.decode(.resolution, SettingsStreamResolution.self, SettingsStream.defaultResolution)
        fps = container.decode(.fps, Int.self, SettingsStream.defaultFps)
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
        codec = container.decode(.codec, SettingsStreamCodec.self, .h265hevc)
        bFrames = container.decode(.bFrames, Bool.self, false)
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 2)
    }
}

class DeepLinkCreatorStreamAudio: Codable, ObservableObject {
    @Published var bitrate: Int = 128_000
    @Published var bitrateFloat: Float = 128

    enum CodingKeys: CodingKey {
        case bitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.bitrate, bitrate)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bitrate = container.decode(.bitrate, Int.self, 128_000)
        bitrateFloat = Float(bitrate / 1000)
    }
}

class DeepLinkCreatorStreamSrt: Codable, ObservableObject {
    @Published var latency: Int32 = defaultSrtLatency
    @Published var adaptiveBitrateEnabled: Bool = true
    @Published var dnsLookupStrategy: SettingsDnsLookupStrategy = .system

    enum CodingKeys: CodingKey {
        case latency,
             adaptiveBitrateEnabled,
             dnsLookupStrategy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.latency, latency)
        try container.encode(.adaptiveBitrateEnabled, adaptiveBitrateEnabled)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latency = container.decode(.latency, Int32.self, defaultSrtLatency)
        adaptiveBitrateEnabled = container.decode(.adaptiveBitrateEnabled, Bool.self, true)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
    }
}

class DeepLinkCreatorStreamObs: Codable, ObservableObject {
    @Published var webSocketUrl: String = ""
    @Published var webSocketPassword: String = ""

    enum CodingKeys: CodingKey {
        case webSocketUrl,
             webSocketPassword
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.webSocketUrl, webSocketUrl)
        try container.encode(.webSocketPassword, webSocketPassword)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        webSocketUrl = container.decode(.webSocketUrl, String.self, "")
        webSocketPassword = container.decode(.webSocketPassword, String.self, "")
    }
}

class DeepLinkCreatorStreamTwitch: Codable, ObservableObject {
    @Published var channelName: String = ""
    @Published var channelId: String = ""

    enum CodingKeys: CodingKey {
        case channelName,
             channelId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.channelName, channelName)
        try container.encode(.channelId, channelId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelName = container.decode(.channelName, String.self, "")
        channelId = container.decode(.channelId, String.self, "")
    }
}

class DeepLinkCreatorStreamKick: Codable, ObservableObject {
    @Published var channelName: String = ""

    enum CodingKeys: CodingKey {
        case channelName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.channelName, channelName)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelName = container.decode(.channelName, String.self, "")
    }
}

class DeepLinkCreatorStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = defaultStreamUrl
    @Published var selected: Bool = false
    @Published var video: DeepLinkCreatorStreamVideo = .init()
    @Published var audio: DeepLinkCreatorStreamAudio = .init()
    @Published var srt: DeepLinkCreatorStreamSrt = .init()
    @Published var obs: DeepLinkCreatorStreamObs = .init()
    @Published var twitch: DeepLinkCreatorStreamTwitch = .init()
    @Published var kick: DeepLinkCreatorStreamKick = .init()

    enum CodingKeys: CodingKey {
        case id,
             name,
             url,
             selected,
             video,
             audio,
             srt,
             obs,
             twitch,
             kick
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.selected, selected)
        try container.encode(.video, video)
        try container.encode(.audio, audio)
        try container.encode(.srt, srt)
        try container.encode(.obs, obs)
        try container.encode(.twitch, twitch)
        try container.encode(.kick, kick)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, defaultStreamUrl)
        selected = container.decode(.selected, Bool.self, false)
        video = container.decode(.video, DeepLinkCreatorStreamVideo.self, .init())
        audio = container.decode(.audio, DeepLinkCreatorStreamAudio.self, .init())
        srt = container.decode(.srt, DeepLinkCreatorStreamSrt.self, .init())
        obs = container.decode(.obs, DeepLinkCreatorStreamObs.self, .init())
        twitch = container.decode(.twitch, DeepLinkCreatorStreamTwitch.self, .init())
        kick = container.decode(.kick, DeepLinkCreatorStreamKick.self, .init())
    }
}

class DeepLinkCreatorQuickButton: Codable, Identifiable, ObservableObject {
    @Published var id: UUID = .init()
    @Published var type: SettingsQuickButtonType = .unknown
    @Published var enabled: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             type,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.enabled, enabled)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsQuickButtonType.self, .unknown)
        enabled = container.decode(.enabled, Bool.self, false)
    }
}

class DeepLinkCreatorQuickButtons: Codable, ObservableObject {
    @Published var twoColumns: Bool = true
    @Published var showName: Bool = true
    @Published var enableScroll: Bool = true
    @Published var buttons: [DeepLinkCreatorQuickButton] = []

    enum CodingKeys: CodingKey {
        case twoColumns,
             showName,
             enableScroll,
             buttons
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twoColumns, twoColumns)
        try container.encode(.showName, showName)
        try container.encode(.enableScroll, enableScroll)
        try container.encode(.buttons, buttons)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoColumns = container.decode(.twoColumns, Bool.self, true)
        showName = container.decode(.showName, Bool.self, true)
        enableScroll = container.decode(.enableScroll, Bool.self, true)
        buttons = container.decode(.buttons, [DeepLinkCreatorQuickButton].self, [])
    }
}

class DeepLinkCreatorWebBrowser: Codable, ObservableObject {
    @Published var home: String = ""

    enum CodingKeys: CodingKey {
        case home
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.home, home)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        home = container.decode(.home, String.self, "")
    }
}

class DeepLinkCreator: Codable, ObservableObject {
    @Published var streams: [DeepLinkCreatorStream] = []
    @Published var quickButtonsEnabled: Bool = false
    @Published var quickButtons: DeepLinkCreatorQuickButtons = .init()
    @Published var webBrowserEnabled: Bool = false
    @Published var webBrowser: DeepLinkCreatorWebBrowser = .init()

    enum CodingKeys: CodingKey {
        case streams,
             quickButtonsEnabled,
             quickButtons,
             webBrowserEnabled,
             webBrowser
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
        try container.encode(.quickButtonsEnabled, quickButtonsEnabled)
        try container.encode(.quickButtons, quickButtons)
        try container.encode(.webBrowserEnabled, webBrowserEnabled)
        try container.encode(.webBrowser, webBrowser)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [DeepLinkCreatorStream].self, [])
        quickButtonsEnabled = container.decode(.quickButtonsEnabled, Bool.self, false)
        quickButtons = container.decode(.quickButtons, DeepLinkCreatorQuickButtons.self, .init())
        webBrowserEnabled = container.decode(.webBrowserEnabled, Bool.self, false)
        webBrowser = container.decode(.webBrowser, DeepLinkCreatorWebBrowser.self, .init())
    }
}
