import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"
let defaultQuickButtonColor = RgbColor(red: 255 / 4, green: 255 / 4, blue: 255 / 4)
let defaultStreamButtonColor = RgbColor(red: 255, green: 59, blue: 48)
let defaultSrtLatency: Int32 = 3000
private let defaultRtmpLatency: Int32 = 2000
let minZoomX: Float = 0.5

enum SettingsStreamCodec: String, Codable, CaseIterable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"

    public init(from decoder: Decoder) throws {
        self = try SettingsStreamCodec(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .h264avc
    }

    func shortString() -> String {
        switch self {
        case .h265hevc:
            return "H.265"
        case .h264avc:
            return "H.264"
        }
    }
}

let codecs = SettingsStreamCodec.allCases.map { $0.rawValue }

enum SettingsStreamResolution: String, Codable, CaseIterable {
    case r3840x2160 = "3840x2160"
    case r2560x1440 = "2560x1440"
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"

    public init(from decoder: Decoder) throws {
        self = try SettingsStreamResolution(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .r1920x1080
    }

    func shortString() -> String {
        switch self {
        case .r3840x2160:
            return "4K"
        case .r2560x1440:
            return "1440p"
        case .r1920x1080:
            return "1080p"
        case .r1280x720:
            return "720p"
        case .r854x480:
            return "480p"
        case .r640x360:
            return "360p"
        case .r426x240:
            return "240p"
        }
    }

    func dimensions(portrait: Bool) -> CMVideoDimensions {
        var size: CMVideoDimensions
        switch self {
        case .r3840x2160:
            size = .init(width: 3840, height: 2160)
        case .r2560x1440:
            size = .init(width: 2560, height: 1440)
        case .r1920x1080:
            size = .init(width: 1920, height: 1080)
        case .r1280x720:
            size = .init(width: 1280, height: 720)
        case .r854x480:
            size = .init(width: 854, height: 480)
        case .r640x360:
            size = .init(width: 640, height: 360)
        case .r426x240:
            size = .init(width: 426, height: 240)
        }
        if portrait {
            size = .init(width: size.height, height: size.width)
        }
        return size
    }
}

let resolutions = SettingsStreamResolution.allCases

let fpss = [120, 100, 60, 50, 30, 25, 15]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
    case rist = "RIST"
    case irl = "IRL"

    public init(from decoder: Decoder) throws {
        self = try SettingsStreamProtocol(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .rtmp
    }
}

class SettingsStreamSrtConnectionPriority: Codable, Identifiable {
    var id: UUID = .init()
    var name: String
    var priority: Int = 1
    var enabled: Bool? = true
    var relayId: UUID?

    init(name: String) {
        self.name = name
    }

    func clone() -> SettingsStreamSrtConnectionPriority {
        let new = SettingsStreamSrtConnectionPriority(name: name)
        new.priority = priority
        new.enabled = enabled
        new.relayId = relayId
        return new
    }
}

class SettingsStreamSrtConnectionPriorities: Codable {
    var enabled: Bool = false
    var priorities: [SettingsStreamSrtConnectionPriority] = [
        SettingsStreamSrtConnectionPriority(name: "Cellular"),
        SettingsStreamSrtConnectionPriority(name: "WiFi"),
    ]

    func clone() -> SettingsStreamSrtConnectionPriorities {
        let new = SettingsStreamSrtConnectionPriorities()
        new.enabled = enabled
        new.priorities.removeAll()
        for priority in priorities {
            new.priorities.append(priority.clone())
        }
        return new
    }
}

enum SettingsStreamSrtAdaptiveBitrateAlgorithm: Codable, CaseIterable {
    case belabox
    case fastIrl
    case slowIrl
    case customIrl

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(CodingKeys.belabox) {
            self = .belabox
        } else if container.contains(CodingKeys.fastIrl) {
            self = .fastIrl
        } else if container.contains(CodingKeys.slowIrl) {
            self = .slowIrl
        } else if container.contains(CodingKeys.customIrl) {
            self = .customIrl
        } else {
            self = .belabox
        }
    }

    func toString() -> String {
        switch self {
        case .belabox:
            return String(localized: "BELABOX")
        case .fastIrl:
            return String(localized: "Fast IRL")
        case .slowIrl:
            return String(localized: "Slow IRL")
        case .customIrl:
            return String(localized: "Custom IRL")
        }
    }
}

class SettingsStreamSrtAdaptiveBitrateFastIrlSettings: Codable {
    var packetsInFlight: Int32 = 200
    var minimumBitrate: Float? = 250

    func clone() -> SettingsStreamSrtAdaptiveBitrateFastIrlSettings {
        let new = SettingsStreamSrtAdaptiveBitrateFastIrlSettings()
        new.packetsInFlight = packetsInFlight
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrateCustomSettings: Codable {
    var packetsInFlight: Int32 = 200
    var pifDiffIncreaseFactor: Float = 100
    var rttDiffHighDecreaseFactor: Float = 0.9
    var rttDiffHighAllowedSpike: Float = 50
    var rttDiffHighMinimumDecrease: Float = 250
    var minimumBitrate: Float? = 250

    func clone() -> SettingsStreamSrtAdaptiveBitrateCustomSettings {
        let new = SettingsStreamSrtAdaptiveBitrateCustomSettings()
        new.packetsInFlight = packetsInFlight
        new.pifDiffIncreaseFactor = pifDiffIncreaseFactor
        new.rttDiffHighDecreaseFactor = rttDiffHighDecreaseFactor
        new.rttDiffHighAllowedSpike = rttDiffHighAllowedSpike
        new.rttDiffHighMinimumDecrease = rttDiffHighMinimumDecrease
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrateBelaboxSettings: Codable {
    var minimumBitrate: Float = 250

    func clone() -> SettingsStreamSrtAdaptiveBitrateBelaboxSettings {
        let new = SettingsStreamSrtAdaptiveBitrateBelaboxSettings()
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrate: Codable {
    var algorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm = .belabox
    var fastIrlSettings: SettingsStreamSrtAdaptiveBitrateFastIrlSettings? = .init()
    var customSettings: SettingsStreamSrtAdaptiveBitrateCustomSettings = .init()
    var belaboxSettings: SettingsStreamSrtAdaptiveBitrateBelaboxSettings? = .init()

    func clone() -> SettingsStreamSrtAdaptiveBitrate {
        let new = SettingsStreamSrtAdaptiveBitrate()
        new.algorithm = algorithm
        new.fastIrlSettings = fastIrlSettings!.clone()
        new.customSettings = customSettings.clone()
        new.belaboxSettings = belaboxSettings!.clone()
        return new
    }
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = defaultSrtLatency
    var maximumBandwidthFollowInput: Bool? = true
    var overheadBandwidth: Int32? = 25
    var adaptiveBitrateEnabled: Bool? = true
    var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate? = .init()
    var connectionPriorities: SettingsStreamSrtConnectionPriorities? = .init()
    var mpegtsPacketsPerPacket: Int = 7
    var dnsLookupStrategy: SettingsDnsLookupStrategy? = .system

    func clone() -> SettingsStreamSrt {
        let new = SettingsStreamSrt()
        new.latency = latency
        new.overheadBandwidth = overheadBandwidth
        new.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.adaptiveBitrate = adaptiveBitrate!.clone()
        new.connectionPriorities = connectionPriorities!.clone()
        new.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        new.dnsLookupStrategy = dnsLookupStrategy
        return new
    }
}

class SettingsStreamRtmp: Codable {
    var adaptiveBitrateEnabled: Bool = false

    func clone() -> SettingsStreamRtmp {
        let new = SettingsStreamRtmp()
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        return new
    }
}

class SettingsStreamRist: Codable {
    var adaptiveBitrateEnabled: Bool = false
    var bonding: Bool = false

    func clone() -> SettingsStreamRist {
        let new = SettingsStreamRist()
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.bonding = bonding
        return new
    }
}

enum SettingsCaptureSessionPreset: String, Codable, CaseIterable {
    case high
    case medium
    case low
    case hd1280x720
    case hd1920x1080
    case hd4K3840x2160
    case vga640x480
    case iFrame960x540
    case iFrame1280x720
    case cif352x288

    public init(from decoder: Decoder) throws {
        self = try SettingsCaptureSessionPreset(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .hd1920x1080
    }
}

class SettingsStreamChat: Codable {
    var bttvEmotes: Bool = false
    var ffzEmotes: Bool = false
    var seventvEmotes: Bool = false

    func clone() -> SettingsStreamChat {
        let new = SettingsStreamChat()
        new.bttvEmotes = bttvEmotes
        new.ffzEmotes = ffzEmotes
        new.seventvEmotes = seventvEmotes
        return new
    }
}

class SettingsStreamRecording: Codable {
    var videoCodec: SettingsStreamCodec = .h265hevc
    var videoBitrate: UInt32 = 0
    var maxKeyFrameInterval: Int32 = 0
    var audioBitrate: UInt32? = 128_000
    var autoStartRecording: Bool? = false
    var autoStopRecording: Bool? = false
    var cleanRecordings: Bool? = false
    var cleanSnapshots: Bool? = false

    func clone() -> SettingsStreamRecording {
        let new = SettingsStreamRecording()
        new.videoCodec = videoCodec
        new.videoBitrate = videoBitrate
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.autoStartRecording = autoStartRecording
        new.autoStopRecording = autoStopRecording
        new.cleanRecordings = cleanRecordings
        new.cleanSnapshots = cleanSnapshots
        return new
    }

    func videoCodecString() -> String {
        switch videoCodec {
        case .h265hevc:
            return "H.265"
        case .h264avc:
            return "H.264"
        }
    }

    func videoBitrateString() -> String {
        if videoBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(videoBitrate))
        } else {
            return "Auto"
        }
    }

    func maxKeyFrameIntervalString() -> String {
        if maxKeyFrameInterval != 0 {
            return String(maxKeyFrameInterval)
        } else {
            return "Auto"
        }
    }

    func audioBitrateString() -> String {
        if let audioBitrate, audioBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(audioBitrate))
        } else {
            return "Auto"
        }
    }
}

class SettingsStreamReplay: Codable {
    var enabled: Bool = false
    var fade: Bool? = true

    func clone() -> SettingsStreamReplay {
        let new = SettingsStreamReplay()
        new.enabled = enabled
        new.fade = fade
        return new
    }
}

class SettingsStreamTwitchReward: Codable, Identifiable {
    var id: UUID = .init()
    // periphery:ignore
    var rewardId: String = ""
    var title: String = ""
    // periphery:ignore
    var alert: SettingsWidgetAlertsAlert = .init()
}

class SettingsStream: Codable, Identifiable, Equatable, ObservableObject {
    @Published var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    var url: String = defaultStreamUrl
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var twitchShowFollows: Bool = true
    var twitchAccessToken: String = ""
    var twitchLoggedIn: Bool = false
    var twitchRewards: [SettingsStreamTwitchReward] = []
    var kickChatroomId: String = ""
    var kickChannelName: String = ""
    var youTubeApiKey: String = ""
    @Published var youTubeVideoId: String = ""
    @Published var youTubeHandle: String = ""
    var afreecaTvChannelName: String = ""
    var afreecaTvStreamId: String = ""
    var openStreamingPlatformUrl: String = ""
    var openStreamingPlatformChannelId: String = ""
    var obsWebSocketEnabled: Bool = false
    var obsWebSocketUrl: String = ""
    var obsWebSocketPassword: String = ""
    var obsSourceName: String = ""
    var obsMainScene: String = ""
    var obsBrbScene: String = ""
    var obsBrbSceneVideoSourceBroken: Bool = false
    var obsAutoStartStream: Bool = false
    var obsAutoStopStream: Bool = false
    var obsAutoStartRecording: Bool = false
    var obsAutoStopRecording: Bool = false
    var discordSnapshotWebhook: String = ""
    var discordChatBotSnapshotWebhook: String = ""
    @Published var discordSnapshotWebhookOnlyWhenLive: Bool = true
    @Published var resolution: SettingsStreamResolution = .r1920x1080
    @Published var fps: Int = 30
    @Published var autoFps: Bool = false
    @Published var bitrate: UInt32 = 5_000_000
    @Published var codec: SettingsStreamCodec = .h265hevc
    @Published var bFrames: Bool = false
    @Published var adaptiveEncoderResolution: Bool = false
    var adaptiveBitrate: Bool = true
    var srt: SettingsStreamSrt = .init()
    var rtmp: SettingsStreamRtmp = .init()
    var rist: SettingsStreamRist = .init()
    var captureSessionPresetEnabled: Bool = false
    var captureSessionPreset: SettingsCaptureSessionPreset = .medium
    @Published var maxKeyFrameInterval: Int32 = 2
    var audioBitrate: Int = 128_000
    var chat: SettingsStreamChat = .init()
    var recording: SettingsStreamRecording = .init()
    var realtimeIrlEnabled: Bool = false
    var realtimeIrlPushKey: String = ""
    @Published var portrait: Bool = false
    var backgroundStreaming: Bool = false
    var estimatedViewerDelay: Float = 8.0
    var twitchMultiTrackEnabled: Bool = false
    @Published var ntpPoolAddress: String = "time.apple.com"
    @Published var timecodesEnabled: Bool = false
    var replay: SettingsStreamReplay = .init()
    @Published var goLiveNotificationDiscordMessage: String = ""
    @Published var goLiveNotificationDiscordWebhookUrl: String = ""
    @Published var goLiveNotificationDiscordIAmLive: Bool = false

    static func == (lhs: SettingsStream, rhs: SettingsStream) -> Bool {
        lhs.id == rhs.id
    }

    init(name: String) {
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             enabled,
             url,
             twitchChannelName,
             twitchChannelId,
             twitchShowFollows,
             twitchAccessToken,
             twitchLoggedIn,
             twitchRewards,
             kickChatroomId,
             kickChannelName,
             youTubeApiKey,
             youTubeVideoId,
             youTubeHandle,
             afreecaTvChannelName,
             afreecaTvStreamId,
             openStreamingPlatformUrl,
             openStreamingPlatformChannelId,
             obsWebSocketEnabled,
             obsWebSocketUrl,
             obsWebSocketPassword,
             obsSourceName,
             obsMainScene,
             obsBrbScene,
             obsBrbSceneVideoSourceBroken,
             obsAutoStartStream,
             obsAutoStopStream,
             obsAutoStartRecording,
             obsAutoStopRecording,
             discordSnapshotWebhook,
             discordChatBotSnapshotWebhook,
             discordSnapshotWebhookOnlyWhenLive,
             resolution,
             fps,
             autoFps,
             bitrate,
             codec,
             bFrames,
             adaptiveEncoderResolution,
             adaptiveBitrate,
             srt,
             rtmp,
             rist,
             captureSessionPresetEnabled,
             captureSessionPreset,
             maxKeyFrameInterval,
             audioBitrate,
             chat,
             recording,
             realtimeIrlEnabled,
             realtimeIrlPushKey,
             portrait,
             backgroundStreaming,
             estimatedViewerDelay,
             twitchMultiTrackEnabled,
             ntpPoolAddress,
             timecodesEnabled,
             replay,
             goLiveNotificationDiscordMessage,
             goLiveNotificationDiscordWebhookUrl,
             goLiveNotificationDiscordIAmLive
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.twitchChannelName, twitchChannelName)
        try container.encode(.twitchChannelId, twitchChannelId)
        try container.encode(.twitchShowFollows, twitchShowFollows)
        try container.encode(.twitchAccessToken, twitchAccessToken)
        try container.encode(.twitchLoggedIn, twitchLoggedIn)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.kickChatroomId, kickChatroomId)
        try container.encode(.kickChannelName, kickChannelName)
        try container.encode(.youTubeApiKey, youTubeApiKey)
        try container.encode(.youTubeVideoId, youTubeVideoId)
        try container.encode(.youTubeHandle, youTubeHandle)
        try container.encode(.afreecaTvChannelName, afreecaTvChannelName)
        try container.encode(.afreecaTvStreamId, afreecaTvStreamId)
        try container.encode(.openStreamingPlatformUrl, openStreamingPlatformUrl)
        try container.encode(.openStreamingPlatformChannelId, openStreamingPlatformChannelId)
        try container.encode(.obsWebSocketEnabled, obsWebSocketEnabled)
        try container.encode(.obsWebSocketUrl, obsWebSocketUrl)
        try container.encode(.obsWebSocketPassword, obsWebSocketPassword)
        try container.encode(.obsSourceName, obsSourceName)
        try container.encode(.obsMainScene, obsMainScene)
        try container.encode(.obsBrbScene, obsBrbScene)
        try container.encode(.obsBrbSceneVideoSourceBroken, obsBrbSceneVideoSourceBroken)
        try container.encode(.obsAutoStartStream, obsAutoStartStream)
        try container.encode(.obsAutoStopStream, obsAutoStopStream)
        try container.encode(.obsAutoStartRecording, obsAutoStartRecording)
        try container.encode(.obsAutoStopRecording, obsAutoStopRecording)
        try container.encode(.discordSnapshotWebhook, discordSnapshotWebhook)
        try container.encode(.discordChatBotSnapshotWebhook, discordChatBotSnapshotWebhook)
        try container.encode(.discordSnapshotWebhookOnlyWhenLive, discordSnapshotWebhookOnlyWhenLive)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.autoFps, autoFps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.codec, codec)
        try container.encode(.bFrames, bFrames)
        try container.encode(.adaptiveEncoderResolution, adaptiveEncoderResolution)
        try container.encode(.adaptiveBitrate, adaptiveBitrate)
        try container.encode(.srt, srt)
        try container.encode(.rtmp, rtmp)
        try container.encode(.rist, rist)
        try container.encode(.captureSessionPresetEnabled, captureSessionPresetEnabled)
        try container.encode(.captureSessionPreset, captureSessionPreset)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
        try container.encode(.audioBitrate, audioBitrate)
        try container.encode(.chat, chat)
        try container.encode(.recording, recording)
        try container.encode(.realtimeIrlEnabled, realtimeIrlEnabled)
        try container.encode(.realtimeIrlPushKey, realtimeIrlPushKey)
        try container.encode(.portrait, portrait)
        try container.encode(.backgroundStreaming, backgroundStreaming)
        try container.encode(.estimatedViewerDelay, estimatedViewerDelay)
        try container.encode(.twitchMultiTrackEnabled, twitchMultiTrackEnabled)
        try container.encode(.ntpPoolAddress, ntpPoolAddress)
        try container.encode(.timecodesEnabled, timecodesEnabled)
        try container.encode(.replay, replay)
        try container.encode(.goLiveNotificationDiscordMessage, goLiveNotificationDiscordMessage)
        try container.encode(.goLiveNotificationDiscordWebhookUrl, goLiveNotificationDiscordWebhookUrl)
        try container.encode(.goLiveNotificationDiscordIAmLive, goLiveNotificationDiscordIAmLive)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "My stream")
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, false)
        url = container.decode(.url, String.self, defaultStreamUrl)
        twitchChannelName = container.decode(.twitchChannelName, String.self, "")
        twitchChannelId = container.decode(.twitchChannelId, String.self, "")
        twitchShowFollows = container.decode(.twitchShowFollows, Bool.self, true)
        twitchAccessToken = container.decode(.twitchAccessToken, String.self, "")
        twitchLoggedIn = container.decode(.twitchLoggedIn, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, [SettingsStreamTwitchReward].self, [])
        kickChatroomId = container.decode(.kickChatroomId, String.self, "")
        kickChannelName = container.decode(.kickChannelName, String.self, "")
        youTubeApiKey = container.decode(.youTubeApiKey, String.self, "")
        youTubeVideoId = container.decode(.youTubeVideoId, String.self, "")
        youTubeHandle = container.decode(.youTubeHandle, String.self, "")
        afreecaTvChannelName = container.decode(.afreecaTvChannelName, String.self, "")
        afreecaTvStreamId = container.decode(.afreecaTvStreamId, String.self, "")
        openStreamingPlatformUrl = container.decode(.openStreamingPlatformUrl, String.self, "")
        openStreamingPlatformChannelId = container.decode(.openStreamingPlatformChannelId, String.self, "")
        obsWebSocketEnabled = container.decode(.obsWebSocketEnabled, Bool.self, false)
        obsWebSocketUrl = container.decode(.obsWebSocketUrl, String.self, "")
        obsWebSocketPassword = container.decode(.obsWebSocketPassword, String.self, "")
        obsSourceName = container.decode(.obsSourceName, String.self, "")
        obsMainScene = container.decode(.obsMainScene, String.self, "")
        obsBrbScene = container.decode(.obsBrbScene, String.self, "")
        obsBrbSceneVideoSourceBroken = container.decode(.obsBrbSceneVideoSourceBroken, Bool.self, false)
        obsAutoStartStream = container.decode(.obsAutoStartStream, Bool.self, false)
        obsAutoStopStream = container.decode(.obsAutoStopStream, Bool.self, false)
        obsAutoStartRecording = container.decode(.obsAutoStartRecording, Bool.self, false)
        obsAutoStopRecording = container.decode(.obsAutoStopRecording, Bool.self, false)
        discordSnapshotWebhook = container.decode(.discordSnapshotWebhook, String.self, "")
        discordChatBotSnapshotWebhook = container.decode(.discordChatBotSnapshotWebhook, String.self, "")
        discordSnapshotWebhookOnlyWhenLive = container.decode(.discordSnapshotWebhookOnlyWhenLive, Bool.self, true)
        resolution = container.decode(.resolution, SettingsStreamResolution.self, .r1920x1080)
        fps = container.decode(.fps, Int.self, 30)
        autoFps = container.decode(.autoFps, Bool.self, false)
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
        codec = container.decode(.codec, SettingsStreamCodec.self, .h265hevc)
        bFrames = container.decode(.bFrames, Bool.self, false)
        adaptiveEncoderResolution = container.decode(.adaptiveEncoderResolution, Bool.self, false)
        adaptiveBitrate = container.decode(.adaptiveBitrate, Bool.self, true)
        srt = container.decode(.srt, SettingsStreamSrt.self, .init())
        rtmp = container.decode(.rtmp, SettingsStreamRtmp.self, .init())
        rist = container.decode(.rist, SettingsStreamRist.self, .init())
        captureSessionPresetEnabled = container.decode(.captureSessionPresetEnabled, Bool.self, false)
        captureSessionPreset = container.decode(.captureSessionPreset, SettingsCaptureSessionPreset.self, .medium)
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 2)
        audioBitrate = container.decode(.audioBitrate, Int.self, 128_000)
        chat = container.decode(.chat, SettingsStreamChat.self, .init())
        recording = container.decode(.recording, SettingsStreamRecording.self, .init())
        realtimeIrlEnabled = container.decode(.realtimeIrlEnabled, Bool.self, false)
        realtimeIrlPushKey = container.decode(.realtimeIrlPushKey, String.self, "")
        portrait = container.decode(.portrait, Bool.self, false)
        backgroundStreaming = container.decode(.backgroundStreaming, Bool.self, false)
        estimatedViewerDelay = container.decode(.estimatedViewerDelay, Float.self, 8.0)
        twitchMultiTrackEnabled = container.decode(.twitchMultiTrackEnabled, Bool.self, false)
        ntpPoolAddress = container.decode(.ntpPoolAddress, String.self, "time.apple.com")
        timecodesEnabled = container.decode(.timecodesEnabled, Bool.self, false)
        replay = container.decode(.replay, SettingsStreamReplay.self, .init())
        goLiveNotificationDiscordMessage = container.decode(.goLiveNotificationDiscordMessage, String.self, "")
        goLiveNotificationDiscordWebhookUrl = container.decode(.goLiveNotificationDiscordWebhookUrl, String.self, "")
        goLiveNotificationDiscordIAmLive = container.decode(.goLiveNotificationDiscordIAmLive, Bool.self, false)
    }

    func clone() -> SettingsStream {
        let new = SettingsStream(name: name)
        new.url = url
        new.twitchChannelName = twitchChannelName
        new.twitchChannelId = twitchChannelId
        new.kickChatroomId = kickChatroomId
        new.kickChannelName = kickChannelName
        new.youTubeApiKey = youTubeApiKey
        new.youTubeVideoId = youTubeVideoId
        new.youTubeHandle = youTubeHandle
        new.afreecaTvChannelName = afreecaTvChannelName
        new.afreecaTvStreamId = afreecaTvStreamId
        new.openStreamingPlatformUrl = openStreamingPlatformUrl
        new.openStreamingPlatformChannelId = openStreamingPlatformChannelId
        new.obsWebSocketEnabled = obsWebSocketEnabled
        new.obsWebSocketUrl = obsWebSocketUrl
        new.obsWebSocketPassword = obsWebSocketPassword
        new.obsSourceName = obsSourceName
        new.obsBrbScene = obsBrbScene
        new.obsMainScene = obsMainScene
        new.obsBrbSceneVideoSourceBroken = obsBrbSceneVideoSourceBroken
        new.obsAutoStartStream = obsAutoStartStream
        new.obsAutoStopStream = obsAutoStopStream
        new.obsAutoStartRecording = obsAutoStartRecording
        new.obsAutoStopRecording = obsAutoStopRecording
        new.discordSnapshotWebhook = discordSnapshotWebhook
        new.discordChatBotSnapshotWebhook = discordChatBotSnapshotWebhook
        new.discordSnapshotWebhookOnlyWhenLive = discordSnapshotWebhookOnlyWhenLive
        new.resolution = resolution
        new.fps = fps
        new.bitrate = bitrate
        new.codec = codec
        new.bFrames = bFrames
        new.adaptiveBitrate = adaptiveBitrate
        new.srt = srt.clone()
        new.rtmp = rtmp.clone()
        new.rist = rist.clone()
        new.captureSessionPresetEnabled = captureSessionPresetEnabled
        new.captureSessionPreset = captureSessionPreset
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.chat = chat.clone()
        new.recording = recording.clone()
        new.realtimeIrlEnabled = realtimeIrlEnabled
        new.realtimeIrlPushKey = realtimeIrlPushKey
        new.portrait = portrait
        new.backgroundStreaming = backgroundStreaming
        new.estimatedViewerDelay = estimatedViewerDelay
        new.twitchMultiTrackEnabled = twitchMultiTrackEnabled
        new.ntpPoolAddress = ntpPoolAddress
        new.timecodesEnabled = timecodesEnabled
        new.replay = replay.clone()
        new.goLiveNotificationDiscordMessage = goLiveNotificationDiscordMessage
        new.goLiveNotificationDiscordWebhookUrl = goLiveNotificationDiscordWebhookUrl
        new.goLiveNotificationDiscordIAmLive = goLiveNotificationDiscordIAmLive
        return new
    }

    private func getScheme() -> String? {
        return URL(string: url)!.scheme
    }

    func getProtocol() -> SettingsStreamProtocol {
        switch getScheme() {
        case "rtmp":
            return .rtmp
        case "rtmps":
            return .rtmp
        case "srt":
            return .srt
        case "srtla":
            return .srt
        case "rist":
            return .rist
        case "irl":
            return .irl
        default:
            return .rtmp
        }
    }

    func protocolString() -> String {
        if getProtocol() == .srt && isSrtla() {
            return "SRTLA"
        } else if getProtocol() == .rtmp && isRtmps() {
            return "RTMPS"
        } else {
            return getProtocol().rawValue
        }
    }

    func isRtmps() -> Bool {
        return getScheme() == "rtmps"
    }

    func isSrtla() -> Bool {
        return getScheme() == "srtla"
    }

    func isBonding() -> Bool {
        if isSrtla() {
            return true
        }
        if getProtocol() == .rist && rist.bonding {
            return true
        }
        return false
    }

    func resolutionString() -> String {
        return resolution.shortString()
    }

    func dimensions() -> CMVideoDimensions {
        return resolution.dimensions(portrait: portrait)
    }

    func codecString() -> String {
        return codec.shortString()
    }

    func bitrateString() -> String {
        var bitrate = formatBytesPerSecond(speed: Int64(bitrate))
        if getProtocol() == .srt && (srt.adaptiveBitrateEnabled ?? false) {
            bitrate = "<\(bitrate)"
        } else if getProtocol() == .rtmp && rtmp.adaptiveBitrateEnabled {
            bitrate = "<\(bitrate)"
        }
        return bitrate
    }

    func audioBitrateString() -> String {
        return formatBytesPerSecond(speed: Int64(audioBitrate))
    }

    func audioCodecString() -> String {
        return makeAudioCodecString()
    }
}

class SettingsSceneWidget: Codable, Identifiable, Equatable {
    static func == (lhs: SettingsSceneWidget, rhs: SettingsSceneWidget) -> Bool {
        return lhs.id == rhs.id
    }

    var widgetId: UUID
    var enabled: Bool = true
    var id: UUID = .init()
    var x: Double = 0.0
    var y: Double = 0.0
    var width: Double = 100.0
    var height: Double = 100.0

    init(widgetId: UUID) {
        self.widgetId = widgetId
    }

    func clone() -> SettingsSceneWidget {
        let new = SettingsSceneWidget(widgetId: widgetId)
        new.enabled = enabled
        new.x = x
        new.y = y
        new.width = width
        new.height = height
        return new
    }

    func isSamePositioning(other: SettingsSceneWidget) -> Bool {
        return x == other.x && y == other.y && width == other.width && height == other.height
    }

    func extent() -> CGRect {
        return .init(x: x, y: y, width: width, height: height)
    }
}

enum SettingsSceneCameraPosition: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"
    case rtmp = "RTMP"
    case external = "External"
    case srtla = "SRT(LA)"
    case mediaPlayer = "Media player"
    case screenCapture = "Screen capture"
    case backTripleLowEnergy = "Back triple"
    case backDualLowEnergy = "Back dual"
    case backWideDualLowEnergy = "Back wide dual"

    public init(from decoder: Decoder) throws {
        self = try SettingsSceneCameraPosition(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .back
    }

    func isBuiltin() -> Bool {
        return builtinCameraPositions.contains(self)
    }
}

private let builtinCameraPositions: [SettingsSceneCameraPosition] = [
    .back,
    .front,
    .backTripleLowEnergy,
    .backDualLowEnergy,
    .backWideDualLowEnergy,
]

enum SettingsCameraId {
    case back(id: String)
    case front(id: String)
    case rtmp(id: UUID)
    case srtla(id: UUID)
    case mediaPlayer(id: UUID)
    case external(id: String, name: String)
    case screenCapture
    case backTripleLowEnergy
    case backDualLowEnergy
    case backWideDualLowEnergy
}

class SettingsScene: Codable, Identifiable, Equatable, ObservableObject {
    @Published var name: String
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var cameraType: SettingsSceneCameraPosition = .back
    @Published var cameraPosition: SettingsSceneCameraPosition = .back
    @Published var backCameraId: String = getBestBackCameraId()
    @Published var frontCameraId: String = getBestFrontCameraId()
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    var externalCameraName: String = ""
    @Published var widgets: [SettingsSceneWidget] = []
    @Published var videoSourceRotation: Double = 0.0
    @Published var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    @Published var overrideVideoStabilizationMode: Bool = false
    @Published var fillFrame: Bool = false

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsScene, rhs: SettingsScene) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             enabled,
             cameraType,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             widgets,
             videoSourceRotation,
             videoStabilizationMode,
             overrideVideoStabilizationMode,
             fillFrame
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.cameraType, cameraType)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.widgets, widgets)
        try container.encode(.videoSourceRotation, videoSourceRotation)
        try container.encode(.videoStabilizationMode, videoStabilizationMode)
        try container.encode(.overrideVideoStabilizationMode, overrideVideoStabilizationMode)
        try container.encode(.fillFrame, fillFrame)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        cameraType = container.decode(.cameraType, SettingsSceneCameraPosition.self, .back)
        cameraPosition = container.decode(.cameraPosition, SettingsSceneCameraPosition.self, .back)
        backCameraId = container.decode(.backCameraId, String.self, getBestBackCameraId())
        frontCameraId = container.decode(.frontCameraId, String.self, getBestFrontCameraId())
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        widgets = container.decode(.widgets, [SettingsSceneWidget].self, [])
        videoSourceRotation = container.decode(.videoSourceRotation, Double.self, 0.0)
        videoStabilizationMode = container.decode(.videoStabilizationMode, SettingsVideoStabilizationMode.self, .off)
        overrideVideoStabilizationMode = container.decode(.overrideVideoStabilizationMode, Bool.self, false)
        fillFrame = container.decode(.fillFrame, Bool.self, false)
    }

    func clone() -> SettingsScene {
        let new = SettingsScene(name: name)
        new.enabled = enabled
        new.cameraType = cameraType
        new.cameraPosition = cameraPosition
        new.backCameraId = backCameraId
        new.frontCameraId = frontCameraId
        new.rtmpCameraId = rtmpCameraId
        new.srtlaCameraId = srtlaCameraId
        new.mediaPlayerCameraId = mediaPlayerCameraId
        new.externalCameraId = externalCameraId
        new.externalCameraName = externalCameraName
        for widget in widgets {
            new.widgets.append(widget.clone())
        }
        new.videoSourceRotation = videoSourceRotation
        return new
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        }
    }
}

class SettingsAutoSceneSwitcherScene: Codable, Identifiable {
    var id: UUID = .init()
    var sceneId: UUID?
    var time: Int = 15
}

class SettingsAutoSceneSwitcher: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = "My switcher"
    var shuffle: Bool = false
    var scenes: [SettingsAutoSceneSwitcherScene] = []

    enum CodingKeys: CodingKey {
        case id, name, shuffle, scenes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.shuffle, shuffle)
        try container.encode(.scenes, scenes)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shuffle = try container.decode(Bool.self, forKey: .shuffle)
        scenes = try container.decode([SettingsAutoSceneSwitcherScene].self, forKey: .scenes)
    }
}

class SettingsAutoSceneSwitchers: Codable, Identifiable, ObservableObject {
    @Published var switcherId: UUID?
    @Published var switchers: [SettingsAutoSceneSwitcher] = []

    enum CodingKeys: CodingKey {
        case switcherId, switchers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.switcherId, switcherId)
        try container.encode(.switchers, switchers)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switcherId = try? container.decode(UUID?.self, forKey: .switcherId)
        switchers = container.decode(.switchers, [SettingsAutoSceneSwitcher].self, [])
    }
}

enum SettingsFontDesign: String, Codable, CaseIterable {
    case `default` = "Default"
    case serif = "Serif"
    case rounded = "Rounded"
    case monospaced = "Monospaced"

    public init(from decoder: Decoder) throws {
        self = try SettingsFontDesign(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .default
    }

    func toString() -> String {
        switch self {
        case .default:
            return String(localized: "Default")
        case .serif:
            return String(localized: "Serif")
        case .rounded:
            return String(localized: "Rounded")
        case .monospaced:
            return String(localized: "Monospaced")
        }
    }

    func toSystem() -> Font.Design {
        switch self {
        case .default:
            return .default
        case .serif:
            return .serif
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        }
    }
}

enum SettingsFontWeight: String, Codable, CaseIterable {
    case regular = "Regular"
    case light = "Light"
    case bold = "Bold"

    public init(from decoder: Decoder) throws {
        self = try SettingsFontWeight(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .regular
    }

    func toString() -> String {
        switch self {
        case .regular:
            return String(localized: "Regular")
        case .light:
            return String(localized: "Light")
        case .bold:
            return String(localized: "Bold")
        }
    }

    func toSystem() -> Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .light:
            return .light
        case .bold:
            return .bold
        }
    }
}

enum SettingsHorizontalAlignment: String, Codable, CaseIterable {
    case leading = "Leading"
    case trailing = "Trailing"

    public init(from decoder: Decoder) throws {
        self = try SettingsHorizontalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .leading
    }

    func toString() -> String {
        switch self {
        case .leading:
            return String(localized: "Leading")
        case .trailing:
            return String(localized: "Trailing")
        }
    }

    func toSystem() -> HorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }
}

enum SettingsVerticalAlignment: String, Codable, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"

    public init(from decoder: Decoder) throws {
        self = try SettingsVerticalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .top
    }

    func toString() -> String {
        switch self {
        case .top:
            return String(localized: "Top")
        case .bottom:
            return String(localized: "Bottom")
        }
    }

    func toSystem() -> VerticalAlignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

class SettingsWidgetTextTimer: Codable, Identifiable {
    var id: UUID = .init()
    var delta: Int = 5
    var endTime: Double = 0
}

class SettingsWidgetTextStopwatch: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var totalElapsed: Double = 0.0
    var playPressedTime: ContinuousClock.Instant = .now
    @Published var running: Bool = false

    enum CodingKeys: CodingKey {
        case id
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
    }

    func clone() -> SettingsWidgetTextStopwatch {
        let new = SettingsWidgetTextStopwatch()
        new.id = id
        new.playPressedTime = playPressedTime
        new.totalElapsed = totalElapsed
        new.running = running
        return new
    }
}

class SettingsWidgetTextCheckbox: Codable, Identifiable {
    var id: UUID = .init()
    var checked: Bool = false
}

class SettingsWidgetTextRating: Codable, Identifiable {
    var id: UUID = .init()
    var rating: Int = 0
}

class SettingsWidgetTextLapTimes: Codable, Identifiable {
    var id: UUID = .init()
    var currentLapStartTime: Double?
    var lapTimes: [Double] = []
}

class SettingsWidgetText: Codable, ObservableObject {
    var formatString: String = "{shortTime}"
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0, opacity: 0.75)
    @Published var backgroundColorColor: Color
    var clearBackgroundColor: Bool = false
    var foregroundColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    @Published var foregroundColorColor: Color
    var clearForegroundColor: Bool = false
    var fontSize: Int = 30
    @Published var fontSizeFloat: Float
    @Published var fontDesign: SettingsFontDesign = .default
    @Published var fontWeight: SettingsFontWeight = .regular
    var fontMonospacedDigits: Bool = false
    @Published var alignment: SettingsHorizontalAlignment = .leading
    @Published var horizontalAlignment: SettingsHorizontalAlignment = .leading
    @Published var verticalAlignment: SettingsVerticalAlignment = .top
    @Published var delay: Double = 0.0
    var timers: [SettingsWidgetTextTimer] = []
    var stopwatches: [SettingsWidgetTextStopwatch] = []
    var needsWeather: Bool = false
    var needsGeography: Bool = false
    var needsSubtitles: Bool = false
    var checkboxes: [SettingsWidgetTextCheckbox] = []
    var ratings: [SettingsWidgetTextRating] = []
    var lapTimes: [SettingsWidgetTextLapTimes] = []
    var needsGForce: Bool = false

    enum CodingKeys: CodingKey {
        case formatString,
             backgroundColor,
             clearBackgroundColor,
             foregroundColor,
             clearForegroundColor,
             fontSize,
             fontDesign,
             fontWeight,
             fontMonospacedDigits,
             alignment,
             horizontalAlignment,
             verticalAlignment,
             delay,
             timers,
             stopwatches,
             needsWeather,
             needsGeography,
             needsSubtitles,
             checkboxes,
             ratings,
             lapTimes,
             needsGForce
    }

    init() {
        backgroundColorColor = backgroundColor.color()
        foregroundColorColor = foregroundColor.color()
        fontSizeFloat = Float(fontSize)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.formatString, formatString)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.clearBackgroundColor, clearBackgroundColor)
        try container.encode(.foregroundColor, foregroundColor)
        try container.encode(.clearForegroundColor, clearForegroundColor)
        try container.encode(.fontSize, fontSize)
        try container.encode(.fontDesign, fontDesign)
        try container.encode(.fontWeight, fontWeight)
        try container.encode(.fontMonospacedDigits, fontMonospacedDigits)
        try container.encode(.alignment, alignment)
        try container.encode(.horizontalAlignment, horizontalAlignment)
        try container.encode(.verticalAlignment, verticalAlignment)
        try container.encode(.delay, delay)
        try container.encode(.timers, timers)
        try container.encode(.stopwatches, stopwatches)
        try container.encode(.needsWeather, needsWeather)
        try container.encode(.needsGeography, needsGeography)
        try container.encode(.needsSubtitles, needsSubtitles)
        try container.encode(.checkboxes, checkboxes)
        try container.encode(.ratings, ratings)
        try container.encode(.lapTimes, lapTimes)
        try container.encode(.needsGForce, needsGForce)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatString = container.decode(.formatString, String.self, "{shortTime}")
        backgroundColor = container.decode(
            .backgroundColor,
            RgbColor.self,
            .init(red: 0, green: 0, blue: 0, opacity: 0.75)
        )
        backgroundColorColor = backgroundColor.color()
        clearBackgroundColor = container.decode(.clearBackgroundColor, Bool.self, false)
        foregroundColor = container.decode(.foregroundColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        foregroundColorColor = foregroundColor.color()
        clearForegroundColor = container.decode(.clearForegroundColor, Bool.self, false)
        fontSize = container.decode(.fontSize, Int.self, 30)
        fontSizeFloat = Float(fontSize)
        fontDesign = container.decode(.fontDesign, SettingsFontDesign.self, .default)
        fontWeight = container.decode(.fontWeight, SettingsFontWeight.self, .regular)
        fontMonospacedDigits = container.decode(.fontMonospacedDigits, Bool.self, false)
        alignment = container.decode(.alignment, SettingsHorizontalAlignment.self, .leading)
        horizontalAlignment = container.decode(.horizontalAlignment, SettingsHorizontalAlignment.self, .leading)
        verticalAlignment = container.decode(.verticalAlignment, SettingsVerticalAlignment.self, .top)
        delay = container.decode(.delay, Double.self, 0.0)
        timers = container.decode(.timers, [SettingsWidgetTextTimer].self, [])
        stopwatches = container.decode(.stopwatches, [SettingsWidgetTextStopwatch].self, [])
        needsWeather = container.decode(.needsWeather, Bool.self, false)
        needsGeography = container.decode(.needsGeography, Bool.self, false)
        needsSubtitles = container.decode(.needsSubtitles, Bool.self, false)
        checkboxes = container.decode(.checkboxes, [SettingsWidgetTextCheckbox].self, [])
        ratings = container.decode(.ratings, [SettingsWidgetTextRating].self, [])
        lapTimes = container.decode(.lapTimes, [SettingsWidgetTextLapTimes].self, [])
        needsGForce = container.decode(.needsGForce, Bool.self, false)
    }
}

class SettingsWidgetCrop: Codable {
    var sourceWidgetId: UUID = .init()
    var x: Int = 0
    var y: Int = 0
    var width: Int = 200
    var height: Int = 200
}

class SettingsWidgetBrowser: Codable, ObservableObject {
    @Published var url: String = ""
    @Published var width: Int = 500
    @Published var height: Int = 500
    @Published var audioOnly: Bool = false
    @Published var scaleToFitVideo: Bool = false
    @Published var fps: Float = 5.0
    @Published var styleSheet: String = ""
    @Published var moblinAccess: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case url,
             width,
             height,
             audioOnly,
             scaleToFitVideo,
             fps,
             styleSheet,
             moblinAccess
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.url, url)
        try container.encode(.width, width)
        try container.encode(.height, height)
        try container.encode(.audioOnly, audioOnly)
        try container.encode(.scaleToFitVideo, scaleToFitVideo)
        try container.encode(.fps, fps)
        try container.encode(.styleSheet, styleSheet)
        try container.encode(.moblinAccess, moblinAccess)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.decode(.url, String.self, "")
        width = container.decode(.width, Int.self, 500)
        height = container.decode(.height, Int.self, 500)
        audioOnly = container.decode(.audioOnly, Bool.self, false)
        scaleToFitVideo = container.decode(.scaleToFitVideo, Bool.self, false)
        fps = container.decode(.fps, Float.self, 5.0)
        styleSheet = container.decode(.styleSheet, String.self, "")
        moblinAccess = container.decode(.moblinAccess, Bool.self, false)
    }
}

class SettingsWidgetMap: Codable {
    // Remove
    var width: Int = 250
    // Remove
    var height: Int = 250
    var migrated: Bool? = false
    var northUp: Bool? = false
    var delay: Double? = 0.0

    func clone() -> SettingsWidgetMap {
        let new = SettingsWidgetMap()
        new.width = width
        new.height = height
        new.migrated = migrated
        new.northUp = northUp
        new.delay = delay
        return new
    }
}

class SettingsWidgetScene: Codable {
    var sceneId: UUID = .init()
}

class SettingsWidgetQrCode: Codable {
    var message = ""
}

enum SettingsWidgetAlertPositionType: String, Codable, CaseIterable {
    case scene = "Scene"
    case face = "Face"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertPositionType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .scene
    }

    func toString() -> String {
        switch self {
        case .scene:
            return String(localized: "Scene")
        case .face:
            return String(localized: "Face")
        }
    }
}

class SettingsWidgetAlertFacePosition: Codable {
    var x: Double = 0.25
    var y: Double = 0.25
    var width: Double = 0.5
    var height: Double = 0.5
}

class SettingsWidgetAlertsAlert: Codable {
    var enabled: Bool = true
    var imageId: UUID = .init()
    var imageLoopCount: Int? = 1
    var soundId: UUID = .init()
    var textColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    var accentColor: RgbColor = .init(red: 0xFD, green: 0xFB, blue: 0x67)
    var fontSize: Int = 45
    var fontDesign: SettingsFontDesign = .monospaced
    var fontWeight: SettingsFontWeight = .bold
    var textToSpeechEnabled: Bool? = true
    var textToSpeechDelay: Double? = 1.5
    var textToSpeechLanguageVoices: [String: String]? = .init()
    var positionType: SettingsWidgetAlertPositionType? = .scene
    var facePosition: SettingsWidgetAlertFacePosition? = .init()

    func isTextToSpeechEnabled() -> Bool {
        return enabled && textToSpeechEnabled!
    }

    func clone() -> SettingsWidgetAlertsAlert {
        let new = SettingsWidgetAlertsAlert()
        new.enabled = enabled
        new.imageId = imageId
        new.imageLoopCount = imageLoopCount
        new.soundId = soundId
        new.textColor = textColor
        new.accentColor = accentColor
        new.fontSize = fontSize
        new.fontDesign = fontDesign
        new.fontWeight = fontWeight
        new.textToSpeechEnabled = textToSpeechEnabled
        new.textToSpeechDelay = textToSpeechDelay
        new.textToSpeechLanguageVoices = textToSpeechLanguageVoices
        new.positionType = positionType
        new.facePosition = facePosition
        return new
    }
}

enum SettingsWidgetAlertsCheerBitsAlertOperator: String, Codable, CaseIterable {
    case equal = "="
    case greaterEqual = ">="

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .equal
    }
}

let twitchCheerBitsAlertOperators = SettingsWidgetAlertsCheerBitsAlertOperator.allCases.map { $0.rawValue }

class SettingsWidgetAlertsCheerBitsAlert: Codable, Identifiable {
    var id: UUID = .init()
    var bits: Int = 1
    var comparisonOperator: SettingsWidgetAlertsCheerBitsAlertOperator = .greaterEqual
    var alert: SettingsWidgetAlertsAlert = .init()

    func clone() -> SettingsWidgetAlertsCheerBitsAlert {
        let new = SettingsWidgetAlertsCheerBitsAlert()
        new.bits = bits
        new.comparisonOperator = comparisonOperator
        new.alert = alert
        return new
    }
}

private func createDefaultCheerBits() -> [SettingsWidgetAlertsCheerBitsAlert] {
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert] = []
    for (index, bits) in [1].enumerated() {
        let cheer = SettingsWidgetAlertsCheerBitsAlert()
        cheer.bits = bits
        cheer.alert.enabled = index == 0
        cheerBits.append(cheer)
    }
    return cheerBits
}

class SettingsWidgetAlertsTwitch: Codable {
    var follows: SettingsWidgetAlertsAlert = .init()
    var subscriptions: SettingsWidgetAlertsAlert = .init()
    var raids: SettingsWidgetAlertsAlert? = .init()
    var cheers: SettingsWidgetAlertsAlert? = .init()
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert]? = createDefaultCheerBits()

    func clone() -> SettingsWidgetAlertsTwitch {
        let new = SettingsWidgetAlertsTwitch()
        new.follows = follows.clone()
        new.subscriptions = subscriptions.clone()
        new.raids = raids!.clone()
        new.cheers = cheers!.clone()
        new.cheerBits = cheerBits!.map { $0.clone() }
        return new
    }
}

enum SettingsWidgetAlertsChatBotCommandImageType: String, Codable, CaseIterable {
    case file = "File"
    case imagePlayground = "Image Playground"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertsChatBotCommandImageType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .file
    }

    func toString() -> String {
        switch self {
        case .file:
            return String(localized: "File")
        case .imagePlayground:
            return String(localized: "Image Playground")
        }
    }
}

class SettingsWidgetAlertsChatBotCommand: Codable, Identifiable, @unchecked Sendable {
    var id: UUID = .init()
    var name: String = "myname"
    var alert: SettingsWidgetAlertsAlert = .init()
    var imageType: SettingsWidgetAlertsChatBotCommandImageType? = .file
    var imagePlaygroundImageId: UUID? = .init()

    func clone() -> SettingsWidgetAlertsChatBotCommand {
        let new = SettingsWidgetAlertsChatBotCommand()
        new.name = name
        new.alert = alert.clone()
        new.imageType = imageType!
        new.imagePlaygroundImageId = imagePlaygroundImageId!
        return new
    }
}

class SettingsWidgetAlertsChatBot: Codable {
    var commands: [SettingsWidgetAlertsChatBotCommand] = []

    func clone() -> SettingsWidgetAlertsChatBot {
        let new = SettingsWidgetAlertsChatBot()
        for command in commands {
            new.commands.append(command.clone())
        }
        return new
    }
}

class SettingsWidgetAlertsSpeechToTextString: Codable, Identifiable {
    var id: UUID = .init()
    var string: String = ""
    var alert: SettingsWidgetAlertsAlert = .init()

    func clone() -> SettingsWidgetAlertsSpeechToTextString {
        let new = SettingsWidgetAlertsSpeechToTextString()
        new.id = id
        new.string = string
        new.alert = alert.clone()
        return new
    }
}

class SettingsWidgetAlertsSpeechToText: Codable {
    var strings: [SettingsWidgetAlertsSpeechToTextString] = []

    func clone() -> SettingsWidgetAlertsSpeechToText {
        let new = SettingsWidgetAlertsSpeechToText()
        for string in strings {
            new.strings.append(string.clone())
        }
        return new
    }
}

class SettingsWidgetAlerts: Codable {
    // To be removed
    // periphery:ignore
    var followVideoId: UUID?
    // periphery:ignore
    var followAudioId: UUID?
    // periphery:ignore
    var followFormatString: String?
    // periphery:ignore
    var subscribeVideoId: UUID?
    // periphery:ignore
    var subscribeAudioId: UUID?
    // periphery:ignore
    var subscribeFormatString: String?
    // periphery:ignore
    var backgroundColor: RgbColor? = .init(red: 0, green: 0, blue: 0, opacity: 0.75)
    // periphery:ignore
    var foregroundColor: RgbColor? = .init(red: 255, green: 255, blue: 255)
    // periphery:ignore
    var fontSize: Int? = 50
    // periphery:ignore
    var fontDesign: SettingsFontDesign? = .default
    // periphery:ignore
    var fontWeight: SettingsFontWeight? = .regular
    var twitch: SettingsWidgetAlertsTwitch? = .init()
    var chatBot: SettingsWidgetAlertsChatBot? = .init()
    var speechToText: SettingsWidgetAlertsSpeechToText? = .init()
    var needsSubtitles: Bool? = false

    func clone() -> SettingsWidgetAlerts {
        let new = SettingsWidgetAlerts()
        new.twitch = twitch!.clone()
        new.chatBot = chatBot!.clone()
        new.speechToText = speechToText!.clone()
        new.needsSubtitles = needsSubtitles
        return new
    }
}

class SettingsWidgetVideoSource: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0
    var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    var backCameraId: String = getBestBackCameraId()
    var frontCameraId: String = getBestFrontCameraId()
    var rtmpCameraId: UUID = .init()
    var srtlaCameraId: UUID = .init()
    var mediaPlayerCameraId: UUID = .init()
    var externalCameraId: String = ""
    var externalCameraName: String = ""
    var cropEnabled: Bool = false
    var cropX: Double = 0.25
    var cropY: Double = 0.0
    var cropWidth: Double = 0.5
    var cropHeight: Double = 1.0
    @Published var rotation: Double = 0.0
    var trackFaceEnabled: Bool = false
    @Published var trackFaceZoom: Double = 0.75
    var mirror: Bool = false
    @Published var borderWidth: Double = 0
    var borderColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var borderColorColor: Color

    enum CodingKeys: CodingKey {
        case cornerRadius,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             cropEnabled,
             cropX,
             cropY,
             cropWidth,
             cropHeight,
             rotation,
             trackFaceEnabled,
             trackFaceZoom,
             mirror,
             borderWidth,
             borderColor
    }

    init() {
        borderColorColor = borderColor.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.cornerRadius, cornerRadius)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.cropEnabled, cropEnabled)
        try container.encode(.cropX, cropX)
        try container.encode(.cropY, cropY)
        try container.encode(.cropWidth, cropWidth)
        try container.encode(.cropHeight, cropHeight)
        try container.encode(.rotation, rotation)
        try container.encode(.trackFaceEnabled, trackFaceEnabled)
        try container.encode(.trackFaceZoom, trackFaceZoom)
        try container.encode(.mirror, mirror)
        try container.encode(.borderWidth, borderWidth)
        try container.encode(.borderColor, borderColor)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = container.decode(.cornerRadius, Float.self, 0)
        cameraPosition = container.decode(.cameraPosition, SettingsSceneCameraPosition.self, .screenCapture)
        backCameraId = container.decode(.backCameraId, String.self, getBestBackCameraId())
        frontCameraId = container.decode(.frontCameraId, String.self, getBestFrontCameraId())
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        cropEnabled = container.decode(.cropEnabled, Bool.self, false)
        cropX = container.decode(.cropX, Double.self, 0.25)
        cropY = container.decode(.cropY, Double.self, 0.0)
        cropWidth = container.decode(.cropWidth, Double.self, 0.5)
        cropHeight = container.decode(.cropHeight, Double.self, 1.0)
        rotation = container.decode(.rotation, Double.self, 0.0)
        trackFaceEnabled = container.decode(.trackFaceEnabled, Bool.self, false)
        trackFaceZoom = container.decode(.trackFaceZoom, Double.self, 0.75)
        mirror = container.decode(.mirror, Bool.self, false)
        borderWidth = container.decode(.borderWidth, Double.self, 0)
        borderColor = container.decode(.borderColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        borderColorColor = borderColor.color()
    }

    func toEffectSettings() -> VideoSourceEffectSettings {
        return .init(cornerRadius: cornerRadius,
                     cropEnabled: cropEnabled,
                     cropX: cropX,
                     cropY: cropY,
                     cropWidth: cropWidth,
                     cropHeight: cropHeight,
                     rotation: rotation,
                     trackFaceEnabled: trackFaceEnabled,
                     trackFaceZoom: 1.5 + (1 - trackFaceZoom) * 4,
                     mirror: mirror,
                     borderWidth: borderWidth,
                     borderColor: CIColor(
                         red: Double(borderColor.red) / 255,
                         green: Double(borderColor.green) / 255,
                         blue: Double(borderColor.blue) / 255
                     ))
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        }
    }
}

enum SettingsWidgetScoreboardType: String, Codable, CaseIterable {
    case padel = "Padel"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetScoreboardType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .padel
    }

    func toString() -> String {
        switch self {
        case .padel:
            return String(localized: "Padel")
        }
    }
}

class SettingsWidgetScoreboardPlayer: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "🇸🇪 Moblin"
}

class SettingsWidgetScoreboardScore: Codable, Identifiable {
    var home: Int = 0
    var away: Int = 0
}

enum SettingsWidgetPadelScoreboardGameType: String, Codable, CaseIterable {
    case doubles = "Double"
    case singles = "Single"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetPadelScoreboardGameType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .doubles
    }

    func toString() -> String {
        switch self {
        case .doubles:
            return String(localized: "Doubles")
        case .singles:
            return String(localized: "Singles")
        }
    }
}

class SettingsWidgetPadelScoreboard: Codable {
    var type: SettingsWidgetPadelScoreboardGameType = .doubles
    var homePlayer1: UUID = .init()
    var homePlayer2: UUID = .init()
    var awayPlayer1: UUID = .init()
    var awayPlayer2: UUID = .init()
    var score: [SettingsWidgetScoreboardScore] = [.init()]
}

class SettingsWidgetScoreboard: Codable {
    var type: SettingsWidgetScoreboardType = .padel
    var padel: SettingsWidgetPadelScoreboard = .init()
}

enum SettingsWidgetVideoEffectType: String, Codable, CaseIterable {
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case bloom = "Bloom"
    case random = "Random"
    case triple = "Triple"
    case noiseReduction = "Noise reduction"
    case pixellate = "Pixellate"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetVideoEffectType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .movie
    }
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case browser = "Browser"
    case image = "Image"
    case text = "Text"
    case videoEffect = "Video effect"
    case crop = "Crop"
    case map = "Map"
    case scene = "Scene"
    case qrCode = "QR code"
    case alerts = "Alerts"
    case videoSource = "Video source"
    case scoreboard = "Scoreboard"
    case vTuber = "VTuber"
    case pngTuber = "PNGTuber"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .text
    }

    func toString() -> String {
        switch self {
        case .browser:
            return String(localized: "Browser")
        case .image:
            return String(localized: "Image")
        case .text:
            return String(localized: "Text")
        case .videoEffect:
            return String(localized: "Video effect")
        case .crop:
            return String(localized: "Crop")
        case .map:
            return String(localized: "Map")
        case .scene:
            return String(localized: "Scene")
        case .qrCode:
            return String(localized: "QR code")
        case .alerts:
            return String(localized: "Alerts")
        case .videoSource:
            return String(localized: "Video source")
        case .scoreboard:
            return String(localized: "Scoreboard")
        case .vTuber:
            return String(localized: "VTuber")
        case .pngTuber:
            return String(localized: "PNGTuber")
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases.filter { $0 != .videoEffect }

enum SettingsVideoEffectType: String, Codable, CaseIterable {
    case grayScale
    case sepia
    case whirlpool
    case pinch
    case removeBackground
    case shape

    public init(from decoder: Decoder) throws {
        do {
            self = try SettingsVideoEffectType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .grayScale
        } catch {
            self = .grayScale
        }
    }

    func toString() -> String {
        switch self {
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .whirlpool:
            return String(localized: "Whirlpool")
        case .pinch:
            return String(localized: "Pinch")
        case .removeBackground:
            return String(localized: "Remove background")
        case .shape:
            return String(localized: "Shape")
        }
    }
}

private let defaultFromColor = RgbColor(red: 220, green: 235, blue: 92)
private let defaultToColor = RgbColor(red: 82, green: 180, blue: 203)

class SettingsVideoEffectRemoveBackground: Codable, ObservableObject {
    var from: RgbColor = defaultFromColor
    @Published var fromColor: Color
    var to: RgbColor = defaultToColor
    @Published var toColor: Color

    enum CodingKeys: CodingKey {
        case from,
             to
    }

    init() {
        fromColor = from.color()
        toColor = to.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.from, from)
        try container.encode(.to, to)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = container.decode(.from, RgbColor.self, defaultFromColor)
        fromColor = from.color()
        to = container.decode(.to, RgbColor.self, defaultToColor)
        toColor = to.color()
    }
}

class SettingsVideoEffectShape: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0
    @Published var borderWidth: Double = 0
    var borderColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var borderColorColor: Color

    enum CodingKeys: CodingKey {
        case cornerRadius,
             borderWidth,
             borderColor
    }

    init() {
        borderColorColor = borderColor.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.cornerRadius, cornerRadius)
        try container.encode(.borderWidth, borderWidth)
        try container.encode(.borderColor, borderColor)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = container.decode(.cornerRadius, Float.self, 0)
        borderWidth = container.decode(.borderWidth, Double.self, 0)
        borderColor = container.decode(.borderColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        borderColorColor = borderColor.color()
    }

    func toSettings() -> ShapeEffectSettings {
        return .init(cornerRadius: cornerRadius,
                     borderWidth: borderWidth,
                     borderColor: CIColor(
                         red: Double(borderColor.red) / 255,
                         green: Double(borderColor.green) / 255,
                         blue: Double(borderColor.blue) / 255
                     ))
    }
}

class SettingsVideoEffect: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var type: SettingsVideoEffectType = .grayScale
    var removeBackground: SettingsVideoEffectRemoveBackground = .init()
    var shape: SettingsVideoEffectShape = .init()

    enum CodingKeys: CodingKey {
        case id,
             enabled,
             type,
             removeBackground,
             shape
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.type, type)
        try container.encode(.removeBackground, removeBackground)
        try container.encode(.shape, shape)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        type = container.decode(.type, SettingsVideoEffectType.self, .grayScale)
        removeBackground = container.decode(.removeBackground, SettingsVideoEffectRemoveBackground.self, .init())
        shape = container.decode(.shape, SettingsVideoEffectShape.self, .init())
    }

    func getEffect() -> VideoEffect {
        switch type {
        case .grayScale:
            return GrayScaleEffect()
        case .sepia:
            return SepiaEffect()
        case .whirlpool:
            return WhirlpoolEffect(angle: .pi / 2)
        case .pinch:
            return PinchEffect(scale: 0.5)
        case .removeBackground:
            let effect = RemoveBackgroundEffect()
            effect.setColorRange(from: removeBackground.from, to: removeBackground.to)
            return effect
        case .shape:
            let effect = ShapeEffect()
            effect.setSettings(settings: shape.toSettings())
            return effect
        }
    }
}

class SettingsWidgetVTuber: Codable, ObservableObject {
    var id: UUID = .init()
    var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    var backCameraId: String = getBestBackCameraId()
    var frontCameraId: String = getBestFrontCameraId()
    var rtmpCameraId: UUID = .init()
    var srtlaCameraId: UUID = .init()
    var mediaPlayerCameraId: UUID = .init()
    var externalCameraId: String = ""
    var externalCameraName: String = ""
    @Published var cameraPositionY: Double = 1.37
    @Published var cameraFieldOfView: Double = 18
    @Published var modelName: String = ""
    @Published var mirror: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             cameraPositionY,
             cameraFieldOfView,
             modelName,
             mirror
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.cameraPositionY, cameraPositionY)
        try container.encode(.cameraFieldOfView, cameraFieldOfView)
        try container.encode(.modelName, modelName)
        try container.encode(.mirror, mirror)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        cameraPosition = container.decode(.cameraPosition, SettingsSceneCameraPosition.self, .screenCapture)
        backCameraId = container.decode(.backCameraId, String.self, getBestBackCameraId())
        frontCameraId = container.decode(.frontCameraId, String.self, getBestFrontCameraId())
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        cameraPositionY = container.decode(.cameraPositionY, Double.self, 1.37)
        cameraFieldOfView = container.decode(.cameraFieldOfView, Double.self, 18)
        modelName = container.decode(.modelName, String.self, "")
        mirror = container.decode(.mirror, Bool.self, false)
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        }
    }
}

class SettingsWidgetPngTuber: Codable, ObservableObject {
    var id: UUID = .init()
    var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    var backCameraId: String = getBestBackCameraId()
    var frontCameraId: String = getBestFrontCameraId()
    var rtmpCameraId: UUID = .init()
    var srtlaCameraId: UUID = .init()
    var mediaPlayerCameraId: UUID = .init()
    var externalCameraId: String = ""
    var externalCameraName: String = ""
    @Published var modelName: String = ""
    @Published var mirror: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             modelName,
             mirror
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.modelName, modelName)
        try container.encode(.mirror, mirror)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        cameraPosition = container.decode(.cameraPosition, SettingsSceneCameraPosition.self, .screenCapture)
        backCameraId = container.decode(.backCameraId, String.self, getBestBackCameraId())
        frontCameraId = container.decode(.frontCameraId, String.self, getBestFrontCameraId())
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        modelName = container.decode(.modelName, String.self, "")
        mirror = container.decode(.mirror, Bool.self, false)
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        }
    }
}

class SettingsWidget: Codable, Identifiable, Equatable, ObservableObject {
    @Published var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .browser
    var text: SettingsWidgetText = .init()
    var browser: SettingsWidgetBrowser = .init()
    var crop: SettingsWidgetCrop = .init()
    var map: SettingsWidgetMap = .init()
    var scene: SettingsWidgetScene = .init()
    var qrCode: SettingsWidgetQrCode = .init()
    var alerts: SettingsWidgetAlerts = .init()
    var videoSource: SettingsWidgetVideoSource = .init()
    var scoreboard: SettingsWidgetScoreboard = .init()
    var vTuber: SettingsWidgetVTuber = .init()
    var pngTuber: SettingsWidgetPngTuber = .init()
    @Published var enabled: Bool = true
    @Published var effects: [SettingsVideoEffect] = []

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsWidget, rhs: SettingsWidget) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             type,
             text,
             browser,
             crop,
             map,
             scene,
             qrCode,
             alerts,
             videoSource,
             scoreboard,
             vTuber,
             pngTuber,
             enabled,
             effects
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.text, text)
        try container.encode(.browser, browser)
        try container.encode(.crop, crop)
        try container.encode(.map, map)
        try container.encode(.scene, scene)
        try container.encode(.qrCode, qrCode)
        try container.encode(.alerts, alerts)
        try container.encode(.videoSource, videoSource)
        try container.encode(.scoreboard, scoreboard)
        try container.encode(.vTuber, vTuber)
        try container.encode(.pngTuber, pngTuber)
        try container.encode(.enabled, enabled)
        try container.encode(.effects, effects)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(SettingsWidgetType.self, forKey: .type)
        text = try container.decode(SettingsWidgetText.self, forKey: .text)
        browser = try container.decode(SettingsWidgetBrowser.self, forKey: .browser)
        crop = container.decode(.crop, SettingsWidgetCrop.self, .init())
        map = container.decode(.map, SettingsWidgetMap.self, .init())
        scene = container.decode(.scene, SettingsWidgetScene.self, .init())
        qrCode = container.decode(.qrCode, SettingsWidgetQrCode.self, .init())
        alerts = container.decode(.alerts, SettingsWidgetAlerts.self, .init())
        videoSource = container.decode(.videoSource, SettingsWidgetVideoSource.self, .init())
        scoreboard = container.decode(.scoreboard, SettingsWidgetScoreboard.self, .init())
        vTuber = container.decode(.vTuber, SettingsWidgetVTuber.self, .init())
        pngTuber = container.decode(.pngTuber, SettingsWidgetPngTuber.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        effects = container.decode(.effects, [SettingsVideoEffect].self, [])
    }

    func getEffects() -> [VideoEffect] {
        return effects.filter { $0.enabled }.map { $0.getEffect() }
    }
}

enum SettingsQuickButtonType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case widget = "Widget"
    case mic = "Mic"
    case chat = "Chat"
    case blackScreen = "Black screen"
    case record = "Record"
    case recordings = "Recrodings"
    case image = "Image"
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case triple = "Triple"
    case twin = "Twin"
    case pixellate = "Pixellate"
    case stream = "Stream"
    case grid = "Grid"
    case obs = "OBS"
    case remote = "Remote"
    case draw = "Draw"
    case localOverlays = "Local overlays"
    case browser = "Browser"
    case lut = "LUT"
    case cameraPreview = "Camera preview"
    case face = "Face"
    case fourThree = "4:3"
    case poll = "Poll"
    case snapshot = "Snapshot"
    case widgets = "Widgets"
    case luts = "LUTs"
    case workout = "Workout"
    case ads = "Ads"
    case skipCurrentTts = "Skip current TTS"
    case streamMarker = "Stream marker"
    case reloadBrowserWidgets = "Reload browser widgets"
    case interactiveChat = "Interactive chat"
    case lockScreen = "Lock screen"
    case djiDevices = "DJI devices"
    case portrait = "Portrait"
    case goPro = "GoPro"
    case replay = "Replay"
    case connectionPriorities = "Connection priorities"
    case instantReplay = "Instant replay"
    case pinch = "Pinch"
    case whirlpool = "Whirlpool"
    case autoSceneSwitcher = "Auto scene switcher"
    case pauseTts = "Pause TTS"

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Chat"
        }
        self = SettingsQuickButtonType(rawValue: value) ?? .unknown
    }
}

class SettingsQuickButton: Codable, Identifiable, Equatable, Hashable, ObservableObject {
    var name: String
    var id: UUID = .init()
    var type: SettingsQuickButtonType = .widget
    // periphery:ignore
    var imageType: String? = "System name"
    var systemImageNameOn: String = "mic.slash"
    var systemImageNameOff: String = "mic"
    var isOn: Bool = false
    @Published var enabled: Bool = true
    var backgroundColor: RgbColor = defaultQuickButtonColor
    @Published var color: Color = defaultQuickButtonColor.color()
    @Published var page: Int? = 1

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsQuickButton, rhs: SettingsQuickButton) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             type,
             imageType,
             systemImageNameOn,
             systemImageNameOff,
             isOn,
             enabled,
             backgroundColor,
             page
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.imageType, imageType)
        try container.encode(.systemImageNameOn, systemImageNameOn)
        try container.encode(.systemImageNameOff, systemImageNameOff)
        try container.encode(.isOn, isOn)
        try container.encode(.enabled, enabled)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.page, page)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsQuickButtonType.self, .widget)
        imageType = try? container.decode(String?.self, forKey: .imageType)
        systemImageNameOn = container.decode(.systemImageNameOn, String.self, "mic.slash")
        systemImageNameOff = container.decode(.systemImageNameOff, String.self, "mic")
        isOn = container.decode(.isOn, Bool.self, false)
        enabled = container.decode(.enabled, Bool.self, true)
        backgroundColor = container.decode(.backgroundColor, RgbColor.self, defaultQuickButtonColor)
        color = backgroundColor.color()
        page = try? container.decode(Int?.self, forKey: .page)
    }
}

enum SettingsColorLutType: String, Codable {
    case bundled
    case disk
    case diskCube

    public init(from decoder: Decoder) throws {
        do {
            self = try SettingsColorLutType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .bundled
        } catch {
            self = .bundled
        }
    }
}

class SettingsColorLut: Codable, Identifiable {
    var id: UUID = .init()
    var type: SettingsColorLutType = .bundled
    var name: String = ""
    var enabled: Bool? = false
    // Remove at some point.
    var buttonId: UUID?

    init(type: SettingsColorLutType, name: String) {
        self.type = type
        self.name = name
    }

    func clone() -> SettingsColorLut {
        let new = SettingsColorLut(type: type, name: name)
        new.id = id
        new.enabled = enabled
        return new
    }
}

enum SettingsColorSpace: String, Codable, CaseIterable {
    case srgb = "Standard RGB"
    case p3D65 = "P3 D65"
    case hlgBt2020 = "HLG BT2020"
    case appleLog = "Apple Log"

    public init(from decoder: Decoder) throws {
        self = try SettingsColorSpace(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .srgb
    }
}

let colorSpaces = SettingsColorSpace.allCases.map { $0.rawValue }

private let allBundledLuts = [
    SettingsColorLut(type: .bundled, name: "Apple Log To Rec 709"),
    SettingsColorLut(type: .bundled, name: "Moblin Meme"),
]

class SettingsColor: Codable {
    var space: SettingsColorSpace = .srgb
    var lutEnabled: Bool = true
    var lut: UUID = .init()
    var bundledLuts = allBundledLuts
    var diskLuts: [SettingsColorLut]? = []
    var diskLutsPng: [SettingsColorLut]? = []
    var diskLutsCube: [SettingsColorLut]? = []
}

class SettingsShow: Codable, ObservableObject {
    @Published var chat: Bool = true
    @Published var viewers: Bool = true
    @Published var uptime: Bool = true
    @Published var stream: Bool = false
    @Published var speed: Bool = true
    @Published var audioLevel: Bool = true
    @Published var zoom: Bool = false
    @Published var zoomPresets: Bool = true
    @Published var microphone: Bool = false
    @Published var audioBar: Bool = true
    @Published var cameras: Bool = false
    @Published var obsStatus: Bool = true
    @Published var rtmpSpeed: Bool = true
    @Published var gameController: Bool = true
    @Published var location: Bool = true
    @Published var remoteControl: Bool = true
    @Published var browserWidgets: Bool = true
    @Published var bonding: Bool = true
    @Published var events: Bool = true
    @Published var djiDevices: Bool = true
    @Published var bondingRtts: Bool = false
    @Published var moblink: Bool = true
    @Published var catPrinter: Bool = true
    @Published var cyclingPowerDevice: Bool = true
    @Published var heartRateDevice: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case chat,
             viewers,
             uptime,
             stream,
             speed,
             audioLevel,
             zoom,
             zoomPresets,
             microphone,
             audioBar,
             cameras,
             obsStatus,
             rtmpSpeed,
             gameController,
             location,
             remoteControl,
             browserWidgets,
             bonding,
             events,
             djiDevices,
             bondingRtts,
             moblink,
             catPrinter,
             cyclingPowerDevice,
             heartRateDevice
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.chat, chat)
        try container.encode(.viewers, viewers)
        try container.encode(.uptime, uptime)
        try container.encode(.stream, stream)
        try container.encode(.speed, speed)
        try container.encode(.audioLevel, audioLevel)
        try container.encode(.zoom, zoom)
        try container.encode(.zoomPresets, zoomPresets)
        try container.encode(.microphone, microphone)
        try container.encode(.audioBar, audioBar)
        try container.encode(.cameras, cameras)
        try container.encode(.obsStatus, obsStatus)
        try container.encode(.rtmpSpeed, rtmpSpeed)
        try container.encode(.gameController, gameController)
        try container.encode(.location, location)
        try container.encode(.remoteControl, remoteControl)
        try container.encode(.browserWidgets, browserWidgets)
        try container.encode(.bonding, bonding)
        try container.encode(.events, events)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.bondingRtts, bondingRtts)
        try container.encode(.moblink, moblink)
        try container.encode(.catPrinter, catPrinter)
        try container.encode(.cyclingPowerDevice, cyclingPowerDevice)
        try container.encode(.heartRateDevice, heartRateDevice)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chat = container.decode(.chat, Bool.self, true)
        viewers = container.decode(.viewers, Bool.self, true)
        uptime = container.decode(.uptime, Bool.self, true)
        stream = container.decode(.stream, Bool.self, false)
        speed = container.decode(.speed, Bool.self, true)
        audioLevel = container.decode(.audioLevel, Bool.self, true)
        zoom = container.decode(.zoom, Bool.self, false)
        zoomPresets = container.decode(.zoomPresets, Bool.self, true)
        microphone = container.decode(.microphone, Bool.self, false)
        audioBar = container.decode(.audioBar, Bool.self, true)
        cameras = container.decode(.cameras, Bool.self, false)
        obsStatus = container.decode(.obsStatus, Bool.self, true)
        rtmpSpeed = container.decode(.rtmpSpeed, Bool.self, true)
        gameController = container.decode(.gameController, Bool.self, true)
        location = container.decode(.location, Bool.self, true)
        remoteControl = container.decode(.remoteControl, Bool.self, true)
        browserWidgets = container.decode(.browserWidgets, Bool.self, true)
        bonding = container.decode(.bonding, Bool.self, true)
        events = container.decode(.events, Bool.self, true)
        djiDevices = container.decode(.djiDevices, Bool.self, true)
        bondingRtts = container.decode(.bondingRtts, Bool.self, false)
        moblink = container.decode(.moblink, Bool.self, true)
        catPrinter = container.decode(.catPrinter, Bool.self, true)
        cyclingPowerDevice = container.decode(.cyclingPowerDevice, Bool.self, true)
        heartRateDevice = container.decode(.heartRateDevice, Bool.self, true)
    }
}

class SettingsZoomPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String = ""
    var level: Float = 1.0
    var x: Float? = 1.0

    init(id: UUID, name: String, level: Float, x: Float) {
        self.id = id
        self.name = name
        self.level = level
        self.x = x
    }

    static func == (lhs: SettingsZoomPreset, rhs: SettingsZoomPreset) -> Bool {
        return lhs.id == rhs.id
    }
}

class SettingsZoomSwitchTo: Codable {
    var level: Float = 1.0
    var x: Float? = 1.0
    var enabled: Bool = false
}

class SettingsZoom: Codable {
    var back: [SettingsZoomPreset] = []
    var front: [SettingsZoomPreset] = []
    var switchToBack: SettingsZoomSwitchTo = .init()
    var switchToFront: SettingsZoomSwitchTo = .init()
    var speed: Float? = 5.0
}

class SettingsBitratePreset: Codable, Identifiable, ObservableObject {
    var id: UUID
    @Published var bitrate: UInt32 = 5_000_000

    init(id: UUID, bitrate: UInt32) {
        self.id = id
        self.bitrate = bitrate
    }

    enum CodingKeys: CodingKey {
        case id,
             bitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.bitrate, bitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
    }
}

enum SettingsVideoStabilizationMode: String, Codable, CaseIterable {
    case off = "Off"
    case standard = "Standard"
    case cinematic = "Cinematic"
    case cinematicExtendedEnhanced = "Cinematic extended enhanced"

    public init(from decoder: Decoder) throws {
        self = try SettingsVideoStabilizationMode(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .off
    }

    func toString() -> String {
        switch self {
        case .off:
            return String(localized: "Off")
        case .standard:
            return String(localized: "Standard")
        case .cinematic:
            return String(localized: "Cinematic")
        case .cinematicExtendedEnhanced:
            return String(localized: "Cinematic extended enhanced")
        }
    }
}

var videoStabilizationModes = SettingsVideoStabilizationMode.allCases
    .filter {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return $0 != .cinematicExtendedEnhanced
        }
    }

class SettingsChatFilter: Identifiable, Codable, ObservableObject {
    var id = UUID()
    @Published var user: String = ""
    @Published var messageStart: String = ""
    var messageStartWords: [String] = []
    @Published var showOnScreen: Bool = false
    @Published var textToSpeech: Bool = false
    @Published var chatBot: Bool = false
    @Published var poll: Bool = false
    @Published var print: Bool = false

    func isMatching(user: String?, segments: [ChatPostSegment]) -> Bool {
        if user != self.user {
            return false
        }
        var segmentsIterator = segments.makeIterator()
        for messageWord in messageStartWords {
            if let text = firstText(segmentsIterator: &segmentsIterator) {
                if !text.starts(with: messageWord) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

    private func firstText(segmentsIterator: inout IndexingIterator<[ChatPostSegment]>) -> String? {
        while let segment = segmentsIterator.next() {
            if let text = segment.text, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    enum CodingKeys: CodingKey {
        case id,
             value,
             messageWords,
             showOnScreen,
             textToSpeech,
             chatBot,
             poll,
             print
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.value, user)
        try container.encode(.messageWords, messageStartWords)
        try container.encode(.showOnScreen, showOnScreen)
        try container.encode(.textToSpeech, textToSpeech)
        try container.encode(.chatBot, chatBot)
        try container.encode(.poll, poll)
        try container.encode(.print, print)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        user = container.decode(.value, String.self, "")
        messageStartWords = container.decode(.messageWords, [String].self, [])
        messageStart = messageStartWords.joined(separator: " ")
        showOnScreen = container.decode(.showOnScreen, Bool.self, false)
        textToSpeech = container.decode(.textToSpeech, Bool.self, false)
        chatBot = container.decode(.chatBot, Bool.self, false)
        poll = container.decode(.poll, Bool.self, false)
        print = container.decode(.print, Bool.self, false)
    }
}

class SettingsChatBotPermissionsCommand: Codable {
    var moderatorsEnabled: Bool = true
    var subscribersEnabled: Bool? = false
    var minimumSubscriberTier: Int? = 1
    var othersEnabled: Bool = false
    var sendChatMessages: Bool? = false
}

class SettingsChatBotPermissions: Codable {
    var tts: SettingsChatBotPermissionsCommand = .init()
    var fix: SettingsChatBotPermissionsCommand = .init()
    var map: SettingsChatBotPermissionsCommand = .init()
    var alert: SettingsChatBotPermissionsCommand? = .init()
    var fax: SettingsChatBotPermissionsCommand? = .init()
    var snapshot: SettingsChatBotPermissionsCommand? = .init()
    var filter: SettingsChatBotPermissionsCommand? = .init()
    var tesla: SettingsChatBotPermissionsCommand? = .init()
    var audio: SettingsChatBotPermissionsCommand? = .init()
    var reaction: SettingsChatBotPermissionsCommand? = .init()
    var scene: SettingsChatBotPermissionsCommand? = .init()
    var stream: SettingsChatBotPermissionsCommand? = .init()
}

class SettingsChat: Codable, ObservableObject {
    @Published var fontSize: Float = 19.0
    var usernameColor: RgbColor = .init(red: 255, green: 163, blue: 0)
    @Published var usernameColorColor: Color = RgbColor(red: 255, green: 163, blue: 0).color()
    var messageColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    @Published var messageColorColor: Color = RgbColor(red: 255, green: 255, blue: 255).color()
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var backgroundColorColor: Color = RgbColor(red: 0, green: 0, blue: 0).color()
    @Published var backgroundColorEnabled: Bool = false
    var shadowColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var shadowColorColor: Color = RgbColor(red: 0, green: 0, blue: 0).color()
    @Published var shadowColorEnabled: Bool = true
    @Published var boldUsername: Bool = true
    @Published var boldMessage: Bool = true
    @Published var animatedEmotes: Bool = false
    var timestampColor: RgbColor = .init(red: 180, green: 180, blue: 180)
    @Published var timestampColorColor: Color = RgbColor(red: 180, green: 180, blue: 180).color()
    @Published var timestampColorEnabled: Bool = false
    @Published var height: Double = 0.7
    @Published var width: Double = 1.0
    @Published var maximumAge: Int = 30
    var maximumAgeEnabled: Bool = false
    var meInUsernameColor: Bool = true
    var enabled: Bool = true
    @Published var filters: [SettingsChatFilter] = []
    var textToSpeechEnabled: Bool = false
    var textToSpeechDetectLanguagePerMessage: Bool = false
    var textToSpeechSayUsername: Bool = true
    @Published var textToSpeechRate: Float = 0.4
    @Published var textToSpeechSayVolume: Float = 0.6
    var textToSpeechLanguageVoices: [String: String] = .init()
    var textToSpeechSubscribersOnly: Bool = false
    var textToSpeechFilter: Bool = true
    var textToSpeechFilterMentions: Bool = true
    @Published var mirrored: Bool = false
    @Published var botEnabled: Bool = false
    var botCommandPermissions: SettingsChatBotPermissions = .init()
    var botSendLowBatteryWarning: Bool = false
    @Published var badges: Bool = true
    var showFirstTimeChatterMessage: Bool = true
    var showNewFollowerMessage: Bool = true
    @Published var bottom: Double = 0.0
    @Published var bottomPoints: Double = 80
    @Published var newMessagesAtTop: Bool = false
    @Published var textToSpeechPauseBetweenMessages: Double = 1.0
    @Published var platform: Bool = true
    @Published var showDeletedMessages: Bool = false

    enum CodingKeys: CodingKey {
        case fontSize,
             usernameColor,
             messageColor,
             backgroundColor,
             backgroundColorEnabled,
             shadowColor,
             shadowColorEnabled,
             boldUsername,
             boldMessage,
             animatedEmotes,
             timestampColor,
             timestampColorEnabled,
             height,
             width,
             maximumAge,
             maximumAgeEnabled,
             meInUsernameColor,
             enabled,
             usernamesToIgnore,
             textToSpeechEnabled,
             textToSpeechDetectLanguagePerMessage,
             textToSpeechSayUsername,
             textToSpeechRate,
             textToSpeechSayVolume,
             textToSpeechLanguageVoices,
             textToSpeechSubscribersOnly,
             textToSpeechFilter,
             textToSpeechFilterMentions,
             mirrored,
             botEnabled,
             botCommandPermissions,
             botSendLowBatteryWarning,
             badges,
             showFirstTimeChatterMessage,
             showNewFollowerMessage,
             bottom,
             bottomPoints,
             newMessagesAtTop,
             textToSpeechPauseBetweenMessages,
             platform,
             showDeletedMessages
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.fontSize, fontSize)
        try container.encode(.usernameColor, usernameColor)
        try container.encode(.messageColor, messageColor)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.backgroundColorEnabled, backgroundColorEnabled)
        try container.encode(.shadowColor, shadowColor)
        try container.encode(.shadowColorEnabled, shadowColorEnabled)
        try container.encode(.boldUsername, boldUsername)
        try container.encode(.boldMessage, boldMessage)
        try container.encode(.animatedEmotes, animatedEmotes)
        try container.encode(.timestampColor, timestampColor)
        try container.encode(.timestampColorEnabled, timestampColorEnabled)
        try container.encode(.height, height)
        try container.encode(.width, width)
        try container.encode(.maximumAge, maximumAge)
        try container.encode(.maximumAgeEnabled, maximumAgeEnabled)
        try container.encode(.meInUsernameColor, meInUsernameColor)
        try container.encode(.enabled, enabled)
        try container.encode(.usernamesToIgnore, filters)
        try container.encode(.textToSpeechEnabled, textToSpeechEnabled)
        try container.encode(.textToSpeechDetectLanguagePerMessage, textToSpeechDetectLanguagePerMessage)
        try container.encode(.textToSpeechSayUsername, textToSpeechSayUsername)
        try container.encode(.textToSpeechRate, textToSpeechRate)
        try container.encode(.textToSpeechSayVolume, textToSpeechSayVolume)
        try container.encode(.textToSpeechLanguageVoices, textToSpeechLanguageVoices)
        try container.encode(.textToSpeechSubscribersOnly, textToSpeechSubscribersOnly)
        try container.encode(.textToSpeechFilter, textToSpeechFilter)
        try container.encode(.textToSpeechFilterMentions, textToSpeechFilterMentions)
        try container.encode(.mirrored, mirrored)
        try container.encode(.botEnabled, botEnabled)
        try container.encode(.botCommandPermissions, botCommandPermissions)
        try container.encode(.botSendLowBatteryWarning, botSendLowBatteryWarning)
        try container.encode(.badges, badges)
        try container.encode(.showFirstTimeChatterMessage, showFirstTimeChatterMessage)
        try container.encode(.showNewFollowerMessage, showNewFollowerMessage)
        try container.encode(.bottom, bottom)
        try container.encode(.bottomPoints, bottomPoints)
        try container.encode(.newMessagesAtTop, newMessagesAtTop)
        try container.encode(.textToSpeechPauseBetweenMessages, textToSpeechPauseBetweenMessages)
        try container.encode(.platform, platform)
        try container.encode(.showDeletedMessages, showDeletedMessages)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decode(Float.self, forKey: .fontSize)
        usernameColor = try container.decode(RgbColor.self, forKey: .usernameColor)
        usernameColorColor = usernameColor.color()
        messageColor = try container.decode(RgbColor.self, forKey: .messageColor)
        messageColorColor = messageColor.color()
        backgroundColor = try container.decode(RgbColor.self, forKey: .backgroundColor)
        backgroundColorColor = backgroundColor.color()
        backgroundColorEnabled = try container.decode(Bool.self, forKey: .backgroundColorEnabled)
        shadowColor = try container.decode(RgbColor.self, forKey: .shadowColor)
        shadowColorColor = shadowColor.color()
        shadowColorEnabled = try container.decode(Bool.self, forKey: .shadowColorEnabled)
        boldUsername = try container.decode(Bool.self, forKey: .boldUsername)
        boldMessage = try container.decode(Bool.self, forKey: .boldMessage)
        animatedEmotes = try container.decode(Bool.self, forKey: .animatedEmotes)
        timestampColor = try container.decode(RgbColor.self, forKey: .timestampColor)
        timestampColorColor = timestampColor.color()
        timestampColorEnabled = try container.decode(Bool.self, forKey: .timestampColorEnabled)
        height = container.decode(.height, Double.self, 0.7)
        width = container.decode(.width, Double.self, 1.0)
        maximumAge = container.decode(.maximumAge, Int.self, 30)
        maximumAgeEnabled = container.decode(.maximumAgeEnabled, Bool.self, false)
        meInUsernameColor = container.decode(.meInUsernameColor, Bool.self, true)
        enabled = container.decode(.enabled, Bool.self, true)
        filters = container.decode(.usernamesToIgnore, [SettingsChatFilter].self, [])
        textToSpeechEnabled = container.decode(.textToSpeechEnabled, Bool.self, false)
        textToSpeechDetectLanguagePerMessage = container.decode(.textToSpeechDetectLanguagePerMessage, Bool.self, false)
        textToSpeechSayUsername = container.decode(.textToSpeechSayUsername, Bool.self, true)
        textToSpeechRate = container.decode(.textToSpeechRate, Float.self, 0.4)
        textToSpeechSayVolume = container.decode(.textToSpeechSayVolume, Float.self, 0.6)
        textToSpeechLanguageVoices = container.decode(.textToSpeechLanguageVoices, [String: String].self, .init())
        textToSpeechSubscribersOnly = container.decode(.textToSpeechSubscribersOnly, Bool.self, false)
        textToSpeechFilter = container.decode(.textToSpeechFilter, Bool.self, true)
        textToSpeechFilterMentions = container.decode(.textToSpeechFilterMentions, Bool.self, true)
        mirrored = container.decode(.mirrored, Bool.self, false)
        botEnabled = container.decode(.botEnabled, Bool.self, false)
        botCommandPermissions = container.decode(.botCommandPermissions, SettingsChatBotPermissions.self, .init())
        botSendLowBatteryWarning = container.decode(.botSendLowBatteryWarning, Bool.self, false)
        badges = container.decode(.badges, Bool.self, true)
        showFirstTimeChatterMessage = container.decode(.showFirstTimeChatterMessage, Bool.self, true)
        showNewFollowerMessage = container.decode(.showNewFollowerMessage, Bool.self, true)
        bottom = container.decode(.bottom, Double.self, 0.0)
        bottomPoints = (try? container.decode(Double.self, forKey: .bottomPoints)) ?? min(
            UIScreen.main.bounds.width * bottom,
            200
        )
        newMessagesAtTop = container.decode(.newMessagesAtTop, Bool.self, false)
        textToSpeechPauseBetweenMessages = container.decode(.textToSpeechPauseBetweenMessages, Double.self, 1.0)
        platform = container.decode(.platform, Bool.self, true)
        showDeletedMessages = container.decode(.showDeletedMessages, Bool.self, false)
    }

    func getRotation() -> Double {
        if newMessagesAtTop {
            return 0.0
        } else {
            return 180.0
        }
    }

    func getScaleX() -> Double {
        if newMessagesAtTop {
            return 1.0
        } else {
            return -1.0
        }
    }

    func isMirrored() -> CGFloat {
        if mirrored {
            return -1
        } else {
            return 1
        }
    }
}

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
    case top = "Top"

    public init(from decoder: Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            getDefaultMic()
    }
}

class SettingsMicsMic: Codable, Equatable {
    static func == (lhs: SettingsMicsMic, rhs: SettingsMicsMic) -> Bool {
        return lhs.inputUid == rhs.inputUid && lhs.dataSourceID == rhs.dataSourceID
    }

    var name: String = ""
    var inputUid: String = ""
    var dataSourceID: Int?
    // var builtInOrientation: SettingsMic?

    enum CodingKeys: CodingKey {
        case name,
             inputUid,
             dataSourceID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.inputUid, inputUid)
        try container.encode(.dataSourceID, dataSourceID)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        inputUid = container.decode(.inputUid, String.self, "")
        dataSourceID = container.decode(.dataSourceID, Int?.self, nil)
    }
}

class SettingsMics: Codable, ObservableObject {
    @Published var mics: [SettingsMicsMic] = []

    enum CodingKeys: CodingKey {
        case mics
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.mics, mics)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mics = container.decode(.mics, [SettingsMicsMic].self, [])
    }
}

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"

    public init(from decoder: Decoder) throws {
        self = try SettingsLogLevel(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .error
    }
}

class SettingsDebugAudioOutputToInputChannelsMap: Codable {
    var channel0: Int = 0
    var channel1: Int = 1
}

let pixelFormats = ["32BGRA", "420YpCbCr8BiPlanarFullRange", "420YpCbCr8BiPlanarVideoRange"]
let pixelFormatTypes = [
    kCVPixelFormatType_32BGRA,
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
]

class SettingsDebugBeautyFilter: Codable, ObservableObject {
    @Published var showBlur = false
    @Published var showBlurBackground: Bool = false
    @Published var showMoblin = false
    @Published var showCute: Bool = false
    var cuteRadius: Float = 0.5
    var cuteScale: Float = 0.0
    var cuteOffset: Float = 0.5
    var showBeauty: Bool = false
    var shapeRadius: Float = 0.5
    var shapeScale: Float = 0.0
    var shapeOffset: Float = 0.5
    var smoothAmount: Float = 0.65
    var smoothRadius: Float = 20.0

    enum CodingKeys: CodingKey {
        case showBlur,
             showBlurBackground,
             showMoblin,
             showCute,
             cuteRadius,
             cuteScale,
             cuteOffset,
             showBeauty,
             shapeRadius,
             shapeScale,
             shapeOffset,
             smoothAmount,
             smoothRadius
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.showBlur, showBlur)
        try container.encode(.showBlurBackground, showBlurBackground)
        try container.encode(.showMoblin, showMoblin)
        try container.encode(.showCute, showCute)
        try container.encode(.cuteRadius, cuteRadius)
        try container.encode(.cuteScale, cuteScale)
        try container.encode(.cuteOffset, cuteOffset)
        try container.encode(.showBeauty, showBeauty)
        try container.encode(.shapeRadius, shapeRadius)
        try container.encode(.shapeScale, shapeScale)
        try container.encode(.shapeOffset, shapeOffset)
        try container.encode(.smoothAmount, smoothAmount)
        try container.encode(.smoothRadius, smoothRadius)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showBlur = container.decode(.showBlur, Bool.self, false)
        showBlurBackground = container.decode(.showBlurBackground, Bool.self, false)
        showMoblin = container.decode(.showMoblin, Bool.self, false)
        showCute = container.decode(.showCute, Bool.self, false)
        cuteRadius = container.decode(.cuteRadius, Float.self, 0.5)
        cuteScale = container.decode(.cuteScale, Float.self, 0.0)
        cuteOffset = container.decode(.cuteOffset, Float.self, 0.5)
        showBeauty = container.decode(.showBeauty, Bool.self, false)
        shapeRadius = container.decode(.shapeRadius, Float.self, 0.5)
        shapeScale = container.decode(.shapeScale, Float.self, 0.0)
        shapeOffset = container.decode(.shapeOffset, Float.self, 0.5)
        smoothAmount = container.decode(.smoothAmount, Float.self, 0.65)
        smoothRadius = container.decode(.smoothRadius, Float.self, 20.0)
    }
}

class SettingsHttpProxy: Codable {
    var enabled: Bool = false
    var host: String = ""
    var port: UInt16 = 3128

    func toHttpProxy() -> HttpProxy? {
        if enabled {
            return .init(host: host, port: port)
        } else {
            return nil
        }
    }
}

class SettingsTesla: Codable {
    var vin: String = ""
    var privateKey: String = ""
    var enabled: Bool? = true
}

enum SettingsDnsLookupStrategy: String, Codable, CaseIterable {
    case system = "System"
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case ipv4AndIpv6 = "IPv4 and IPv6"

    public init(from decoder: Decoder) throws {
        self = try SettingsDnsLookupStrategy(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .system
    }
}

let dnsLookupStrategies = SettingsDnsLookupStrategy.allCases.map { $0.rawValue }

enum SettingsSelfieStickButtonFunction: String, Codable, CaseIterable {
    case switchScene

    public init(from decoder: Decoder) throws {
        do {
            self = try SettingsSelfieStickButtonFunction(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .switchScene
        } catch {
            self = .switchScene
        }
    }

    func toString() -> String {
        switch self {
        case .switchScene:
            return String(localized: "Switch scene")
        }
    }
}

class SettingsSelfieStick: Codable, ObservableObject {
    @Published var buttonEnabled: Bool = false
    @Published var buttonFunction: SettingsSelfieStickButtonFunction = .switchScene

    enum CodingKeys: CodingKey {
        case enabled,
             function
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, buttonEnabled)
        try container.encode(.function, buttonFunction)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttonEnabled = container.decode(.enabled, Bool.self, false)
        buttonFunction = container.decode(.function, SettingsSelfieStickButtonFunction.self, .switchScene)
    }
}

class SettingsDebug: Codable, ObservableObject {
    var logLevel: SettingsLogLevel = .error
    @Published var srtOverlay: Bool = false
    var srtOverheadBandwidth: Int32 = 25
    @Published var cameraSwitchRemoveBlackish: Float = 0.3
    var maximumBandwidthFollowInput: Bool = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap = .init()
    var bluetoothOutputOnly: Bool = true
    var maximumLogLines: Int = 500
    var pixelFormat: String = pixelFormats[1]
    @Published var beautyFilter: Bool = false
    var beautyFilterSettings: SettingsDebugBeautyFilter = .init()
    @Published var allowVideoRangePixelFormat: Bool = false
    var blurSceneSwitch: Bool = true
    @Published var metalPetalFilters: Bool = false
    var preferStereoMic: Bool = false
    @Published var twitchRewards: Bool = false
    @Published var removeWindNoise: Bool = false
    var httpProxy: SettingsHttpProxy = .init()
    var tesla: SettingsTesla = .init()
    @Published var reliableChat: Bool = false
    @Published var timecodesEnabled: Bool = false
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system
    var srtlaBatchSend: Bool = false
    var cameraControlsEnabled: Bool = true
    @Published var dataRateLimitFactor: Float = 2.0
    @Published var bitrateDropFix: Bool = false
    @Published var relaxedBitrate: Bool = false
    var externalDisplayChat: Bool = false
    var videoSourceWidgetTrackFace: Bool = false
    @Published var srtlaBatchSendEnabled: Bool = true
    var replay: Bool = false
    var recordSegmentLength: Double = 5.0
    @Published var builtinAudioAndVideoDelay: Double = 0.0

    enum CodingKeys: CodingKey {
        case logLevel,
             srtOverlay,
             srtOverheadBandwidth,
             cameraSwitchRemoveBlackish,
             maximumBandwidthFollowInput,
             audioOutputToInputChannelsMap,
             bluetoothOutputOnly,
             maximumLogLines,
             pixelFormat,
             beautyFilter,
             beautyFilterSettings,
             allowVideoRangePixelFormat,
             blurSceneSwitch,
             metalPetalFilters,
             preferStereoMic,
             twitchRewards,
             removeWindNoise,
             httpProxy,
             tesla,
             reliableChat,
             timecodesEnabled,
             dnsLookupStrategy,
             srtlaBatchSend,
             cameraControlsEnabled,
             dataRateLimitFactor,
             bitrateDropFix,
             relaxedBitrate,
             externalDisplayChat,
             videoSourceWidgetTrackFace,
             srtlaBatchSendEnabled,
             replay,
             recordSegmentLength,
             builtinAudioAndVideoDelay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.logLevel, logLevel)
        try container.encode(.srtOverlay, srtOverlay)
        try container.encode(.srtOverheadBandwidth, srtOverheadBandwidth)
        try container.encode(.cameraSwitchRemoveBlackish, cameraSwitchRemoveBlackish)
        try container.encode(.maximumBandwidthFollowInput, maximumBandwidthFollowInput)
        try container.encode(.audioOutputToInputChannelsMap, audioOutputToInputChannelsMap)
        try container.encode(.bluetoothOutputOnly, bluetoothOutputOnly)
        try container.encode(.maximumLogLines, maximumLogLines)
        try container.encode(.pixelFormat, pixelFormat)
        try container.encode(.beautyFilter, beautyFilter)
        try container.encode(.beautyFilterSettings, beautyFilterSettings)
        try container.encode(.allowVideoRangePixelFormat, allowVideoRangePixelFormat)
        try container.encode(.blurSceneSwitch, blurSceneSwitch)
        try container.encode(.metalPetalFilters, metalPetalFilters)
        try container.encode(.preferStereoMic, preferStereoMic)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.removeWindNoise, removeWindNoise)
        try container.encode(.httpProxy, httpProxy)
        try container.encode(.tesla, tesla)
        try container.encode(.reliableChat, reliableChat)
        try container.encode(.timecodesEnabled, timecodesEnabled)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
        try container.encode(.srtlaBatchSend, srtlaBatchSend)
        try container.encode(.cameraControlsEnabled, cameraControlsEnabled)
        try container.encode(.dataRateLimitFactor, dataRateLimitFactor)
        try container.encode(.bitrateDropFix, bitrateDropFix)
        try container.encode(.relaxedBitrate, relaxedBitrate)
        try container.encode(.externalDisplayChat, externalDisplayChat)
        try container.encode(.videoSourceWidgetTrackFace, videoSourceWidgetTrackFace)
        try container.encode(.srtlaBatchSendEnabled, srtlaBatchSendEnabled)
        try container.encode(.replay, replay)
        try container.encode(.recordSegmentLength, recordSegmentLength)
        try container.encode(.builtinAudioAndVideoDelay, builtinAudioAndVideoDelay)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logLevel = try container.decode(SettingsLogLevel.self, forKey: .logLevel)
        srtOverlay = try container.decode(Bool.self, forKey: .srtOverlay)
        srtOverheadBandwidth = (try? container.decode(Int32.self, forKey: .srtOverheadBandwidth)) ?? 25
        cameraSwitchRemoveBlackish = (try? container.decode(Float.self, forKey: .cameraSwitchRemoveBlackish)) ?? 0.3
        maximumBandwidthFollowInput = (try? container.decode(Bool.self, forKey: .maximumBandwidthFollowInput)) ?? true
        audioOutputToInputChannelsMap = (try? container.decode(
            SettingsDebugAudioOutputToInputChannelsMap.self,
            forKey: .audioOutputToInputChannelsMap
        )) ?? .init()
        bluetoothOutputOnly = (try? container.decode(Bool.self, forKey: .bluetoothOutputOnly)) ?? true
        maximumLogLines = (try? container.decode(Int.self, forKey: .maximumLogLines)) ?? 500
        pixelFormat = (try? container.decode(String.self, forKey: .pixelFormat)) ?? pixelFormats[1]
        beautyFilter = (try? container.decode(Bool.self, forKey: .beautyFilter)) ?? false
        beautyFilterSettings = (try? container.decode(SettingsDebugBeautyFilter.self, forKey: .beautyFilterSettings)) ??
            .init()
        allowVideoRangePixelFormat = (try? container.decode(Bool.self, forKey: .allowVideoRangePixelFormat)) ?? false
        blurSceneSwitch = (try? container.decode(Bool.self, forKey: .blurSceneSwitch)) ?? true
        metalPetalFilters = (try? container.decode(Bool.self, forKey: .metalPetalFilters)) ?? false
        preferStereoMic = (try? container.decode(Bool.self, forKey: .preferStereoMic)) ?? false
        twitchRewards = (try? container.decode(Bool.self, forKey: .twitchRewards)) ?? false
        removeWindNoise = (try? container.decode(Bool.self, forKey: .removeWindNoise)) ?? false
        httpProxy = (try? container.decode(SettingsHttpProxy.self, forKey: .httpProxy)) ?? .init()
        tesla = (try? container.decode(SettingsTesla.self, forKey: .tesla)) ?? .init()
        reliableChat = (try? container.decode(Bool.self, forKey: .reliableChat)) ?? false
        timecodesEnabled = (try? container.decode(Bool.self, forKey: .timecodesEnabled)) ?? false
        dnsLookupStrategy = (try? container.decode(SettingsDnsLookupStrategy.self, forKey: .dnsLookupStrategy)) ??
            .system
        srtlaBatchSend = (try? container.decode(Bool.self, forKey: .srtlaBatchSend)) ?? false
        cameraControlsEnabled = (try? container.decode(Bool.self, forKey: .cameraControlsEnabled)) ?? true
        dataRateLimitFactor = (try? container.decode(Float.self, forKey: .dataRateLimitFactor)) ?? 2.0
        bitrateDropFix = (try? container.decode(Bool.self, forKey: .bitrateDropFix)) ?? false
        relaxedBitrate = (try? container.decode(Bool.self, forKey: .relaxedBitrate)) ?? false
        externalDisplayChat = (try? container.decode(Bool.self, forKey: .externalDisplayChat)) ?? false
        videoSourceWidgetTrackFace = (try? container.decode(Bool.self, forKey: .videoSourceWidgetTrackFace)) ?? false
        srtlaBatchSendEnabled = (try? container.decode(Bool.self, forKey: .srtlaBatchSendEnabled)) ?? true
        replay = (try? container.decode(Bool.self, forKey: .replay)) ?? false
        recordSegmentLength = (try? container.decode(Double.self, forKey: .recordSegmentLength)) ?? 5.0
        builtinAudioAndVideoDelay = (try? container.decode(Double.self, forKey: .builtinAudioAndVideoDelay)) ?? 0.0
    }
}

class SettingsRtmpServerStream: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My stream"
    var streamKey: String = ""
    var latency: Int32? = defaultRtmpLatency
    var autoSelectMic: Bool? = true

    func camera() -> String {
        return rtmpCamera(name: name)
    }

    func clone() -> SettingsRtmpServerStream {
        let new = SettingsRtmpServerStream()
        new.id = id
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        new.autoSelectMic = autoSelectMic
        return new
    }
}

class SettingsRtmpServer: Codable {
    var enabled: Bool = false
    var port: UInt16 = 1935
    var streams: [SettingsRtmpServerStream] = []

    func clone() -> SettingsRtmpServer {
        let new = SettingsRtmpServer()
        new.enabled = enabled
        new.port = port
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }
}

class SettingsSrtlaServerStream: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My stream"
    var streamId: String = ""
    var autoSelectMic: Bool? = true

    func camera() -> String {
        return srtlaCamera(name: name)
    }

    func clone() -> SettingsSrtlaServerStream {
        let new = SettingsSrtlaServerStream()
        new.name = name
        new.streamId = streamId
        new.autoSelectMic = autoSelectMic
        return new
    }
}

class SettingsSrtlaServer: Codable {
    var enabled: Bool = false
    var srtPort: UInt16 = 4000
    var srtlaPort: UInt16 = 5000
    var streams: [SettingsSrtlaServerStream] = []

    func clone() -> SettingsSrtlaServer {
        let new = SettingsSrtlaServer()
        new.enabled = enabled
        new.srtPort = srtPort
        new.srtlaPort = srtlaPort
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }

    func srtlaSrtPort() -> UInt16 {
        return srtlaPort + 1
    }
}

class SettingsMediaPlayerFile: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My video"

    func clone() -> SettingsMediaPlayerFile {
        let new = SettingsMediaPlayerFile()
        new.id = id
        new.name = name
        return new
    }
}

class SettingsMediaPlayer: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = "My player"
    @Published var playerId: String = ""
    @Published var autoSelectMic: Bool = true
    @Published var playlist: [SettingsMediaPlayerFile] = []

    enum CodingKeys: CodingKey {
        case id,
             name,
             playerId,
             autoSelectMic,
             playlist
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.playerId, playerId)
        try container.encode(.autoSelectMic, autoSelectMic)
        try container.encode(.playlist, playlist)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "My player")
        playerId = container.decode(.playerId, String.self, "")
        autoSelectMic = container.decode(.autoSelectMic, Bool.self, true)
        playlist = container.decode(.playlist, [SettingsMediaPlayerFile].self, [])
    }

    func camera() -> String {
        return mediaPlayerCamera(name: name)
    }

    func clone() -> SettingsMediaPlayer {
        let new = SettingsMediaPlayer()
        new.id = id
        new.name = name
        new.playerId = playerId
        new.autoSelectMic = autoSelectMic
        for file in playlist {
            new.playlist.append(file.clone())
        }
        return new
    }
}

class SettingsMediaPlayers: Codable, ObservableObject {
    @Published var players: [SettingsMediaPlayer] = []

    enum CodingKeys: CodingKey {
        case players
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.players, players)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = container.decode(.players, [SettingsMediaPlayer].self, [])
    }
}

enum SettingsDjiDeviceUrlType: String, Codable, CaseIterable {
    case server = "Server"
    case custom = "Custom"

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceUrlType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .server
    }

    func toString() -> String {
        switch self {
        case .server:
            return String(localized: "Server")
        case .custom:
            return String(localized: "Custom")
        }
    }
}

enum SettingsDjiDeviceImageStabilization: String, CaseIterable, Codable {
    case off
    case rockSteady
    case rockSteadyPlus
    case horizonBalancing
    case horizonSteady

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceImageStabilization(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .rockSteady
    }

    func toString() -> String {
        switch self {
        case .off:
            return String(localized: "Off")
        case .rockSteady:
            return String(localized: "RockSteady")
        case .rockSteadyPlus:
            return String(localized: "RockSteady+")
        case .horizonBalancing:
            return String(localized: "HorizonBalancing")
        case .horizonSteady:
            return String(localized: "HorizonSteady")
        }
    }
}

enum SettingsDjiDeviceResolution: String, CaseIterable, Codable {
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceResolution(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .r1080p
    }
}

enum SettingsDjiDeviceModel: String, Codable {
    case osmoAction3
    case osmoAction4
    case osmoAction5Pro
    case osmoPocket3
    case unknown

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceModel(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .unknown
    }
}

var djiDeviceBitrates: [UInt32] = [
    20_000_000,
    16_000_000,
    12_000_000,
    10_000_000,
    8_000_000,
    6_000_000,
    4_000_000,
    2_000_000,
]

var djiDeviceFpss: [Int] = [25, 30]

class SettingsDjiDevice: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = ""
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
    var wifiSsid: String = ""
    var wifiPassword: String = ""
    @Published var rtmpUrlType: SettingsDjiDeviceUrlType = .server
    @Published var serverRtmpStreamId: UUID = .init()
    @Published var serverRtmpUrl: String = ""
    @Published var customRtmpUrl: String = ""
    @Published var autoRestartStream: Bool = false
    @Published var imageStabilization: SettingsDjiDeviceImageStabilization = .off
    @Published var resolution: SettingsDjiDeviceResolution = .r1080p
    @Published var fps: Int = 30
    @Published var bitrate: UInt32 = 6_000_000
    @Published var isStarted: Bool = false
    @Published var model: SettingsDjiDeviceModel = .unknown
    @Published var state: DjiDeviceState?

    init() {
        bluetoothPeripheralName = nil
        bluetoothPeripheralId = nil
    }

    enum CodingKeys: CodingKey {
        case id,
             name,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             wifiSsid,
             wifiPassword,
             rtmpUrlType,
             serverRtmpStreamId,
             serverRtmpUrl,
             customRtmpUrl,
             autoRestartStream,
             imageStabilization,
             resolution,
             fps,
             bitrate,
             isStarted,
             model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.wifiSsid, wifiSsid)
        try container.encode(.wifiPassword, wifiPassword)
        try container.encode(.rtmpUrlType, rtmpUrlType)
        try container.encode(.serverRtmpStreamId, serverRtmpStreamId)
        try container.encode(.serverRtmpUrl, serverRtmpUrl)
        try container.encode(.customRtmpUrl, customRtmpUrl)
        try container.encode(.autoRestartStream, autoRestartStream)
        try container.encode(.imageStabilization, imageStabilization)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.isStarted, isStarted)
        try container.encode(.model, model)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        wifiSsid = container.decode(.wifiSsid, String.self, "")
        wifiPassword = container.decode(.wifiPassword, String.self, "")
        rtmpUrlType = container.decode(.rtmpUrlType, SettingsDjiDeviceUrlType.self, .server)
        serverRtmpStreamId = container.decode(.serverRtmpStreamId, UUID.self, .init())
        serverRtmpUrl = container.decode(.serverRtmpUrl, String.self, "")
        customRtmpUrl = container.decode(.customRtmpUrl, String.self, "")
        autoRestartStream = container.decode(.autoRestartStream, Bool.self, false)
        imageStabilization = container.decode(.imageStabilization, SettingsDjiDeviceImageStabilization.self, .off)
        resolution = container.decode(.resolution, SettingsDjiDeviceResolution.self, .r1080p)
        fps = container.decode(.fps, Int.self, 30)
        bitrate = container.decode(.bitrate, UInt32.self, 6_000_000)
        isStarted = container.decode(.isStarted, Bool.self, false)
        model = container.decode(.model, SettingsDjiDeviceModel.self, .unknown)
    }
}

class SettingsDjiDevices: Codable, ObservableObject {
    @Published var devices: [SettingsDjiDevice] = []

    init() {}

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsDjiDevice].self, [])
    }
}

enum SettingsDjiGimbalDeviceModel: String, Codable {
    case osmoMobile7P
    case unknown

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiGimbalDeviceModel(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .unknown
    }
}

class SettingsDjiGimbalDevice: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var enabled: Bool = false
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
    var model: SettingsDjiGimbalDeviceModel = .unknown
}

class SettingsDjiGimbalDevices: Codable {
    var devices: [SettingsDjiGimbalDevice] = []
}

class SettingsGoProWifiCredentials: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name = "My SSID"
    @Published var ssid = ""
    @Published var password = ""

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             ssid,
             password
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.ssid, ssid)
        try container.encode(.password, password)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        ssid = container.decode(.ssid, String.self, "")
        password = container.decode(.password, String.self, "")
    }
}

class SettingsGoProRtmpUrl: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name = "My URL"
    @Published var type: SettingsDjiDeviceUrlType = .server
    @Published var serverStreamId: UUID = .init()
    @Published var serverUrl = ""
    @Published var customUrl = ""

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             type,
             serverStreamId,
             serverUrl,
             customUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.type, type)
        try container.encode(.serverStreamId, serverStreamId)
        try container.encode(.serverUrl, serverUrl)
        try container.encode(.customUrl, customUrl)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "My URL")
        type = container.decode(.type, SettingsDjiDeviceUrlType.self, .server)
        serverStreamId = container.decode(.serverStreamId, UUID.self, .init())
        serverUrl = container.decode(.serverUrl, String.self, "")
        customUrl = container.decode(.customUrl, String.self, "")
    }
}

class SettingsGoProLaunchLiveStream: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name = "1080p"
    @Published var isHero12Or13: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             isHero12Or13
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.isHero12Or13, isHero12Or13)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "1080p")
        isHero12Or13 = container.decode(.isHero12Or13, Bool.self, true)
    }
}

class SettingsGoPro: Codable, ObservableObject {
    @Published var launchLiveStream: [SettingsGoProLaunchLiveStream] = []
    @Published var selectedLaunchLiveStream: UUID?
    @Published var wifiCredentials: [SettingsGoProWifiCredentials] = []
    @Published var selectedWifiCredentials: UUID?
    @Published var rtmpUrls: [SettingsGoProRtmpUrl] = []
    @Published var selectedRtmpUrl: UUID?

    init() {}

    enum CodingKeys: CodingKey {
        case launchLiveStream,
             selectedLaunchLiveStream,
             wifiCredentials,
             selectedWifiCredentials,
             rtmpUrls,
             selectedRtmpUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.launchLiveStream, launchLiveStream)
        try container.encode(.selectedLaunchLiveStream, selectedLaunchLiveStream)
        try container.encode(.wifiCredentials, wifiCredentials)
        try container.encode(.selectedWifiCredentials, selectedWifiCredentials)
        try container.encode(.rtmpUrls, rtmpUrls)
        try container.encode(.selectedRtmpUrl, selectedRtmpUrl)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchLiveStream = container.decode(.launchLiveStream, [SettingsGoProLaunchLiveStream].self, [])
        selectedLaunchLiveStream = try? container.decode(UUID.self, forKey: .selectedLaunchLiveStream)
        wifiCredentials = container.decode(.wifiCredentials, [SettingsGoProWifiCredentials].self, [])
        selectedWifiCredentials = try? container.decode(UUID.self, forKey: .selectedWifiCredentials)
        rtmpUrls = container.decode(.rtmpUrls, [SettingsGoProRtmpUrl].self, [])
        selectedRtmpUrl = try? container.decode(UUID.self, forKey: .selectedRtmpUrl)
    }
}

enum SettingsReplaySpeed: String, Codable, CaseIterable {
    case oneHalf = "0.5x"
    case one = "1x"

    public init(from decoder: Decoder) throws {
        self = try SettingsReplaySpeed(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .one
    }

    func toNumber() -> Double {
        switch self {
        case .oneHalf:
            return 0.5
        case .one:
            return 1.0
        }
    }
}

class SettingsReplay: Codable {
    // periphery:ignore
    var position: Double? = 10.0
    var start: Double? = 20.0
    var stop: Double? = 30.0
    var speed: SettingsReplaySpeed = .one
}

class SettingsCatPrinter: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var printChat: Bool = true
    @Published var faxMeowSound: Bool = true
    @Published var printSnapshots: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             printChat,
             faxMeowSound,
             printSnapshots
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.printChat, printChat)
        try container.encode(.faxMeowSound, faxMeowSound)
        try container.encode(.printSnapshots, printSnapshots)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        printChat = container.decode(.printChat, Bool.self, true)
        faxMeowSound = container.decode(.faxMeowSound, Bool.self, true)
        printSnapshots = container.decode(.printSnapshots, Bool.self, true)
    }
}

class SettingsCatPrinters: Codable, ObservableObject {
    @Published var devices: [SettingsCatPrinter] = []
    @Published var backgroundPrinting: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case devices,
             backgroundPrinting
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
        try container.encode(.backgroundPrinting, backgroundPrinting)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsCatPrinter].self, [])
        backgroundPrinting = container.decode(.backgroundPrinting, Bool.self, false)
    }
}

class SettingsCyclingPowerDevice: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var enabled: Bool = false
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
}

class SettingsCyclingPowerDevices: Codable {
    var devices: [SettingsCyclingPowerDevice] = []
}

class SettingsHeartRateDevice: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var enabled: Bool = false
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
}

class SettingsHeartRateDevices: Codable {
    var devices: [SettingsHeartRateDevice] = []
}

private let defaultRgbLightColor = RgbColor(red: 0, green: 255, blue: 0)

class SettingsPhoneCoolerDevice: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var rgbLightEnabled: Bool = false
    var rgbLightColor: RgbColor = defaultRgbLightColor
    @Published var rgbLightColorColor: Color = defaultRgbLightColor.color()
    @Published var rgbLightBrightness: Double = 100.0

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             rgbLightEnabled,
             rgbLightColor,
             rgbLightBrightness
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.rgbLightEnabled, rgbLightEnabled)
        try container.encode(.rgbLightColor, rgbLightColor)
        try container.encode(.rgbLightBrightness, rgbLightBrightness)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        rgbLightEnabled = container.decode(.rgbLightEnabled, Bool.self, false)
        rgbLightColor = container.decode(.rgbLightColor, RgbColor.self, defaultRgbLightColor)
        rgbLightColorColor = rgbLightColor.color()
        rgbLightBrightness = container.decode(.rgbLightBrightness, Double.self, 100.0)
    }
}

class SettingsPhoneCoolerDevices: Codable, ObservableObject {
    @Published var devices: [SettingsPhoneCoolerDevice] = []

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsPhoneCoolerDevice].self, [])
    }
}

class SettingsQuickButtons: Codable, ObservableObject {
    @Published var twoColumns: Bool = true
    @Published var bigButtons: Bool = false
    @Published var showName: Bool = true
    @Published var enableScroll: Bool = true
    @Published var blackScreenShowChat: Bool = false

    enum CodingKeys: CodingKey {
        case twoColumns,
             bigButtons,
             showName,
             enableScroll,
             blackScreenShowChat
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twoColumns, twoColumns)
        try container.encode(.bigButtons, bigButtons)
        try container.encode(.showName, showName)
        try container.encode(.enableScroll, enableScroll)
        try container.encode(.blackScreenShowChat, blackScreenShowChat)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoColumns = container.decode(.twoColumns, Bool.self, true)
        bigButtons = container.decode(.bigButtons, Bool.self, false)
        showName = container.decode(.showName, Bool.self, true)
        enableScroll = container.decode(.enableScroll, Bool.self, true)
        blackScreenShowChat = container.decode(.blackScreenShowChat, Bool.self, false)
    }
}

class SettingsNetworkInterfaceName: Codable, Identifiable {
    var id: UUID = .init()
    var interfaceName: String = ""
    var name: String = ""
}

enum SettingsGameControllerButtonFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case record = "Record"
    case stream = "Stream"
    case zoomIn = "Zoom in"
    case zoomOut = "Zoom out"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case chat = "Chat"
    case scene = "Scene"
    case instantReplay = "Instant replay"
    case pauseTts = "Pause TTS"

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Interactive chat"
        }
        self = SettingsGameControllerButtonFunction(rawValue: value) ?? .unused
    }

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .record:
            return String(localized: "Record")
        case .stream:
            return String(localized: "Stream")
        case .zoomIn:
            return String(localized: "Zoom in")
        case .zoomOut:
            return String(localized: "Zoom out")
        case .mute:
            return String(localized: "Mute")
        case .torch:
            return String(localized: "Torch")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .chat:
            return String(localized: "Chat")
        case .scene:
            return String(localized: "Scene")
        case .instantReplay:
            return String(localized: "Instant replay")
        case .pauseTts:
            return String(localized: "Pause TTS")
        }
    }
}

class SettingsGameControllerButton: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var name: String = ""
    var text: String = ""
    @Published var function: SettingsGameControllerButtonFunction = .unused
    @Published var sceneId: UUID = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             text,
             function,
             sceneId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.text, text)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        text = container.decode(.text, String.self, "")
        function = container.decode(.function, SettingsGameControllerButtonFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID.self, .init())
    }
}

class SettingsGameController: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var buttons: [SettingsGameControllerButton] = []

    init() {
        var button = SettingsGameControllerButton()
        button.name = "dpad.left.fill"
        button.text = String(localized: "Left")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.right.fill"
        button.text = String(localized: "Right")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.up.fill"
        button.text = String(localized: "Up")
        button.function = .zoomIn
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.down.fill"
        button.text = String(localized: "Down")
        button.function = .zoomOut
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "a.circle"
        button.text = "A"
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "b.circle"
        button.text = "B"
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "x.circle"
        button.text = "X"
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "y.circle"
        button.text = "Y"
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "circle.circle"
        button.text = String(localized: "Circle")
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "xmark.circle"
        button.text = String(localized: "X mark")
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "square.circle"
        button.text = String(localized: "Square")
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "triangle.circle"
        button.text = String(localized: "Triangle")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zl.rectangle.roundedtop"
        button.text = "ZL"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l.rectangle.roundedbottom"
        button.text = "L"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zr.rectangle.roundedtop"
        button.text = "ZR"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r.rectangle.roundedbottom"
        button.text = "R"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l2.rectangle.roundedtop"
        button.text = "L2"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l1.rectangle.roundedbottom"
        button.text = "L1"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r2.rectangle.roundedtop"
        button.text = "R2"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r1.rectangle.roundedbottom"
        button.text = "R1"
        button.function = .chat
        buttons.append(button)
    }

    enum CodingKeys: CodingKey {
        case id,
             buttons
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.buttons, buttons)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        buttons = container.decode(.buttons, [SettingsGameControllerButton].self, [])
    }
}

enum SettingsKeyboardKeyFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case record = "Record"
    case stream = "Stream"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case scene = "Scene"
    case widget = "Widget"
    case instantReplay = "Instant replay"

    public init(from decoder: Decoder) throws {
        self = try SettingsKeyboardKeyFunction(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .unused
    }

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .record:
            return String(localized: "Record")
        case .stream:
            return String(localized: "Stream")
        case .mute:
            return String(localized: "Mute")
        case .torch:
            return String(localized: "Torch")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .scene:
            return String(localized: "Scene")
        case .widget:
            return String(localized: "Widget")
        case .instantReplay:
            return String(localized: "Instant replay")
        }
    }
}

class SettingsKeyboardKey: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var key: String = ""
    @Published var function: SettingsKeyboardKeyFunction = .unused
    @Published var sceneId: UUID = .init()
    @Published var widgetId: UUID? = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             key,
             function,
             sceneId,
             widgetId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.key, key)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.widgetId, widgetId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        key = container.decode(.key, String.self, "")
        function = container.decode(.function, SettingsKeyboardKeyFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID.self, .init())
        widgetId = container.decode(.widgetId, UUID.self, .init())
    }
}

class SettingsKeyboard: Codable, ObservableObject {
    @Published var keys: [SettingsKeyboardKey] = []

    init() {}

    enum CodingKeys: CodingKey {
        case keys
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.keys, keys)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = container.decode(.keys, [SettingsKeyboardKey].self, [])
    }
}

class SettingsRemoteControlAssistant: Codable {
    var enabled: Bool = false
    // periphery:ignore
    var address: String? = ""
    var port: UInt16 = 2345
    var relay: SettingsRemoteControlServerRelay? = .init()
}

class SettingsRemoteControlStreamer: Codable {
    var enabled: Bool = false
    var url: String = ""
    var previewFps: Float? = 1.0
}

class SettingsRemoteControlServerRelay: Codable {
    var enabled: Bool = false
    var baseUrl: String = "wss://moblin.mys-lang.org/moblin-remote-control-relay"
    var bridgeId: String = UUID().uuidString.lowercased()
}

class SettingsRemoteControl: Codable {
    var client: SettingsRemoteControlAssistant = .init()
    var server: SettingsRemoteControlStreamer = .init()
    var password: String? = randomGoodPassword()
}

class SettingsMoblinkStreamer: Codable {
    var enabled: Bool = false
    var port: UInt16 = 7777
}

class SettingsMoblinkRelay: Codable, ObservableObject {
    var enabled: Bool = false
    @Published var name: String = randomName()
    @Published var url: String = ""
    @Published var manual: Bool = false

    enum CodingKeys: CodingKey {
        case enabled,
             name,
             url,
             manual
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.manual, manual)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        name = container.decode(.name, String.self, randomName())
        url = container.decode(.url, String.self, "")
        manual = container.decode(.manual, Bool.self, false)
    }
}

class SettingsMoblink: Codable {
    var server: SettingsMoblinkStreamer = .init()
    var client: SettingsMoblinkRelay = .init()
    var password = "1234"
}

enum SettingsSceneSwitchTransition: String, Codable, CaseIterable {
    case blur = "Blur"
    case freeze = "Freeze"
    case blurAndZoom = "Blur & zoom"

    public init(from decoder: Decoder) throws {
        self = try SettingsSceneSwitchTransition(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .blur
    }

    func toString() -> String {
        switch self {
        case .blur:
            return String(localized: "Blur")
        case .freeze:
            return String(localized: "Freeze")
        case .blurAndZoom:
            return String(localized: "Blur & zoom")
        }
    }

    func toVideoUnit() -> SceneSwitchTransition {
        switch self {
        case .blur:
            return .blur
        case .freeze:
            return .freeze
        case .blurAndZoom:
            return .blurAndZoom
        }
    }
}

enum SettingsExternalDisplayContent: String, Codable, CaseIterable {
    case stream = "Stream"
    case cleanStream = "Clean stream"
    case chat = "Chat"
    case mirror = "Mirror"

    public init(from decoder: Decoder) throws {
        self = try SettingsExternalDisplayContent(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .stream
    }

    func toString() -> String {
        switch self {
        case .stream:
            return String(localized: "Stream")
        case .cleanStream:
            return String(localized: "Clean stream")
        case .chat:
            return String(localized: "Chat")
        case .mirror:
            return String(localized: "Mirror")
        }
    }
}

class SettingsPrivacyRegion: Codable, Identifiable {
    var id: UUID = .init()
    var latitude: Double = 0
    var longitude: Double = 0
    var latitudeDelta: Double = 30
    var longitudeDelta: Double = 30
}

class SettingsLocation: Codable {
    var enabled: Bool = false
    var privacyRegions: [SettingsPrivacyRegion] = []
    var distance: Double? = 0.0
    var resetWhenGoingLive: Bool? = false
}

class SettingsAudioOutputToInputChannelsMap: Codable {
    var channel1: Int = 0
    var channel2: Int = 1
}

class AudioSettings: Codable {
    var audioOutputToInputChannelsMap: SettingsAudioOutputToInputChannelsMap? = .init()
}

class WebBrowserSettings: Codable {
    var home: String = "https://google.com"
}

class DeepLinkCreatorStreamVideo: Codable, ObservableObject {
    @Published var resolution: SettingsStreamResolution = .r1920x1080
    @Published var fps: Int = 30
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
        resolution = container.decode(.resolution, SettingsStreamResolution.self, .r1920x1080)
        fps = container.decode(.fps, Int.self, 30)
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

class DeepLinkCreatorStream: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var name: String = "My stream"
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
        name = container.decode(.name, String.self, "My stream")
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

class SettingsAlertsMediaGalleryItem: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""

    init(name: String) {
        self.name = name
    }
}

private let allBundledAlertsMediaGalleryImages = [
    SettingsAlertsMediaGalleryItem(name: "Moblin pixels"),
    SettingsAlertsMediaGalleryItem(name: "Moblin party"),
    SettingsAlertsMediaGalleryItem(name: "Moblin trillionaire"),
    SettingsAlertsMediaGalleryItem(name: "White star"),
    SettingsAlertsMediaGalleryItem(name: "Angry"),
    SettingsAlertsMediaGalleryItem(name: "Sunglasses"),
    SettingsAlertsMediaGalleryItem(name: "Salty"),
    SettingsAlertsMediaGalleryItem(name: "-100"),
]

private let allBundledAlertsMediaGallerySounds = [
    SettingsAlertsMediaGalleryItem(name: "Notification 2"),
    SettingsAlertsMediaGalleryItem(name: "Boing"),
    SettingsAlertsMediaGalleryItem(name: "Cash register"),
    SettingsAlertsMediaGalleryItem(name: "Dingaling"),
    SettingsAlertsMediaGalleryItem(name: "Level up"),
    SettingsAlertsMediaGalleryItem(name: "Notification"),
    SettingsAlertsMediaGalleryItem(name: "SFX magic"),
    SettingsAlertsMediaGalleryItem(name: "Whoosh"),
    SettingsAlertsMediaGalleryItem(name: "Coin dropping"),
    SettingsAlertsMediaGalleryItem(name: "Fart"),
    SettingsAlertsMediaGalleryItem(name: "Fart 2"),
    SettingsAlertsMediaGalleryItem(name: "Bad chili fart"),
    SettingsAlertsMediaGalleryItem(name: "Perfect fart"),
    SettingsAlertsMediaGalleryItem(name: "Silence"),
]

class SettingsAlertsMediaGallery: Codable {
    var bundledImages = allBundledAlertsMediaGalleryImages
    var customImages: [SettingsAlertsMediaGalleryItem] = []
    var bundledSounds = allBundledAlertsMediaGallerySounds
    var customSounds: [SettingsAlertsMediaGalleryItem] = []
}

class Database: Codable, ObservableObject {
    @Published var streams: [SettingsStream] = []
    @Published var scenes: [SettingsScene] = []
    @Published var widgets: [SettingsWidget] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    var tapToFocus: Bool = false
    @Published var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var batteryPercentage: Bool = true
    var mic: SettingsMic = getDefaultMic()
    var mics: SettingsMics = .init()
    var debug: SettingsDebug = .init()
    var quickButtonsGeneral: SettingsQuickButtons = .init()
    var quickButtons: [SettingsQuickButton] = []
    var rtmpServer: SettingsRtmpServer = .init()
    var networkInterfaceNames: [SettingsNetworkInterfaceName] = []
    var lowBitrateWarning: Bool = true
    var vibrate: Bool = false
    @Published var gameControllers: [SettingsGameController] = [.init()]
    var remoteControl: SettingsRemoteControl = .init()
    var startStopRecordingConfirmations: Bool = true
    var color: SettingsColor = .init()
    var mirrorFrontCameraOnStream: Bool = true
    var streamButtonColor: RgbColor = defaultStreamButtonColor
    var location: SettingsLocation = .init()
    var watch: WatchSettings = .init()
    var audio: AudioSettings = .init()
    var webBrowser: WebBrowserSettings = .init()
    var deepLinkCreator: DeepLinkCreator = .init()
    var srtlaServer: SettingsSrtlaServer = .init()
    var mediaPlayers: SettingsMediaPlayers = .init()
    @Published var showAllSettings: Bool = false
    var portrait: Bool = false
    var djiDevices: SettingsDjiDevices = .init()
    var alertsMediaGallery: SettingsAlertsMediaGallery = .init()
    var catPrinters: SettingsCatPrinters = .init()
    @Published var verboseStatuses: Bool = false
    var scoreboardPlayers: [SettingsWidgetScoreboardPlayer] = .init()
    var keyboard: SettingsKeyboard = .init()
    var tesla: SettingsTesla = .init()
    var srtlaRelay: SettingsMoblink = .init()
    @Published var pixellateStrength: Float = 0.3
    var moblink: SettingsMoblink = .init()
    var sceneSwitchTransition: SettingsSceneSwitchTransition = .blur
    var forceSceneSwitchTransition: Bool = false
    @Published var cameraControlsEnabled: Bool = true
    @Published var externalDisplayContent: SettingsExternalDisplayContent = .stream
    var cyclingPowerDevices: SettingsCyclingPowerDevices = .init()
    var heartRateDevices: SettingsHeartRateDevices = .init()
    var phoneCoolerDevices: SettingsPhoneCoolerDevices = .init()
    var djiGimbalDevices: SettingsDjiGimbalDevices = .init()
    var remoteSceneId: UUID?
    @Published var sceneNumericInput: Bool = false
    var goPro: SettingsGoPro = .init()
    var replay: SettingsReplay = .init()
    var portraitVideoOffsetFromTop: Double = 0.0
    var autoSceneSwitchers: SettingsAutoSceneSwitchers = .init()
    @Published var fixedHorizon: Bool = false
    @Published var whirlpoolAngle: Float = .pi / 2
    @Published var pinchScale: Float = 0.5
    var selfieStick: SettingsSelfieStick = .init()
    @Published var bigButtons: Bool = false

    static func fromString(settings: String) throws -> Database {
        let database = try JSONDecoder().decode(
            Database.self,
            from: settings.data(using: .utf8)!
        )
        if database.zoom.back.isEmpty {
            addDefaultBackZoomPresets(database: database)
        }
        if database.zoom.front.isEmpty {
            addDefaultFrontZoomPresets(database: database)
        }
        if database.bitratePresets.isEmpty {
            addDefaultBitratePresets(database: database)
        }
        addMissingQuickButtons(database: database)
        for button in database.quickButtons where button.type != .interactiveChat && button.type != .cameraPreview {
            button.isOn = false
        }
        addMissingDeepLinkQuickButtons(database: database)
        addMissingBundledLuts(database: database)
        addMissingGoPro(database: database)
        return database
    }

    func toString() throws -> String {
        return try String.fromUtf8(data: JSONEncoder().encode(self))
    }

    enum CodingKeys: CodingKey {
        case streams,
             scenes,
             widgets,
             show,
             zoom,
             tapToFocus,
             bitratePresets,
             iconImage,
             videoStabilizationMode,
             chat,
             batteryPercentage,
             mic,
             mics,
             debug,
             quickButtons,
             globalButtons,
             rtmpServer,
             networkInterfaceNames,
             lowBitrateWarning,
             vibrate,
             gameControllers,
             remoteControl,
             startStopRecordingConfirmations,
             color,
             mirrorFrontCameraOnStream,
             streamButtonColor,
             location,
             watch,
             audio,
             webBrowser,
             deepLinkCreator,
             srtlaServer,
             mediaPlayers,
             showAllSettings,
             portrait,
             djiDevices,
             alertsMediaGallery,
             catPrinters,
             verboseStatuses,
             scoreboardPlayers,
             keyboard,
             tesla,
             srtlaRelay,
             pixellateStrength,
             moblink,
             sceneSwitchTransition,
             forceSceneSwitchTransition,
             cameraControlsEnabled,
             externalDisplayContent,
             cyclingPowerDevices,
             heartRateDevices,
             djiGimbalDevices,
             phoneCoolerDevices,
             remoteSceneId,
             sceneNumericInput,
             goPro,
             replay,
             portraitVideoOffsetFromTop,
             autoSceneSwitchers,
             fixedHorizon,
             whirlpoolAngle,
             pinchScale,
             selfieStick,
             bigButtons
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
        try container.encode(.scenes, scenes)
        try container.encode(.widgets, widgets)
        try container.encode(.show, show)
        try container.encode(.zoom, zoom)
        try container.encode(.tapToFocus, tapToFocus)
        try container.encode(.bitratePresets, bitratePresets)
        try container.encode(.iconImage, iconImage)
        try container.encode(.videoStabilizationMode, videoStabilizationMode)
        try container.encode(.chat, chat)
        try container.encode(.batteryPercentage, batteryPercentage)
        try container.encode(.mic, mic)
        try container.encode(.mics, mics)
        try container.encode(.debug, debug)
        try container.encode(.quickButtons, quickButtonsGeneral)
        try container.encode(.globalButtons, quickButtons)
        try container.encode(.rtmpServer, rtmpServer)
        try container.encode(.networkInterfaceNames, networkInterfaceNames)
        try container.encode(.lowBitrateWarning, lowBitrateWarning)
        try container.encode(.vibrate, vibrate)
        try container.encode(.gameControllers, gameControllers)
        try container.encode(.remoteControl, remoteControl)
        try container.encode(.startStopRecordingConfirmations, startStopRecordingConfirmations)
        try container.encode(.color, color)
        try container.encode(.mirrorFrontCameraOnStream, mirrorFrontCameraOnStream)
        try container.encode(.streamButtonColor, streamButtonColor)
        try container.encode(.location, location)
        try container.encode(.watch, watch)
        try container.encode(.audio, audio)
        try container.encode(.webBrowser, webBrowser)
        try container.encode(.deepLinkCreator, deepLinkCreator)
        try container.encode(.srtlaServer, srtlaServer)
        try container.encode(.mediaPlayers, mediaPlayers)
        try container.encode(.showAllSettings, showAllSettings)
        try container.encode(.portrait, portrait)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.alertsMediaGallery, alertsMediaGallery)
        try container.encode(.catPrinters, catPrinters)
        try container.encode(.verboseStatuses, verboseStatuses)
        try container.encode(.scoreboardPlayers, scoreboardPlayers)
        try container.encode(.keyboard, keyboard)
        try container.encode(.tesla, tesla)
        try container.encode(.srtlaRelay, srtlaRelay)
        try container.encode(.pixellateStrength, pixellateStrength)
        try container.encode(.moblink, moblink)
        try container.encode(.sceneSwitchTransition, sceneSwitchTransition)
        try container.encode(.forceSceneSwitchTransition, forceSceneSwitchTransition)
        try container.encode(.cameraControlsEnabled, cameraControlsEnabled)
        try container.encode(.externalDisplayContent, externalDisplayContent)
        try container.encode(.cyclingPowerDevices, cyclingPowerDevices)
        try container.encode(.heartRateDevices, heartRateDevices)
        try container.encode(.djiGimbalDevices, djiGimbalDevices)
        try container.encode(.phoneCoolerDevices, phoneCoolerDevices)
        try container.encode(.remoteSceneId, remoteSceneId)
        try container.encode(.sceneNumericInput, sceneNumericInput)
        try container.encode(.goPro, goPro)
        try container.encode(.replay, replay)
        try container.encode(.portraitVideoOffsetFromTop, portraitVideoOffsetFromTop)
        try container.encode(.autoSceneSwitchers, autoSceneSwitchers)
        try container.encode(.fixedHorizon, fixedHorizon)
        try container.encode(.whirlpoolAngle, whirlpoolAngle)
        try container.encode(.pinchScale, pinchScale)
        try container.encode(.selfieStick, selfieStick)
        try container.encode(.bigButtons, bigButtons)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsStream].self, [])
        scenes = container.decode(.scenes, [SettingsScene].self, [])
        widgets = container.decode(.widgets, [SettingsWidget].self, [])
        show = container.decode(.show, SettingsShow.self, .init())
        zoom = container.decode(.zoom, SettingsZoom.self, .init())
        tapToFocus = container.decode(.tapToFocus, Bool.self, false)
        bitratePresets = container.decode(.bitratePresets, [SettingsBitratePreset].self, [])
        iconImage = container.decode(.iconImage, String.self, plainIcon.image())
        videoStabilizationMode = container.decode(.videoStabilizationMode, SettingsVideoStabilizationMode.self, .off)
        chat = container.decode(.chat, SettingsChat.self, .init())
        batteryPercentage = container.decode(.batteryPercentage, Bool.self, true)
        mic = container.decode(.mic, SettingsMic.self, getDefaultMic())
        mics = container.decode(.mics, SettingsMics.self, .init())
        debug = container.decode(.debug, SettingsDebug.self, .init())
        quickButtonsGeneral = container.decode(.quickButtons, SettingsQuickButtons.self, .init())
        quickButtons = container.decode(.globalButtons, [SettingsQuickButton].self, [])
        rtmpServer = container.decode(.rtmpServer, SettingsRtmpServer.self, .init())
        networkInterfaceNames = container.decode(.networkInterfaceNames, [SettingsNetworkInterfaceName].self, [])
        lowBitrateWarning = container.decode(.lowBitrateWarning, Bool.self, true)
        vibrate = container.decode(.vibrate, Bool.self, false)
        gameControllers = container.decode(.gameControllers, [SettingsGameController].self, [.init()])
        remoteControl = container.decode(.remoteControl, SettingsRemoteControl.self, .init())
        startStopRecordingConfirmations = container.decode(.startStopRecordingConfirmations, Bool.self, true)
        color = container.decode(.color, SettingsColor.self, .init())
        mirrorFrontCameraOnStream = container.decode(.mirrorFrontCameraOnStream, Bool.self, true)
        streamButtonColor = container.decode(.streamButtonColor, RgbColor.self, defaultStreamButtonColor)
        location = container.decode(.location, SettingsLocation.self, .init())
        watch = container.decode(.watch, WatchSettings.self, .init())
        audio = container.decode(.audio, AudioSettings.self, .init())
        webBrowser = container.decode(.webBrowser, WebBrowserSettings.self, .init())
        deepLinkCreator = container.decode(.deepLinkCreator, DeepLinkCreator.self, .init())
        srtlaServer = container.decode(.srtlaServer, SettingsSrtlaServer.self, .init())
        mediaPlayers = container.decode(.mediaPlayers, SettingsMediaPlayers.self, .init())
        showAllSettings = container.decode(.showAllSettings, Bool.self, false)
        portrait = container.decode(.portrait, Bool.self, false)
        djiDevices = container.decode(.djiDevices, SettingsDjiDevices.self, .init())
        alertsMediaGallery = container.decode(.alertsMediaGallery, SettingsAlertsMediaGallery.self, .init())
        catPrinters = container.decode(.catPrinters, SettingsCatPrinters.self, .init())
        verboseStatuses = container.decode(.verboseStatuses, Bool.self, false)
        scoreboardPlayers = container.decode(.scoreboardPlayers, [SettingsWidgetScoreboardPlayer].self, .init())
        keyboard = container.decode(.keyboard, SettingsKeyboard.self, .init())
        tesla = container.decode(.tesla, SettingsTesla.self, .init())
        srtlaRelay = container.decode(.srtlaRelay, SettingsMoblink.self, .init())
        pixellateStrength = container.decode(.pixellateStrength, Float.self, 0.3)
        moblink = container.decode(.moblink, SettingsMoblink.self, srtlaRelay)
        sceneSwitchTransition = container.decode(.sceneSwitchTransition, SettingsSceneSwitchTransition.self, .blur)
        forceSceneSwitchTransition = container.decode(.forceSceneSwitchTransition, Bool.self, false)
        cameraControlsEnabled = container.decode(.cameraControlsEnabled, Bool.self, true)
        externalDisplayContent = container.decode(.externalDisplayContent, SettingsExternalDisplayContent.self, .stream)
        cyclingPowerDevices = container.decode(.cyclingPowerDevices, SettingsCyclingPowerDevices.self, .init())
        heartRateDevices = container.decode(.heartRateDevices, SettingsHeartRateDevices.self, .init())
        djiGimbalDevices = container.decode(.djiGimbalDevices, SettingsDjiGimbalDevices.self, .init())
        phoneCoolerDevices = container.decode(.phoneCoolerDevices, SettingsPhoneCoolerDevices.self, .init())
        remoteSceneId = try? container.decode(UUID?.self, forKey: .remoteSceneId)
        sceneNumericInput = container.decode(.sceneNumericInput, Bool.self, false)
        goPro = container.decode(.goPro, SettingsGoPro.self, .init())
        replay = container.decode(.replay, SettingsReplay.self, .init())
        portraitVideoOffsetFromTop = container.decode(.portraitVideoOffsetFromTop, Double.self, 0.0)
        autoSceneSwitchers = container.decode(.autoSceneSwitchers, SettingsAutoSceneSwitchers.self, .init())
        fixedHorizon = container.decode(.fixedHorizon, Bool.self, false)
        whirlpoolAngle = container.decode(.whirlpoolAngle, Float.self, .pi / 2)
        pinchScale = container.decode(.pinchScale, Float.self, 0.5)
        selfieStick = container.decode(.selfieStick, SettingsSelfieStick.self, .init())
        bigButtons = container.decode(.bigButtons, Bool.self, false)
    }
}

private func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.cameraPosition = .back
    scene.backCameraId = getBestBackCameraId()
    database.scenes.append(scene)

    scene = SettingsScene(name: String(localized: "Front"))
    scene.cameraPosition = .front
    scene.frontCameraId = getBestFrontCameraId()
    database.scenes.append(scene)
}

private func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

private func addDefaultBackZoomPresets(database: Database) {
    if let device = getBestBackCameraDevice() {
        let hasUltraWideCamera = hasUltraWideBackCamera()
        let scale = device.getZoomFactorScale(hasUltraWideCamera: hasUltraWideCamera)
        var xs: [Float] = []
        if hasUltraWideCamera {
            xs.append(0.5)
        } else {
            xs.append(1.0)
        }
        for factor in device.virtualDeviceSwitchOverVideoZoomFactors {
            let x = (Float(truncating: factor) * scale).rounded()
            if let prevX = xs.last {
                if (x / prevX) >= 4 {
                    xs.append(2 * prevX)
                }
            }
            xs.append(x)
        }
        xs.append(2 * xs.last!)
        database.zoom.back = []
        for x in xs {
            let nameX = x < 1 ? formatOneDecimal(x) : String(Int(x))
            database.zoom.back.append(SettingsZoomPreset(
                id: UUID(),
                name: "\(nameX)x",
                level: 2.0 * x,
                x: x
            ))
        }
    } else {
        database.zoom.back = [
            SettingsZoomPreset(id: UUID(), name: "0.5x", level: 1.0, x: 0.5),
            SettingsZoomPreset(id: UUID(), name: "1x", level: 2.0, x: 1.0),
            SettingsZoomPreset(id: UUID(), name: "2x", level: 4.0, x: 2.0),
            SettingsZoomPreset(id: UUID(), name: "4x", level: 8.0, x: 4.0),
            SettingsZoomPreset(id: UUID(), name: "8x", level: 16.0, x: 8.0),
        ]
    }
}

private func addDefaultFrontZoomPresets(database: Database) {
    database.zoom.front = [
        SettingsZoomPreset(id: UUID(), name: "0.5x", level: 0.5, x: 0.5),
        SettingsZoomPreset(id: UUID(), name: "1x", level: 1.0, x: 1.0),
        SettingsZoomPreset(id: UUID(), name: "2x", level: 2.0, x: 2.0),
        SettingsZoomPreset(id: UUID(), name: "4x", level: 4.0, x: 4.0),
        SettingsZoomPreset(id: UUID(), name: "8x", level: 8.0, x: 8.0),
    ]
}

private func addDefaultBitratePresets(database: Database) {
    database.bitratePresets = [
        SettingsBitratePreset(id: UUID(), bitrate: 15_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 12_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 9_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 7_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 6_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 4_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 2_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
    ]
}

private func updateQuickButton(database: Database, button: SettingsQuickButton) {
    let existingButton = database.quickButtons.first(where: { globalButton in
        globalButton.type == button.type
    })
    if let existingButton {
        existingButton.name = button.name
        existingButton.systemImageNameOn = button.systemImageNameOn
        existingButton.systemImageNameOff = button.systemImageNameOff
    } else {
        database.quickButtons.append(button)
    }
}

private func quickButtonPageTwo() -> Int {
    if #available(iOS 17, *) {
        return 2
    } else {
        return 1
    }
}

private func addMissingQuickButtons(database: Database) {
    var button = SettingsQuickButton(name: String(localized: "Torch"))
    button.id = UUID()
    button.type = .torch
    button.imageType = "System name"
    button.systemImageNameOn = "flashlight.on.fill"
    button.systemImageNameOff = "flashlight.off.fill"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Mute"))
    button.id = UUID()
    button.type = .mute
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Bitrate"))
    button.id = UUID()
    button.type = .bitrate
    button.imageType = "System name"
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Mic"))
    button.id = UUID()
    button.type = .mic
    button.imageType = "System name"
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Chat"))
    button.id = UUID()
    button.type = .chat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Interactive chat"))
    button.id = UUID()
    button.type = .interactiveChat
    button.imageType = "System name"
    button.systemImageNameOn = "arrow.up.message.fill"
    button.systemImageNameOff = "arrow.up.message"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stealth mode"))
    button.id = UUID()
    button.type = .blackScreen
    button.imageType = "System name"
    button.systemImageNameOn = "sunset.fill"
    button.systemImageNameOff = "sunset"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Lock screen"))
    button.id = UUID()
    button.type = .lockScreen
    button.imageType = "System name"
    button.systemImageNameOn = "lock.fill"
    button.systemImageNameOff = "lock"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Record"))
    button.id = UUID()
    button.type = .record
    button.imageType = "System name"
    button.systemImageNameOn = "record.circle.fill"
    button.systemImageNameOff = "record.circle"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stream"))
    button.id = UUID()
    button.type = .stream
    button.imageType = "System name"
    button.systemImageNameOn = "dot.radiowaves.left.and.right"
    button.systemImageNameOff = "dot.radiowaves.left.and.right"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Recordings"))
    button.id = UUID()
    button.type = .recordings
    button.imageType = "System name"
    button.systemImageNameOn = "photo.on.rectangle.angled.fill"
    button.systemImageNameOff = "photo.on.rectangle.angled"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Snapshot"))
    button.id = UUID()
    button.type = .snapshot
    button.imageType = "System name"
    button.systemImageNameOn = "camera.aperture"
    button.systemImageNameOff = "camera.aperture"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Replay"))
    button.id = UUID()
    button.type = .replay
    button.imageType = "System name"
    button.systemImageNameOn = "play.fill"
    button.systemImageNameOff = "play"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Instant replay"))
    button.id = UUID()
    button.type = .instantReplay
    button.imageType = "System name"
    button.systemImageNameOn = "memories"
    button.systemImageNameOff = "memories"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "OBS"))
    button.id = UUID()
    button.type = .obs
    button.imageType = "System name"
    button.systemImageNameOn = "xserve"
    button.systemImageNameOff = "xserve"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Remote"))
    button.id = UUID()
    button.type = .remote
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Widgets"))
    button.id = UUID()
    button.type = .widgets
    button.imageType = "System name"
    button.systemImageNameOn = "photo.on.rectangle.fill"
    button.systemImageNameOff = "photo.on.rectangle"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Auto scene switcher"))
    button.id = UUID()
    button.type = .autoSceneSwitcher
    button.imageType = "System name"
    button.systemImageNameOn = "autostartstop"
    button.systemImageNameOff = "autostartstop"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Draw"))
    button.id = UUID()
    button.type = .draw
    button.imageType = "System name"
    button.systemImageNameOn = "pencil.line"
    button.systemImageNameOff = "pencil.line"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Camera"))
    button.id = UUID()
    button.type = .image
    button.imageType = "System name"
    button.systemImageNameOn = "camera.fill"
    button.systemImageNameOff = "camera"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Browser"))
    button.id = UUID()
    button.type = .browser
    button.imageType = "System name"
    button.systemImageNameOn = "globe"
    button.systemImageNameOff = "globe"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Grid"))
    button.id = UUID()
    button.type = .grid
    button.imageType = "System name"
    button.systemImageNameOn = "grid"
    button.systemImageNameOff = "grid"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Face"))
    button.id = UUID()
    button.type = .face
    button.imageType = "System name"
    button.systemImageNameOn = "theatermask.and.paintbrush.fill"
    button.systemImageNameOff = "theatermask.and.paintbrush"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Movie"))
    button.id = UUID()
    button.type = .movie
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "4:3"))
    button.id = UUID()
    button.type = .fourThree
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "square.fill"
    button.systemImageNameOff = "square"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Gray scale"))
    button.id = UUID()
    button.type = .grayScale
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Sepia"))
    button.id = UUID()
    button.type = .sepia
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent.inverse"
    button.systemImageNameOff = "moonphase.waning.crescent"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Triple"))
    button.id = UUID()
    button.type = .triple
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "person.3.fill"
    button.systemImageNameOff = "person.3"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Twin"))
    button.id = UUID()
    button.type = .twin
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "person.2.fill"
    button.systemImageNameOff = "person.2"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pixellate"))
    button.id = UUID()
    button.type = .pixellate
    button.imageType = "System name"
    button.systemImageNameOn = "squareshape.split.2x2"
    button.systemImageNameOff = "squareshape.split.2x2"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Whirlpool"))
    button.id = UUID()
    button.type = .whirlpool
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "tornado"
    button.systemImageNameOff = "tornado"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pinch"))
    button.id = UUID()
    button.type = .pinch
    button.page = quickButtonPageTwo()
    button.imageType = "System name"
    button.systemImageNameOn = "hand.pinch.fill"
    button.systemImageNameOff = "hand.pinch"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Local overlays"))
    button.id = UUID()
    button.type = .localOverlays
    button.imageType = "System name"
    button.systemImageNameOn = "square.stack.3d.up.slash.fill"
    button.systemImageNameOff = "square.stack.3d.up.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Poll"))
    button.id = UUID()
    button.type = .poll
    button.imageType = "System name"
    button.systemImageNameOn = "chart.bar.xaxis"
    button.systemImageNameOff = "chart.bar.xaxis"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "LUTs"))
    button.id = UUID()
    button.type = .luts
    button.imageType = "System name"
    button.systemImageNameOn = "camera.filters"
    button.systemImageNameOff = "camera.filters"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Workout"))
    button.id = UUID()
    button.type = .workout
    button.imageType = "System name"
    button.systemImageNameOn = "figure.run"
    button.systemImageNameOff = "figure.run"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Skip current TTS"))
    button.id = UUID()
    button.type = .skipCurrentTts
    button.imageType = "System name"
    button.systemImageNameOn = "waveform.slash"
    button.systemImageNameOff = "waveform.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pause TTS"))
    button.id = UUID()
    button.type = .pauseTts
    button.imageType = "System name"
    button.systemImageNameOn = "waveform.badge.xmark"
    button.systemImageNameOff = "waveform.badge.xmark"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Ads"))
    button.id = UUID()
    button.type = .ads
    button.imageType = "System name"
    button.systemImageNameOn = "cup.and.saucer.fill"
    button.systemImageNameOff = "cup.and.saucer"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stream marker"))
    button.id = UUID()
    button.type = .streamMarker
    button.imageType = "System name"
    button.systemImageNameOn = "bookmark.fill"
    button.systemImageNameOff = "bookmark"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Reload browser widgets"))
    button.id = UUID()
    button.type = .reloadBrowserWidgets
    button.imageType = "System name"
    button.systemImageNameOn = "arrow.clockwise"
    button.systemImageNameOff = "arrow.clockwise"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "DJI devices"))
    button.id = UUID()
    button.type = .djiDevices
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "GoPro"))
    button.id = UUID()
    button.type = .goPro
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Camera preview"))
    button.id = UUID()
    button.type = .cameraPreview
    button.imageType = "System name"
    button.systemImageNameOn = "camera.rotate.fill"
    button.systemImageNameOff = "camera.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Portrait"))
    button.id = UUID()
    button.type = .portrait
    button.imageType = "System name"
    button.systemImageNameOn = "rectangle.portrait.rotate"
    button.systemImageNameOff = "rectangle.portrait.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Connection priorities"))
    button.id = UUID()
    button.type = .connectionPriorities
    button.imageType = "System name"
    button.systemImageNameOn = "phone.connection.fill"
    button.systemImageNameOff = "phone.connection"
    updateQuickButton(database: database, button: button)

    database.quickButtons = database.quickButtons.filter { button in
        if button.type == .unknown {
            return false
        }
        if button.type == .workout, !isPhone() {
            return false
        }
        if button.type == .portrait, isMac() {
            return false
        }
        return true
    }
}

private func addMissingDeepLinkQuickButtons(database: Database) {
    let quickButtons = database.deepLinkCreator.quickButtons
    for quickButton in database.quickButtons where quickButton.type != .lut {
        let button = DeepLinkCreatorQuickButton()
        let buttonExists = quickButtons.buttons.contains(where: { button in
            quickButton.type == button.type
        })
        if !buttonExists {
            button.type = quickButton.type
            quickButtons.buttons.append(button)
        }
    }
    quickButtons.buttons = quickButtons.buttons.filter { button in
        button.type != .unknown
    }
}

private func addMissingBundledLuts(database: Database) {
    var bundledLuts: [SettingsColorLut] = []
    for lut in allBundledLuts {
        if let existingLut = database.color.bundledLuts.first(where: { $0.name == lut.name }) {
            bundledLuts.append(existingLut)
        } else {
            bundledLuts.append(lut)
        }
    }
    database.color.bundledLuts = bundledLuts
}

private func addMissingGoPro(database: Database) {
    let goPro = database.goPro
    if goPro.launchLiveStream.isEmpty {
        goPro.launchLiveStream = [.init()]
        goPro.selectedLaunchLiveStream = goPro.launchLiveStream.first?.id
    }
}

private func updateBundledAlertsMediaGallery(database: Database) {
    var bundledImages: [SettingsAlertsMediaGalleryItem] = []
    for image in allBundledAlertsMediaGalleryImages {
        if let existingImage = database.alertsMediaGallery.bundledImages
            .first(where: { $0.name == image.name })
        {
            bundledImages.append(existingImage)
        } else {
            bundledImages.append(image)
        }
    }
    database.alertsMediaGallery.bundledImages = bundledImages
    var bundledSounds: [SettingsAlertsMediaGalleryItem] = []
    for sound in allBundledAlertsMediaGallerySounds {
        if let existingSound = database.alertsMediaGallery.bundledSounds
            .first(where: { $0.name == sound.name })
        {
            bundledSounds.append(existingSound)
        } else {
            bundledSounds.append(sound)
        }
    }
    database.alertsMediaGallery.bundledSounds = bundledSounds
}

private func addScenesToGameController(database: Database) {
    var button = database.gameControllers[0].buttons[0]
    button.function = .scene
    button.sceneId = database.scenes[0].id
    button = database.gameControllers[0].buttons[1]
    button.function = .scene
    button.sceneId = database.scenes[1].id
}

private func getDefaultMic() -> SettingsMic {
    if isMac() {
        return .bottom
    }
    let session = AVAudioSession.sharedInstance()
    for inputPort in session.availableInputs ?? [] {
        if inputPort.portType != .builtInMic {
            continue
        }
        if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
            for dataSource in dataSources {
                if dataSource.orientation == .bottom {
                    return .bottom
                } else if dataSource.orientation == .top {
                    return .top
                }
            }
        }
    }
    return .bottom
}

private func createDefault() -> Database {
    let database = Database()
    addDefaultScenes(database: database)
    addDefaultZoomPresets(database: database)
    addDefaultBitratePresets(database: database)
    addMissingQuickButtons(database: database)
    addMissingDeepLinkQuickButtons(database: database)
    addScenesToGameController(database: database)
    addMissingBundledLuts(database: database)
    return database
}

final class Settings {
    private var realDatabase = Database()
    var database: Database {
        realDatabase
    }

    @AppStorage("settings") var storage = ""

    func load() -> Bool {
        do {
            try tryLoadAndMigrate(settings: storage)
            return true
        } catch {
            logger.info("settings: Failed to load with error \(error). Using default.")
            realDatabase = createDefault()
            return storage.isEmpty
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try Database.fromString(settings: settings)
        addSensitiveData(database: realDatabase)
        migrateFromOlderVersions()
    }

    func store() {
        do {
            let database = extractSensitiveData(fromDatabase: realDatabase)
            storage = try realDatabase.toString()
            insertSensitiveData(toDatabase: realDatabase, fromDatabase: database)
        } catch {
            logger.error("settings: Failed to store.")
        }
    }

    func reset() {
        realDatabase = createDefault()
        store()
    }

    func importFromClipboard() -> String? {
        guard let settings = UIPasteboard.general.string else {
            return String(localized: "Empty clipboard")
        }
        do {
            try tryLoadAndMigrate(settings: settings)
        } catch {
            return String(localized: "Malformed settings")
        }
        store()
        return nil
    }

    func exportToClipboard() {
        UIPasteboard.general.string = storage
    }

    private func addSensitiveData(database: Database) {
        for stream in database.streams {
            if let accessToken = loadTwitchAccessTokenFromKeychain(streamId: stream.id) {
                stream.twitchAccessToken = accessToken
            }
        }
    }

    private func extractSensitiveData(fromDatabase: Database) -> Database {
        let toDatabase = Database()
        for fromStream in fromDatabase.streams {
            let toStream = SettingsStream(name: "")
            toStream.twitchAccessToken = fromStream.twitchAccessToken
            fromStream.twitchAccessToken = ""
            toDatabase.streams.append(toStream)
        }
        return toDatabase
    }

    private func insertSensitiveData(toDatabase: Database, fromDatabase: Database) {
        for (index, fromStream) in fromDatabase.streams.enumerated() where index < toDatabase.streams.count {
            toDatabase.streams[index].twitchAccessToken = fromStream.twitchAccessToken
        }
    }

    private func migrateFromOlderVersions() {
        if realDatabase.zoom.speed == nil {
            realDatabase.zoom.speed = 5.0
            store()
        }
        for preset in realDatabase.zoom.back where preset.x == nil {
            preset.x = preset.level / 2
            store()
        }
        for preset in realDatabase.zoom.front where preset.x == nil {
            preset.x = preset.level
            store()
        }
        if realDatabase.zoom.switchToBack.x == nil {
            realDatabase.zoom.switchToBack.x = realDatabase.zoom.switchToBack.level / 2
            store()
        }
        if realDatabase.zoom.switchToFront.x == nil {
            realDatabase.zoom.switchToFront.x = realDatabase.zoom.switchToFront.level / 2
            store()
        }
        for stream in realDatabase.rtmpServer.streams where stream.latency == nil {
            stream.latency = defaultRtmpLatency
            store()
        }
        for button in realDatabase.quickButtons where button.type == .image {
            if button.name != String(localized: "Camera") {
                button.name = String(localized: "Camera")
                store()
            }
            if button.systemImageNameOn != "camera.fill" {
                button.systemImageNameOn = "camera.fill"
                store()
            }
            if button.systemImageNameOff != "camera" {
                button.systemImageNameOff = "camera"
                store()
            }
        }
        for stream in realDatabase.streams where stream.srt.connectionPriorities == nil {
            stream.srt.connectionPriorities = .init()
            store()
        }
        for stream in realDatabase.streams where stream.srt.overheadBandwidth == nil {
            stream.srt.overheadBandwidth = realDatabase.debug.srtOverheadBandwidth
            store()
        }
        for stream in realDatabase.streams where stream.srt.maximumBandwidthFollowInput == nil {
            stream.srt.maximumBandwidthFollowInput = realDatabase.debug.maximumBandwidthFollowInput
            store()
        }
        for stream in realDatabase.streams where stream.srt.adaptiveBitrate == nil {
            stream.srt.adaptiveBitrate = .init()
            store()
        }
        if realDatabase.remoteControl.password == nil {
            realDatabase.remoteControl.password = randomGoodPassword()
            store()
        }
        for stream in realDatabase.streams {
            for priority in stream.srt.connectionPriorities!.priorities where priority.enabled == nil {
                priority.enabled = true
                store()
            }
        }
        if realDatabase.color.diskLuts == nil {
            realDatabase.color.diskLuts = []
            store()
        }
        for stream in database.streams where stream.srt.adaptiveBitrate!.fastIrlSettings == nil {
            stream.srt.adaptiveBitrate!.fastIrlSettings = .init()
            store()
        }
        for stream in database.streams where stream.srt.adaptiveBitrateEnabled == nil {
            stream.srt.adaptiveBitrateEnabled = stream.adaptiveBitrate
            store()
        }
        for stream in realDatabase.streams where stream.recording.autoStartRecording == nil {
            stream.recording.autoStartRecording = false
            store()
        }
        for stream in realDatabase.streams where stream.recording.autoStopRecording == nil {
            stream.recording.autoStopRecording = false
            store()
        }
        for stream in realDatabase.streams where stream.recording.audioBitrate == nil {
            stream.recording.audioBitrate = 128_000
            store()
        }
        var videoEffectWidgets: [SettingsWidget] = []
        for widget in realDatabase.widgets where widget.type == .videoEffect {
            videoEffectWidgets.append(widget)
        }
        if !videoEffectWidgets.isEmpty {
            realDatabase.widgets = realDatabase.widgets.filter { widget in
                !videoEffectWidgets.contains(widget)
            }
            for scene in realDatabase.scenes {
                scene.widgets = scene.widgets.filter { widget in
                    !videoEffectWidgets.contains { videoEffectWidget in
                        videoEffectWidget.id == widget.widgetId
                    }
                }
            }
            store()
        }
        for stream in realDatabase.streams
            where stream.srt.adaptiveBitrate!.customSettings.minimumBitrate == nil
        {
            stream.srt.adaptiveBitrate!.customSettings.minimumBitrate = 250
            store()
        }
        for stream in realDatabase.streams
            where stream.srt.adaptiveBitrate!.fastIrlSettings!.minimumBitrate == nil
        {
            stream.srt.adaptiveBitrate!.fastIrlSettings!.minimumBitrate = 250
            store()
        }
        for stream in realDatabase.rtmpServer.streams where stream.autoSelectMic == nil {
            stream.autoSelectMic = true
            store()
        }
        for stream in realDatabase.srtlaServer.streams where stream.autoSelectMic == nil {
            stream.autoSelectMic = true
            store()
        }
        if realDatabase.remoteControl.server.previewFps == nil {
            realDatabase.remoteControl.server.previewFps = 1.0
            store()
        }
        for stream in realDatabase.streams where stream.srt.adaptiveBitrate!.belaboxSettings == nil {
            stream.srt.adaptiveBitrate!.belaboxSettings = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.map.northUp == nil {
            widget.map.northUp = false
            store()
        }
        for widget in database.widgets where widget.map.delay == nil {
            widget.map.delay = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.alerts.twitch == nil {
            widget.alerts.twitch = .init()
            store()
        }
        for widget in realDatabase.widgets {
            if widget.alerts.twitch!.follows.textToSpeechEnabled == nil {
                widget.alerts.twitch!.follows.textToSpeechEnabled = true
                store()
            }
            if widget.alerts.twitch!.follows.textToSpeechDelay == nil {
                widget.alerts.twitch!.follows.textToSpeechDelay = 1.5
                store()
            }
            if widget.alerts.twitch!.follows.textToSpeechLanguageVoices == nil {
                widget.alerts.twitch!.follows.textToSpeechLanguageVoices = .init()
                store()
            }
            if widget.alerts.twitch!.follows.imageLoopCount == nil {
                widget.alerts.twitch!.follows.imageLoopCount = 1
                store()
            }
            if widget.alerts.twitch!.follows.positionType == nil {
                widget.alerts.twitch!.follows.positionType = .scene
                store()
            }
            if widget.alerts.twitch!.follows.facePosition == nil {
                widget.alerts.twitch!.follows.facePosition = .init()
                store()
            }
            if widget.alerts.twitch!.subscriptions.textToSpeechEnabled == nil {
                widget.alerts.twitch!.subscriptions.textToSpeechEnabled = true
                store()
            }
            if widget.alerts.twitch!.subscriptions.textToSpeechDelay == nil {
                widget.alerts.twitch!.subscriptions.textToSpeechDelay = 1.5
                store()
            }
            if widget.alerts.twitch!.subscriptions.textToSpeechLanguageVoices == nil {
                widget.alerts.twitch!.subscriptions.textToSpeechLanguageVoices = .init()
                store()
            }
            if widget.alerts.twitch!.subscriptions.imageLoopCount == nil {
                widget.alerts.twitch!.subscriptions.imageLoopCount = 1
                store()
            }
            if widget.alerts.twitch!.subscriptions.positionType == nil {
                widget.alerts.twitch!.subscriptions.positionType = .scene
                store()
            }
            if widget.alerts.twitch!.subscriptions.facePosition == nil {
                widget.alerts.twitch!.subscriptions.facePosition = .init()
                store()
            }
        }
        updateBundledAlertsMediaGallery(database: realDatabase)
        for widget in realDatabase.widgets where widget.map.migrated == nil {
            widget.map.migrated = false
            store()
        }
        for widget in realDatabase.widgets where !widget.map.migrated! {
            widget.map.migrated = true
            let stream = realDatabase.streams.first(where: { $0.enabled }) ?? SettingsStream(name: "")
            if widget.type == .map {
                for scene in realDatabase.scenes {
                    for sceneWidget in scene.widgets where sceneWidget.widgetId == widget.id {
                        var width: Double
                        var height: Double
                        switch stream.resolution {
                        case .r3840x2160:
                            width = 3840
                            height = 2160
                        case .r2560x1440:
                            width = 2560
                            height = 1440
                        case .r1920x1080:
                            width = 1920
                            height = 1080
                        case .r1280x720:
                            width = 1280
                            height = 720
                        case .r854x480:
                            width = 854
                            height = 480
                        case .r640x360:
                            width = 640
                            height = 360
                        case .r426x240:
                            width = 426
                            height = 240
                        }
                        sceneWidget.width = (100 * Double(widget.map.width) / width)
                            .clamped(to: 1 ... 100)
                        sceneWidget.height = (100 * Double(widget.map.height) / height)
                            .clamped(to: 1 ... 100)
                    }
                }
            }
            store()
        }
        for widget in realDatabase.widgets where widget.alerts.chatBot == nil {
            widget.alerts.chatBot = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.alert == nil {
            realDatabase.chat.botCommandPermissions.alert = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.fax == nil {
            realDatabase.chat.botCommandPermissions.fax = .init()
            store()
        }
        let allLuts = realDatabase.color.bundledLuts + (realDatabase.color.diskLuts ?? [])
        for lut in allLuts where lut.enabled == nil {
            if let button = realDatabase.quickButtons.first(where: { $0.id == lut.buttonId }) {
                lut.enabled = button.isOn
            } else {
                lut.enabled = false
            }
            store()
        }
        let newButtons = realDatabase.quickButtons.filter { $0.type != .lut }
        if realDatabase.quickButtons.count != newButtons.count {
            realDatabase.quickButtons = newButtons
            store()
        }
        for widget in database.widgets where widget.alerts.twitch!.raids == nil {
            widget.alerts.twitch!.raids = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.tts.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions.tts.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.fix.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions.fix.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.map.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions.map.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.alert!.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions.alert!.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.fax!.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions.fax!.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.snapshot == nil {
            realDatabase.chat.botCommandPermissions.snapshot = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.filter == nil {
            realDatabase.chat.botCommandPermissions.filter = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.tts.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.tts.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.fix.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.fix.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.map.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.map.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.alert!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.alert!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.fax!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.fax!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.snapshot!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.snapshot!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.filter!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions.filter!.minimumSubscriberTier = 1
            store()
        }
        for widget in database.widgets where widget.alerts.twitch!.cheers == nil {
            widget.alerts.twitch!.cheers = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropX > 1.0 {
            widget.videoSource.cropX = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropY > 1.0 {
            widget.videoSource.cropY = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropWidth > 1.0 {
            widget.videoSource.cropWidth = 1.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropHeight > 1.0 {
            widget.videoSource.cropHeight = 1.0
            store()
        }
        for widget in database.widgets where widget.alerts.twitch!.cheerBits == nil {
            widget.alerts.twitch!.cheerBits = createDefaultCheerBits()
            widget.alerts.twitch!.cheerBits![0].alert = widget.alerts.twitch!.cheers!.clone()
            store()
        }
        if realDatabase.remoteControl.client.relay == nil {
            realDatabase.remoteControl.client.relay = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.tesla == nil {
            realDatabase.chat.botCommandPermissions.tesla = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.audio == nil {
            realDatabase.chat.botCommandPermissions.audio = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.alerts.speechToText == nil {
            widget.alerts.speechToText = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.alerts.needsSubtitles == nil {
            widget.alerts.needsSubtitles = false
            store()
        }
        for stream in realDatabase.streams where stream.srt.dnsLookupStrategy == nil {
            stream.srt.dnsLookupStrategy = .system
            store()
        }
        if realDatabase.color.diskLutsPng == nil {
            realDatabase.color.diskLutsPng = realDatabase.color.diskLuts
            store()
        }
        if realDatabase.color.diskLutsCube == nil {
            realDatabase.color.diskLutsCube = []
            store()
        }
        for key in realDatabase.keyboard.keys where key.widgetId == nil {
            key.widgetId = .init()
            store()
        }
        if realDatabase.location.distance == nil {
            realDatabase.location.distance = 0.0
            store()
        }
        for stream in realDatabase.streams where stream.recording.cleanRecordings == nil {
            stream.recording.cleanRecordings = false
            store()
        }
        for stream in realDatabase.streams where stream.recording.cleanSnapshots == nil {
            stream.recording.cleanSnapshots = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.reaction == nil {
            realDatabase.chat.botCommandPermissions.reaction = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions.scene == nil {
            realDatabase.chat.botCommandPermissions.scene = .init()
            store()
        }
        if realDatabase.location.resetWhenGoingLive == nil {
            realDatabase.location.resetWhenGoingLive = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.tts.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.tts.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.fix.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.fix.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.map.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.map.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.alert!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.alert!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.fax!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.fax!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.snapshot!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.snapshot!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.filter!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.filter!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.tesla!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.tesla!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.audio!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.audio!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.reaction!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.reaction!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions.scene!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions.scene!.sendChatMessages = false
            store()
        }
        for widget in realDatabase.widgets {
            for command in widget.alerts.chatBot!.commands where command.imageType == nil {
                command.imageType = .file
                store()
            }
            for command in widget.alerts.chatBot!.commands where command.imagePlaygroundImageId == nil {
                command.imagePlaygroundImageId = .init()
                store()
            }
        }
        if realDatabase.tesla.enabled == nil {
            realDatabase.tesla.enabled = true
            store()
        }
        if realDatabase.replay.position == nil {
            realDatabase.replay.position = 10.0
            store()
        }
        if realDatabase.replay.start == nil {
            realDatabase.replay.start = 20.0
            store()
        }
        if realDatabase.replay.stop == nil {
            realDatabase.replay.stop = 30.0
            store()
        }
        for stream in realDatabase.streams where stream.replay.fade == nil {
            stream.replay.fade = true
            store()
        }
        for button in realDatabase.quickButtons where button.page == nil {
            button.page = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions.stream == nil {
            realDatabase.chat.botCommandPermissions.stream = .init()
            store()
        }
    }
}
