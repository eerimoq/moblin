import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"
let defaultRtmpStreamUrl = "rtmp://my_public_ip:1935/live/foobar"
let defaultQuickButtonColor = RgbColor(red: 255 / 4, green: 255 / 4, blue: 255 / 4)
let defaultStreamButtonColor = RgbColor(red: 255, green: 59, blue: 48)
let defaultSrtLatency: Int32 = 3000
private let defaultRtmpLatency: Int32 = 2000
let minZoomX: Float = 0.5

enum SettingsStreamCodec: String, Codable, CaseIterable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"

    init(from decoder: Decoder) throws {
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
    case r960x540 = "960x540"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"

    init(from decoder: Decoder) throws {
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
        case .r960x540:
            return "540p"
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
        case .r960x540:
            size = .init(width: 960, height: 540)
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

enum SettingsStreamAudioCodec: String, Codable, CaseIterable {
    case aac = "AAC"
    case opus = "OPUS"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamAudioCodec(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .aac
    }

    func toEncoder() -> AudioEncoderSettings.Format {
        switch self {
        case .aac:
            return .aac
        case .opus:
            return .opus
        }
    }

    func toString() -> String {
        switch self {
        case .aac:
            return "AAC"
        case .opus:
            return "Opus"
        }
    }
}

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
    case rist = "RIST"

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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
    var minimumBitrate: Float = 250

    init() {}

    enum CodingKeys: CodingKey {
        case packetsInFlight,
             minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.packetsInFlight, packetsInFlight)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsInFlight = container.decode(.packetsInFlight, Int32.self, 200)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

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
    var minimumBitrate: Float = 250

    init() {}

    enum CodingKeys: CodingKey {
        case packetsInFlight,
             pifDiffIncreaseFactor,
             rttDiffHighDecreaseFactor,
             rttDiffHighAllowedSpike,
             rttDiffHighMinimumDecrease,
             minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.packetsInFlight, packetsInFlight)
        try container.encode(.pifDiffIncreaseFactor, pifDiffIncreaseFactor)
        try container.encode(.rttDiffHighDecreaseFactor, rttDiffHighDecreaseFactor)
        try container.encode(.rttDiffHighAllowedSpike, rttDiffHighAllowedSpike)
        try container.encode(.rttDiffHighMinimumDecrease, rttDiffHighMinimumDecrease)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsInFlight = container.decode(.packetsInFlight, Int32.self, 200)
        pifDiffIncreaseFactor = container.decode(.pifDiffIncreaseFactor, Float.self, 100)
        rttDiffHighDecreaseFactor = container.decode(.rttDiffHighDecreaseFactor, Float.self, 0.9)
        rttDiffHighAllowedSpike = container.decode(.rttDiffHighAllowedSpike, Float.self, 50)
        rttDiffHighMinimumDecrease = container.decode(.rttDiffHighMinimumDecrease, Float.self, 250)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

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

    init() {}

    enum CodingKeys: CodingKey {
        case minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrateBelaboxSettings {
        let new = SettingsStreamSrtAdaptiveBitrateBelaboxSettings()
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrate: Codable {
    var algorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm = .belabox
    var fastIrlSettings: SettingsStreamSrtAdaptiveBitrateFastIrlSettings = .init()
    var customSettings: SettingsStreamSrtAdaptiveBitrateCustomSettings = .init()
    var belaboxSettings: SettingsStreamSrtAdaptiveBitrateBelaboxSettings = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case algorithm,
             fastIrlSettings,
             customSettings,
             belaboxSettings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.algorithm, algorithm)
        try container.encode(.fastIrlSettings, fastIrlSettings)
        try container.encode(.customSettings, customSettings)
        try container.encode(.belaboxSettings, belaboxSettings)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        algorithm = container.decode(.algorithm, SettingsStreamSrtAdaptiveBitrateAlgorithm.self, .belabox)
        fastIrlSettings = container.decode(
            .fastIrlSettings,
            SettingsStreamSrtAdaptiveBitrateFastIrlSettings.self,
            .init()
        )
        customSettings = container.decode(.customSettings, SettingsStreamSrtAdaptiveBitrateCustomSettings.self, .init())
        belaboxSettings = container.decode(
            .belaboxSettings,
            SettingsStreamSrtAdaptiveBitrateBelaboxSettings.self,
            .init()
        )
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrate {
        let new = SettingsStreamSrtAdaptiveBitrate()
        new.algorithm = algorithm
        new.fastIrlSettings = fastIrlSettings.clone()
        new.customSettings = customSettings.clone()
        new.belaboxSettings = belaboxSettings.clone()
        return new
    }
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = defaultSrtLatency
    var maximumBandwidthFollowInput: Bool = true
    var overheadBandwidth: Int32 = 25
    var adaptiveBitrateEnabled: Bool = true
    var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate = .init()
    var connectionPriorities: SettingsStreamSrtConnectionPriorities = .init()
    var mpegtsPacketsPerPacket: Int = 7
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system

    init() {}

    enum CodingKeys: CodingKey {
        case latency,
             maximumBandwidthFollowInput,
             overheadBandwidth,
             adaptiveBitrateEnabled,
             adaptiveBitrate,
             connectionPriorities,
             mpegtsPacketsPerPacket,
             dnsLookupStrategy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.latency, latency)
        try container.encode(.maximumBandwidthFollowInput, maximumBandwidthFollowInput)
        try container.encode(.overheadBandwidth, overheadBandwidth)
        try container.encode(.adaptiveBitrateEnabled, adaptiveBitrateEnabled)
        try container.encode(.adaptiveBitrate, adaptiveBitrate)
        try container.encode(.connectionPriorities, connectionPriorities)
        try container.encode(.mpegtsPacketsPerPacket, mpegtsPacketsPerPacket)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latency = container.decode(.latency, Int32.self, defaultSrtLatency)
        maximumBandwidthFollowInput = container.decode(.maximumBandwidthFollowInput, Bool.self, true)
        overheadBandwidth = container.decode(.overheadBandwidth, Int32.self, 25)
        adaptiveBitrateEnabled = container.decode(.adaptiveBitrateEnabled, Bool.self, true)
        adaptiveBitrate = container.decode(.adaptiveBitrate, SettingsStreamSrtAdaptiveBitrate.self, .init())
        connectionPriorities = container.decode(.connectionPriorities,
                                                SettingsStreamSrtConnectionPriorities.self,
                                                .init())
        mpegtsPacketsPerPacket = container.decode(.mpegtsPacketsPerPacket, Int.self, 7)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
    }

    func clone() -> SettingsStreamSrt {
        let new = SettingsStreamSrt()
        new.latency = latency
        new.overheadBandwidth = overheadBandwidth
        new.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.adaptiveBitrate = adaptiveBitrate.clone()
        new.connectionPriorities = connectionPriorities.clone()
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

    init(from decoder: Decoder) throws {
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

class SettingsStreamRecording: Codable, ObservableObject {
    @Published var videoCodec: SettingsStreamCodec = .h265hevc
    @Published var videoBitrate: UInt32 = 0
    @Published var maxKeyFrameInterval: Int32 = 0
    @Published var audioBitrate: UInt32 = 128_000
    @Published var autoStartRecording: Bool = false
    @Published var autoStopRecording: Bool = false
    @Published var cleanRecordings: Bool = false
    @Published var cleanSnapshots: Bool = false
    @Published var recordingPath: Data?

    init() {}

    enum CodingKeys: CodingKey {
        case videoCodec,
             videoBitrate,
             maxKeyFrameInterval,
             audioBitrate,
             autoStartRecording,
             autoStopRecording,
             cleanRecordings,
             cleanSnapshots,
             recordingPath
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.videoCodec, videoCodec)
        try container.encode(.videoBitrate, videoBitrate)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
        try container.encode(.audioBitrate, audioBitrate)
        try container.encode(.autoStartRecording, autoStartRecording)
        try container.encode(.autoStopRecording, autoStopRecording)
        try container.encode(.cleanRecordings, cleanRecordings)
        try container.encode(.cleanSnapshots, cleanSnapshots)
        try container.encode(.recordingPath, recordingPath)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoCodec = container.decode(.videoCodec, SettingsStreamCodec.self, .h265hevc)
        videoBitrate = container.decode(.videoBitrate, UInt32.self, 0)
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 0)
        audioBitrate = container.decode(.audioBitrate, UInt32.self, 128_000)
        autoStartRecording = container.decode(.autoStartRecording, Bool.self, false)
        autoStopRecording = container.decode(.autoStopRecording, Bool.self, false)
        cleanRecordings = container.decode(.cleanRecordings, Bool.self, false)
        cleanSnapshots = container.decode(.cleanSnapshots, Bool.self, false)
        recordingPath = container.decode(.recordingPath, Data?.self, nil)
    }

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
        new.recordingPath = recordingPath
        return new
    }

    func videoBitrateString() -> String {
        if videoBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(videoBitrate))
        } else {
            return String(localized: "Auto")
        }
    }

    func maxKeyFrameIntervalString() -> String {
        if maxKeyFrameInterval != 0 {
            return "\(maxKeyFrameInterval) s"
        } else {
            return String(localized: "Auto")
        }
    }

    func audioBitrateString() -> String {
        if audioBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(audioBitrate))
        } else {
            return String(localized: "Auto")
        }
    }

    func isDefaultRecordingPath() -> Bool {
        return recordingPath == nil
    }
}

class SettingsStreamReplay: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var fade: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case enabled,
             fade
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.fade, fade)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        fade = container.decode(.fade, Bool.self, false)
    }

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

class SettingsStreamMultiStreamingDestination: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My destination")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = defaultRtmpStreamUrl
    @Published var enabled: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case name,
             url,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, defaultRtmpStreamUrl)
        enabled = container.decode(.enabled, Bool.self, false)
    }

    func clone() -> SettingsStreamMultiStreamingDestination {
        let new = SettingsStreamMultiStreamingDestination()
        new.name = name
        new.url = url
        return new
    }
}

class SettingsStreamMultiStreaming: Codable, ObservableObject {
    @Published var destinations: [SettingsStreamMultiStreamingDestination] = []

    init() {}

    enum CodingKeys: CodingKey {
        case destinations
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.destinations, destinations)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        destinations = container.decode(.destinations, [SettingsStreamMultiStreamingDestination].self, [])
    }

    func clone() -> SettingsStreamMultiStreaming {
        let new = SettingsStreamMultiStreaming()
        for destination in destinations {
            new.destinations.append(destination.clone())
        }
        return new
    }
}

class SettingsStream: Codable, Identifiable, Equatable, ObservableObject, Named {
    @Published var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    @Published var url: String = defaultStreamUrl
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var twitchShowFollows: Bool = true
    var twitchAccessToken: String = ""
    var twitchLoggedIn: Bool = false
    var twitchRewards: [SettingsStreamTwitchReward] = []
    @Published var twitchSendMessagesTo: Bool = true
    var kickChannelName: String = ""
    @Published var kickChannelId: String?
    @Published var kickSlug: String?
    var kickAccessToken: String = ""
    @Published var kickLoggedIn: Bool = false
    @Published var kickSendMessagesTo: Bool = true
    var youTubeApiKey: String = ""
    @Published var youTubeVideoId: String = ""
    @Published var youTubeHandle: String = ""
    var afreecaTvChannelName: String = ""
    var afreecaTvStreamId: String = ""
    var openStreamingPlatformUrl: String = ""
    var openStreamingPlatformChannelId: String = ""
    @Published var obsWebSocketEnabled: Bool = false
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
    @Published var maxKeyFrameInterval: Int32 = 2
    @Published var audioCodec: SettingsStreamAudioCodec = .aac
    var audioBitrate: Int = 128_000
    var chat: SettingsStreamChat = .init()
    var recording: SettingsStreamRecording = .init()
    @Published var realtimeIrlEnabled: Bool = false
    var realtimeIrlPushKey: String = ""
    @Published var portrait: Bool = false
    @Published var backgroundStreaming: Bool = false
    @Published var estimatedViewerDelay: Float = 8.0
    var twitchMultiTrackEnabled: Bool = false
    @Published var ntpPoolAddress: String = "time.apple.com"
    @Published var timecodesEnabled: Bool = false
    var replay: SettingsStreamReplay = .init()
    @Published var goLiveNotificationDiscordMessage: String = ""
    @Published var goLiveNotificationDiscordWebhookUrl: String = ""
    @Published var multiStreaming: SettingsStreamMultiStreaming = .init()

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
             twitchSendMessagesTo,
             kickChannelName,
             kickChannelId,
             kickSlug,
             kickAccessToken,
             kickLoggedIn,
             kickSendMessagesTo,
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
             audioCodec,
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
             multiStreaming
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
        try container.encode(.twitchSendMessagesTo, twitchSendMessagesTo)
        try container.encode(.kickChannelName, kickChannelName)
        try container.encode(.kickChannelId, kickChannelId)
        try container.encode(.kickSlug, kickSlug)
        try container.encode(.kickAccessToken, kickAccessToken)
        try container.encode(.kickLoggedIn, kickLoggedIn)
        try container.encode(.kickSendMessagesTo, kickSendMessagesTo)
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
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
        try container.encode(.audioCodec, audioCodec)
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
        try container.encode(.multiStreaming, multiStreaming)
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
        twitchSendMessagesTo = container.decode(.twitchSendMessagesTo, Bool.self, true)
        kickChannelName = container.decode(.kickChannelName, String.self, "")
        kickChannelId = container.decode(.kickChannelId, String?.self, nil)
        kickSlug = container.decode(.kickSlug, String?.self, nil)
        kickAccessToken = container.decode(.kickAccessToken, String.self, "")
        kickLoggedIn = container.decode(.kickLoggedIn, Bool.self, false)
        kickSendMessagesTo = container.decode(.kickSendMessagesTo, Bool.self, true)
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
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 2)
        audioCodec = container.decode(.audioCodec, SettingsStreamAudioCodec.self, .aac)
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
        multiStreaming = container.decode(.multiStreaming, SettingsStreamMultiStreaming.self, .init())
    }

    func clone() -> SettingsStream {
        let new = SettingsStream(name: name)
        new.url = url
        new.twitchChannelName = twitchChannelName
        new.twitchChannelId = twitchChannelId
        new.twitchShowFollows = twitchShowFollows
        new.twitchSendMessagesTo = twitchSendMessagesTo
        new.kickChannelName = kickChannelName
        new.kickChannelId = kickChannelId
        new.kickSlug = kickSlug
        new.kickAccessToken = kickAccessToken
        new.kickLoggedIn = kickLoggedIn
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
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioCodec = audioCodec
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
        new.multiStreaming = multiStreaming.clone()
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
        if getProtocol() == .srt && srt.adaptiveBitrateEnabled {
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
        return audioCodec.toString()
    }

    func maxKeyFrameIntervalString() -> String {
        if maxKeyFrameInterval != 0 {
            return "\(maxKeyFrameInterval) s"
        } else {
            return String(localized: "Auto")
        }
    }
}

class SettingsSceneWidget: Codable, Identifiable, Equatable, ObservableObject {
    static func == (lhs: SettingsSceneWidget, rhs: SettingsSceneWidget) -> Bool {
        return lhs.id == rhs.id
    }

    var id: UUID = .init()
    @Published var widgetId: UUID
    @Published var enabled: Bool = true
    @Published var x: Double = 0.0
    @Published var xString: String = "0.0"
    @Published var y: Double = 0.0
    @Published var yString: String = "0.0"
    @Published var width: Double = 100.0
    @Published var widthString: String = "100.0"
    @Published var height: Double = 100.0
    @Published var heightString: String = "100.0"

    init(widgetId: UUID) {
        self.widgetId = widgetId
    }

    enum CodingKeys: CodingKey {
        case widgetId,
             enabled,
             id,
             x,
             y,
             width,
             height
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.widgetId, widgetId)
        try container.encode(.enabled, enabled)
        try container.encode(.id, id)
        try container.encode(.x, x)
        try container.encode(.y, y)
        try container.encode(.width, width)
        try container.encode(.height, height)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widgetId = container.decode(.widgetId, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        id = container.decode(.id, UUID.self, .init())
        x = container.decode(.x, Double.self, 0.0)
        xString = String(x)
        y = container.decode(.y, Double.self, 0.0)
        yString = String(y)
        width = container.decode(.width, Double.self, 100.0)
        widthString = String(width)
        height = container.decode(.height, Double.self, 100.0)
        heightString = String(height)
    }

    func clone() -> SettingsSceneWidget {
        let new = SettingsSceneWidget(widgetId: widgetId)
        new.enabled = enabled
        new.x = x
        new.xString = xString
        new.y = y
        new.yString = yString
        new.width = width
        new.widthString = widthString
        new.height = height
        new.heightString = heightString
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
    case rist = "RIST"
    case rtsp = "RTSP"
    case mediaPlayer = "Media player"
    case screenCapture = "Screen capture"
    case backTripleLowEnergy = "Back triple"
    case backDualLowEnergy = "Back dual"
    case backWideDualLowEnergy = "Back wide dual"
    case none = "None"

    init(from decoder: Decoder) throws {
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
    case rist(id: UUID)
    case rtsp(id: UUID)
    case mediaPlayer(id: UUID)
    case external(id: String, name: String)
    case screenCapture
    case none
    case backTripleLowEnergy
    case backDualLowEnergy
    case backWideDualLowEnergy
}

class SettingsScene: Codable, Identifiable, Equatable, ObservableObject, Named {
    static let baseName = String(localized: "My scene")
    @Published var name: String
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var cameraType: SettingsSceneCameraPosition = .back
    @Published var cameraPosition: SettingsSceneCameraPosition = getDefaultBackCameraPosition()
    @Published var backCameraId: String = getBestBackCameraId()
    @Published var frontCameraId: String = getBestFrontCameraId()
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    var externalCameraName: String = ""
    @Published var widgets: [SettingsSceneWidget] = []
    @Published var videoSourceRotation: Double = 0.0
    @Published var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    @Published var overrideVideoStabilizationMode: Bool = false
    @Published var fillFrame: Bool = false
    @Published var overrideMic: Bool = false
    @Published var micId: String = ""

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
             ristCameraId,
             rtspCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             widgets,
             videoSourceRotation,
             videoStabilizationMode,
             overrideVideoStabilizationMode,
             fillFrame,
             overrideMic,
             micId
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
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.widgets, widgets)
        try container.encode(.videoSourceRotation, videoSourceRotation)
        try container.encode(.videoStabilizationMode, videoStabilizationMode)
        try container.encode(.overrideVideoStabilizationMode, overrideVideoStabilizationMode)
        try container.encode(.fillFrame, fillFrame)
        try container.encode(.overrideMic, overrideMic)
        try container.encode(.micId, micId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        cameraType = container.decode(.cameraType, SettingsSceneCameraPosition.self, .back)
        cameraPosition = container.decode(
            .cameraPosition,
            SettingsSceneCameraPosition.self,
            getDefaultBackCameraPosition()
        )
        backCameraId = container.decode(.backCameraId, String.self, getBestBackCameraId())
        frontCameraId = container.decode(.frontCameraId, String.self, getBestFrontCameraId())
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        widgets = container.decode(.widgets, [SettingsSceneWidget].self, [])
        videoSourceRotation = container.decode(.videoSourceRotation, Double.self, 0.0)
        videoStabilizationMode = container.decode(.videoStabilizationMode, SettingsVideoStabilizationMode.self, .off)
        overrideVideoStabilizationMode = container.decode(.overrideVideoStabilizationMode, Bool.self, false)
        fillFrame = container.decode(.fillFrame, Bool.self, false)
        overrideMic = container.decode(.overrideMic, Bool.self, false)
        micId = container.decode(.micId, String.self, "")
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
        new.overrideMic = overrideMic
        new.micId = micId
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
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
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
        case .none:
            return .none
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
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
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
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsAutoSceneSwitcherScene: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var sceneId: UUID?
    @Published var time: Int = 15

    enum CodingKeys: CodingKey {
        case id,
             sceneId,
             time
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.sceneId, sceneId)
        try container.encode(.time, time)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        time = container.decode(.time, Int.self, 15)
    }
}

class SettingsAutoSceneSwitcher: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My switcher")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var shuffle: Bool = false
    @Published var scenes: [SettingsAutoSceneSwitcherScene] = []

    enum CodingKeys: CodingKey {
        case id,
             name,
             shuffle,
             scenes
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
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        shuffle = container.decode(.shuffle, Bool.self, false)
        scenes = container.decode(.scenes, [SettingsAutoSceneSwitcherScene].self, [])
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

class SettingsWidgetTextTimer: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var delta: Int = 5
    @Published var endTime: Double = 0

    enum CodingKeys: CodingKey {
        case id,
             delta,
             endTime
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.delta, delta)
        try container.encode(.endTime, endTime)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        delta = container.decode(.delta, Int.self, 5)
        endTime = container.decode(.endTime, Double.self, 0)
    }

    func add(delta: Double) {
        if timeLeft() < 0 {
            endTime = Date().timeIntervalSince1970
        }
        endTime += delta
    }

    func format() -> String {
        return Duration(secondsComponent: Int64(max(timeLeft(), 0)), attosecondsComponent: 0).formatWithSeconds()
    }

    func textEffectEndTime() -> ContinuousClock.Instant {
        return .now.advanced(by: .seconds(max(timeLeft(), 0)))
    }

    private func timeLeft() -> Double {
        return utcTimeDeltaFromNow(to: endTime)
    }
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
    @Published var formatString: String = "{shortTime}"
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
    @Published var fontMonospacedDigits: Bool = false
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

    init(from decoder: Decoder) throws {
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

class SettingsWidgetAlertsAlert: Codable, ObservableObject {
    var enabled: Bool = true
    var imageId: UUID = .init()
    var imageLoopCount: Int = 1
    var soundId: UUID = .init()
    var textColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    var accentColor: RgbColor = .init(red: 0xFD, green: 0xFB, blue: 0x67)
    var fontSize: Int = 45
    var fontDesign: SettingsFontDesign = .monospaced
    var fontWeight: SettingsFontWeight = .bold
    var textToSpeechEnabled: Bool = true
    var textToSpeechDelay: Double = 1.5
    @Published var textToSpeechLanguageVoices: [String: String] = .init()
    var positionType: SettingsWidgetAlertPositionType = .scene
    var facePosition: SettingsWidgetAlertFacePosition = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case enabled,
             imageId,
             imageLoopCount,
             soundId,
             textColor,
             accentColor,
             fontSize,
             fontDesign,
             fontWeight,
             textToSpeechEnabled,
             textToSpeechDelay,
             textToSpeechLanguageVoices,
             positionType,
             facePosition
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.imageId, imageId)
        try container.encode(.imageLoopCount, imageLoopCount)
        try container.encode(.soundId, soundId)
        try container.encode(.textColor, textColor)
        try container.encode(.accentColor, accentColor)
        try container.encode(.fontSize, fontSize)
        try container.encode(.fontDesign, fontDesign)
        try container.encode(.fontWeight, fontWeight)
        try container.encode(.textToSpeechEnabled, textToSpeechEnabled)
        try container.encode(.textToSpeechDelay, textToSpeechDelay)
        try container.encode(.textToSpeechLanguageVoices, textToSpeechLanguageVoices)
        try container.encode(.positionType, positionType)
        try container.encode(.facePosition, facePosition)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, true)
        imageId = container.decode(.imageId, UUID.self, .init())
        imageLoopCount = container.decode(.imageLoopCount, Int.self, 1)
        soundId = container.decode(.soundId, UUID.self, .init())
        textColor = container.decode(.textColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        accentColor = container.decode(.accentColor, RgbColor.self, .init(red: 0xFD, green: 0xFB, blue: 0x67))
        fontSize = container.decode(.fontSize, Int.self, 45)
        fontDesign = container.decode(.fontDesign, SettingsFontDesign.self, .monospaced)
        fontWeight = container.decode(.fontWeight, SettingsFontWeight.self, .bold)
        textToSpeechEnabled = container.decode(.textToSpeechEnabled, Bool.self, true)
        textToSpeechDelay = container.decode(.textToSpeechDelay, Double.self, 1.5)
        textToSpeechLanguageVoices = container.decode(.textToSpeechLanguageVoices, [String: String].self, .init())
        positionType = container.decode(.positionType, SettingsWidgetAlertPositionType.self, .scene)
        facePosition = container.decode(.facePosition, SettingsWidgetAlertFacePosition.self, .init())
    }

    func isTextToSpeechEnabled() -> Bool {
        return enabled && textToSpeechEnabled
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

    init(from decoder: Decoder) throws {
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
    var raids: SettingsWidgetAlertsAlert = .init()
    var cheers: SettingsWidgetAlertsAlert = .init()
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert] = createDefaultCheerBits()

    init() {}

    enum CodingKeys: CodingKey {
        case follows,
             subscriptions,
             raids,
             cheers,
             cheerBits
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.follows, follows)
        try container.encode(.subscriptions, subscriptions)
        try container.encode(.raids, raids)
        try container.encode(.cheers, cheers)
        try container.encode(.cheerBits, cheerBits)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        follows = container.decode(.follows, SettingsWidgetAlertsAlert.self, .init())
        subscriptions = container.decode(.subscriptions, SettingsWidgetAlertsAlert.self, .init())
        raids = container.decode(.raids, SettingsWidgetAlertsAlert.self, .init())
        cheers = container.decode(.cheers, SettingsWidgetAlertsAlert.self, .init())
        cheerBits = container.decode(.cheerBits, [SettingsWidgetAlertsCheerBitsAlert].self, createDefaultCheerBits())
    }

    func clone() -> SettingsWidgetAlertsTwitch {
        let new = SettingsWidgetAlertsTwitch()
        new.follows = follows.clone()
        new.subscriptions = subscriptions.clone()
        new.raids = raids.clone()
        new.cheers = cheers.clone()
        new.cheerBits = cheerBits.map { $0.clone() }
        return new
    }
}

enum SettingsWidgetAlertsChatBotCommandImageType: String, Codable, CaseIterable {
    case file = "File"
    case imagePlayground = "Image Playground"

    init(from decoder: Decoder) throws {
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
    var twitch: SettingsWidgetAlertsTwitch = .init()
    var chatBot: SettingsWidgetAlertsChatBot = .init()
    var speechToText: SettingsWidgetAlertsSpeechToText = .init()
    var needsSubtitles: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case twitch,
             chatBot,
             speechToText,
             needsSubtitles
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twitch, twitch)
        try container.encode(.chatBot, chatBot)
        try container.encode(.speechToText, speechToText)
        try container.encode(.needsSubtitles, needsSubtitles)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twitch = container.decode(.twitch, SettingsWidgetAlertsTwitch.self, .init())
        chatBot = container.decode(.chatBot, SettingsWidgetAlertsChatBot.self, .init())
        speechToText = container.decode(.speechToText, SettingsWidgetAlertsSpeechToText.self, .init())
        needsSubtitles = container.decode(.needsSubtitles, Bool.self, false)
    }

    func clone() -> SettingsWidgetAlerts {
        let new = SettingsWidgetAlerts()
        new.twitch = twitch.clone()
        new.chatBot = chatBot.clone()
        new.speechToText = speechToText.clone()
        new.needsSubtitles = needsSubtitles
        return new
    }
}

class SettingsWidgetVideoSource: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = getBestBackCameraId()
    @Published var frontCameraId: String = getBestFrontCameraId()
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
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
             ristCameraId,
             rtspCameraId,
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
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
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
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
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
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
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
        case .none:
            return .none
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
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
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
        case .none:
            cameraPosition = .none
        }
    }
}

enum SettingsWidgetScoreboardType: String, Codable, CaseIterable {
    case padel = "Padel"

    init(from decoder: Decoder) throws {
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

class SettingsWidgetScoreboardPlayer: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "🇸🇪 Moblin")
    var id: UUID = .init()
    @Published var name: String = baseName

    enum CodingKeys: CodingKey {
        case id,
             name
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
    }
}

class SettingsWidgetScoreboardScore: Codable, Identifiable {
    var home: Int = 0
    var away: Int = 0
}

enum SettingsWidgetPadelScoreboardGameType: String, Codable, CaseIterable {
    case doubles = "Double"
    case singles = "Single"

    init(from decoder: Decoder) throws {
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

enum SettingsWidgetPadelScoreboardScoreIncrement {
    case home
    case away
}

class SettingsWidgetPadelScoreboard: Codable, ObservableObject {
    var type: SettingsWidgetPadelScoreboardGameType = .doubles
    var homePlayer1: UUID = .init()
    var homePlayer2: UUID = .init()
    var awayPlayer1: UUID = .init()
    var awayPlayer2: UUID = .init()
    var score: [SettingsWidgetScoreboardScore] = [.init()]
    var scoreChanges: [SettingsWidgetPadelScoreboardScoreIncrement] = []

    enum CodingKeys: CodingKey {
        case type,
             homePlayer1,
             homePlayer2,
             awayPlayer1,
             awayPlayer2,
             score
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.type, type)
        try container.encode(.homePlayer1, homePlayer1)
        try container.encode(.homePlayer2, homePlayer2)
        try container.encode(.awayPlayer1, awayPlayer1)
        try container.encode(.awayPlayer2, awayPlayer2)
        try container.encode(.score, score)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decode(.type, SettingsWidgetPadelScoreboardGameType.self, .doubles)
        homePlayer1 = container.decode(.homePlayer1, UUID.self, .init())
        homePlayer2 = container.decode(.homePlayer2, UUID.self, .init())
        awayPlayer1 = container.decode(.awayPlayer1, UUID.self, .init())
        awayPlayer2 = container.decode(.awayPlayer2, UUID.self, .init())
        score = container.decode(.score, [SettingsWidgetScoreboardScore].self, [.init()])
    }
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

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetVideoEffectType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .movie
    }
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case text = "Text"
    case browser = "Browser"
    case videoSource = "Video source"
    case image = "Image"
    case alerts = "Alerts"
    case map = "Map"
    case snapshot = "Snapshot"
    case scene = "Scene"
    case vTuber = "VTuber"
    case pngTuber = "PNGTuber"
    case qrCode = "QR code"
    case scoreboard = "Scoreboard"
    case crop = "Crop"
    case videoEffect = "Video effect"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .text
    }

    func toString() -> String {
        switch self {
        case .text:
            return String(localized: "Text")
        case .browser:
            return String(localized: "Browser")
        case .videoSource:
            return String(localized: "Video source")
        case .image:
            return String(localized: "Image")
        case .alerts:
            return String(localized: "Alerts")
        case .map:
            return String(localized: "Map")
        case .snapshot:
            return String(localized: "Snapshot")
        case .scene:
            return String(localized: "Scene")
        case .vTuber:
            return String(localized: "VTuber")
        case .pngTuber:
            return String(localized: "PNGTuber")
        case .qrCode:
            return String(localized: "QR code")
        case .scoreboard:
            return String(localized: "Scoreboard")
        case .crop:
            return String(localized: "Crop")
        case .videoEffect:
            return String(localized: "Video effect")
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases.filter { $0 != .videoEffect }

enum SettingsVideoEffectType: String, Codable, CaseIterable {
    case shape
    case grayScale
    case sepia
    case whirlpool
    case pinch
    case removeBackground

    init(from decoder: Decoder) throws {
        do {
            self = try SettingsVideoEffectType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .grayScale
        } catch {
            self = .grayScale
        }
    }

    func toString() -> String {
        switch self {
        case .shape:
            return String(localized: "Shape")
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
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = getBestBackCameraId()
    @Published var frontCameraId: String = getBestFrontCameraId()
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
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
             ristCameraId,
             rtspCameraId,
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
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
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
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
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
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
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
        case .none:
            return .none
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
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
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
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsWidgetPngTuber: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = getBestBackCameraId()
    @Published var frontCameraId: String = getBestFrontCameraId()
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
    @Published var modelName: String = ""
    @Published var mirror: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             ristCameraId,
             rtspCameraId,
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
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
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
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
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
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
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
        case .none:
            return .none
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
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
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
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsWidgetSnapshot: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var showtime: Int = 5

    enum CodingKeys: CodingKey {
        case id,
             showtime
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.showtime, showtime)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        showtime = container.decode(.showtime, Int.self, 5)
    }
}

class SettingsWidget: Codable, Identifiable, Equatable, ObservableObject, Named {
    static let baseName = String(localized: "My widget")
    @Published var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .text
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
    var snapshot: SettingsWidgetSnapshot = .init()
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
             snapshot,
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
        try container.encode(.snapshot, snapshot)
        try container.encode(.enabled, enabled)
        try container.encode(.effects, effects)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsWidgetType.self, .text)
        text = container.decode(.text, SettingsWidgetText.self, .init())
        browser = container.decode(.browser, SettingsWidgetBrowser.self, .init())
        crop = container.decode(.crop, SettingsWidgetCrop.self, .init())
        map = container.decode(.map, SettingsWidgetMap.self, .init())
        scene = container.decode(.scene, SettingsWidgetScene.self, .init())
        qrCode = container.decode(.qrCode, SettingsWidgetQrCode.self, .init())
        alerts = container.decode(.alerts, SettingsWidgetAlerts.self, .init())
        videoSource = container.decode(.videoSource, SettingsWidgetVideoSource.self, .init())
        scoreboard = container.decode(.scoreboard, SettingsWidgetScoreboard.self, .init())
        vTuber = container.decode(.vTuber, SettingsWidgetVTuber.self, .init())
        pngTuber = container.decode(.pngTuber, SettingsWidgetPngTuber.self, .init())
        snapshot = container.decode(.snapshot, SettingsWidgetSnapshot.self, .init())
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
    case cameraLevel = "Camera level"
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
        self = try SettingsColorSpace(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .srgb
    }
}

let colorSpaces = SettingsColorSpace.allCases

private let allBundledLuts = [
    SettingsColorLut(type: .bundled, name: "Apple Log To Rec 709"),
    SettingsColorLut(type: .bundled, name: "Moblin Meme"),
]

class SettingsColor: Codable, ObservableObject {
    @Published var space: SettingsColorSpace = .srgb
    @Published var lutEnabled: Bool = true
    @Published var lut: UUID = .init()
    var bundledLuts = allBundledLuts
    @Published var diskLuts: [SettingsColorLut] = []
    @Published var diskLutsPng: [SettingsColorLut] = []
    @Published var diskLutsCube: [SettingsColorLut] = []

    init() {}

    enum CodingKeys: CodingKey {
        case space,
             lutEnabled,
             lut,
             bundledLuts,
             diskLuts,
             diskLutsPng,
             diskLutsCube
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.space, space)
        try container.encode(.lutEnabled, lutEnabled)
        try container.encode(.lut, lut)
        try container.encode(.bundledLuts, bundledLuts)
        try container.encode(.diskLuts, diskLuts)
        try container.encode(.diskLutsPng, diskLutsPng)
        try container.encode(.diskLutsCube, diskLutsCube)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        space = container.decode(.space, SettingsColorSpace.self, .srgb)
        lutEnabled = container.decode(.lutEnabled, Bool.self, true)
        lut = container.decode(.lut, UUID.self, .init())
        bundledLuts = container.decode(.bundledLuts, [SettingsColorLut].self, [])
        diskLuts = container.decode(.diskLuts, [SettingsColorLut].self, [])
        diskLutsPng = container.decode(.diskLutsPng, [SettingsColorLut].self, [])
        diskLutsCube = container.decode(.diskLutsCube, [SettingsColorLut].self, [])
    }
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
    @Published var cpu: Bool = false

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
             heartRateDevice,
             cpu
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
        try container.encode(.cpu, cpu)
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
        cpu = container.decode(.cpu, Bool.self, false)
    }
}

class SettingsZoomPreset: Codable, Identifiable, Equatable, ObservableObject {
    var id: UUID
    @Published var name: String = ""
    @Published var x: Float = 1.0

    init(id: UUID, name: String, x: Float) {
        self.id = id
        self.name = name
        self.x = x
    }

    static func == (lhs: SettingsZoomPreset, rhs: SettingsZoomPreset) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case id,
             name,
             x
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.x, x)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        x = container.decode(.x, Float.self, 1.0)
    }
}

class SettingsZoomSwitchTo: Codable, ObservableObject {
    @Published var level: Float = 1.0
    @Published var x: Float = 1.0
    @Published var enabled: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case level,
             x,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.level, level)
        try container.encode(.x, x)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = container.decode(.level, Float.self, 1.0)
        x = container.decode(.x, Float.self, 1.0)
        enabled = container.decode(.enabled, Bool.self, false)
    }
}

class SettingsZoom: Codable, ObservableObject {
    @Published var back: [SettingsZoomPreset] = []
    @Published var front: [SettingsZoomPreset] = []
    @Published var switchToBack: SettingsZoomSwitchTo = .init()
    @Published var switchToFront: SettingsZoomSwitchTo = .init()
    @Published var speed: Float = 5.0

    init() {}

    enum CodingKeys: CodingKey {
        case back,
             front,
             switchToBack,
             switchToFront,
             speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.back, back)
        try container.encode(.front, front)
        try container.encode(.switchToBack, switchToBack)
        try container.encode(.switchToFront, switchToFront)
        try container.encode(.speed, speed)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        back = container.decode(.back, [SettingsZoomPreset].self, [])
        front = container.decode(.front, [SettingsZoomPreset].self, [])
        switchToBack = container.decode(.switchToBack, SettingsZoomSwitchTo.self, .init())
        switchToFront = container.decode(.switchToFront, SettingsZoomSwitchTo.self, .init())
        speed = container.decode(.speed, Float.self, 5.0)
    }
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

    init(from decoder: Decoder) throws {
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
        if self.user.count > 0, user != self.user {
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

    func username() -> String {
        if user.isEmpty {
            return String(localized: "-- Any --")
        } else {
            return user
        }
    }

    func message() -> String {
        if messageStart.isEmpty {
            return String(localized: "-- Any --")
        } else {
            return messageStart
        }
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

class SettingsChatBotPermissionsCommand: Codable, ObservableObject {
    @Published var moderatorsEnabled: Bool = true
    @Published var subscribersEnabled: Bool = false
    @Published var minimumSubscriberTier: Int = 1
    @Published var othersEnabled: Bool = false
    @Published var sendChatMessages: Bool = false
    @Published var cooldown: Int?
    var latestExecutionTime: ContinuousClock.Instant?

    enum CodingKeys: CodingKey {
        case moderatorsEnabled,
             subscribersEnabled,
             minimumSubscriberTier,
             othersEnabled,
             sendChatMessages,
             cooldown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.moderatorsEnabled, moderatorsEnabled)
        try container.encode(.subscribersEnabled, subscribersEnabled)
        try container.encode(.minimumSubscriberTier, minimumSubscriberTier)
        try container.encode(.othersEnabled, othersEnabled)
        try container.encode(.sendChatMessages, sendChatMessages)
        try container.encode(.cooldown, cooldown)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        moderatorsEnabled = container.decode(.moderatorsEnabled, Bool.self, true)
        subscribersEnabled = container.decode(.subscribersEnabled, Bool.self, false)
        minimumSubscriberTier = container.decode(.minimumSubscriberTier, Int.self, 1)
        othersEnabled = container.decode(.othersEnabled, Bool.self, false)
        sendChatMessages = container.decode(.sendChatMessages, Bool.self, false)
        cooldown = container.decode(.cooldown, Int?.self, nil)
    }
}

class SettingsChatBotPermissions: Codable {
    var tts: SettingsChatBotPermissionsCommand = .init()
    var fix: SettingsChatBotPermissionsCommand = .init()
    var map: SettingsChatBotPermissionsCommand = .init()
    var alert: SettingsChatBotPermissionsCommand = .init()
    var fax: SettingsChatBotPermissionsCommand = .init()
    var snapshot: SettingsChatBotPermissionsCommand = .init()
    var filter: SettingsChatBotPermissionsCommand = .init()
    var tesla: SettingsChatBotPermissionsCommand = .init()
    var audio: SettingsChatBotPermissionsCommand = .init()
    var reaction: SettingsChatBotPermissionsCommand = .init()
    var scene: SettingsChatBotPermissionsCommand = .init()
    var stream: SettingsChatBotPermissionsCommand = .init()
    var widget: SettingsChatBotPermissionsCommand = .init()
    var location: SettingsChatBotPermissionsCommand = .init()
    var ai: SettingsChatBotPermissionsCommand = .init()

    enum CodingKeys: CodingKey {
        case tts,
             fix,
             map,
             alert,
             fax,
             snapshot,
             filter,
             tesla,
             audio,
             reaction,
             scene,
             stream,
             widget,
             location,
             ai
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.tts, tts)
        try container.encode(.fix, fix)
        try container.encode(.map, map)
        try container.encode(.alert, alert)
        try container.encode(.fax, fax)
        try container.encode(.snapshot, snapshot)
        try container.encode(.filter, filter)
        try container.encode(.tesla, tesla)
        try container.encode(.audio, audio)
        try container.encode(.reaction, reaction)
        try container.encode(.scene, scene)
        try container.encode(.stream, stream)
        try container.encode(.widget, widget)
        try container.encode(.location, location)
        try container.encode(.ai, ai)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tts = container.decode(.tts, SettingsChatBotPermissionsCommand.self, .init())
        fix = container.decode(.fix, SettingsChatBotPermissionsCommand.self, .init())
        map = container.decode(.map, SettingsChatBotPermissionsCommand.self, .init())
        alert = container.decode(.alert, SettingsChatBotPermissionsCommand.self, .init())
        fax = container.decode(.fax, SettingsChatBotPermissionsCommand.self, .init())
        snapshot = container.decode(.snapshot, SettingsChatBotPermissionsCommand.self, .init())
        filter = container.decode(.filter, SettingsChatBotPermissionsCommand.self, .init())
        tesla = container.decode(.tesla, SettingsChatBotPermissionsCommand.self, .init())
        audio = container.decode(.audio, SettingsChatBotPermissionsCommand.self, .init())
        reaction = container.decode(.reaction, SettingsChatBotPermissionsCommand.self, .init())
        scene = container.decode(.scene, SettingsChatBotPermissionsCommand.self, .init())
        stream = container.decode(.stream, SettingsChatBotPermissionsCommand.self, .init())
        widget = container.decode(.widget, SettingsChatBotPermissionsCommand.self, .init())
        location = container.decode(.location, SettingsChatBotPermissionsCommand.self, .init())
        ai = container.decode(.ai, SettingsChatBotPermissionsCommand.self, .init())
    }
}

class SettingsChatBotAlias: Codable, ObservableObject, Identifiable {
    var id: UUID = .init()
    @Published var alias: String = "!myalias"
    @Published var replacement: String = "!moblin"

    enum CodingKeys: CodingKey {
        case alias,
             replacement
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.alias, alias)
        try container.encode(.replacement, replacement)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alias = container.decode(.alias, String.self, "")
        replacement = container.decode(.replacement, String.self, "")
    }
}

class SettingsChatPredefinedMessage: Codable, Identifiable, ObservableObject {
    static let tagRed = "🌹"
    static let tagGreen = "🐸"
    static let tagBlue = "🐳"
    static let tagYellow = "🐥"
    static let tagOrange = "🦊"
    var id: UUID = .init()
    @Published var text: String = ""
    @Published var blueTag: Bool = false
    @Published var greenTag: Bool = false
    @Published var yellowTag: Bool = false
    @Published var orangeTag: Bool = false
    @Published var redTag: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             text,
             blueTag,
             greenTag,
             yellowTag,
             orangeTag,
             redTag
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.text, text)
        try container.encode(.blueTag, blueTag)
        try container.encode(.greenTag, greenTag)
        try container.encode(.yellowTag, yellowTag)
        try container.encode(.orangeTag, orangeTag)
        try container.encode(.redTag, redTag)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        text = container.decode(.text, String.self, "")
        blueTag = container.decode(.blueTag, Bool.self, false)
        greenTag = container.decode(.greenTag, Bool.self, false)
        yellowTag = container.decode(.yellowTag, Bool.self, false)
        orangeTag = container.decode(.orangeTag, Bool.self, false)
        redTag = container.decode(.redTag, Bool.self, false)
    }

    func tagsString() -> String {
        var tags = ""
        if blueTag {
            tags += Self.tagBlue
        }
        if greenTag {
            tags += Self.tagGreen
        }
        if yellowTag {
            tags += Self.tagYellow
        }
        if orangeTag {
            tags += Self.tagOrange
        }
        if redTag {
            tags += Self.tagRed
        }
        return tags
    }
}

class SettingsChatPredefinedMessagesFilter: Codable, ObservableObject {
    @Published var redTag: Bool = false
    @Published var greenTag: Bool = false
    @Published var blueTag: Bool = false
    @Published var yellowTag: Bool = false
    @Published var orangeTag: Bool = false

    enum CodingKeys: CodingKey {
        case redTag,
             greenTag,
             blueTag,
             yellowTag,
             orangeTag
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.redTag, redTag)
        try container.encode(.greenTag, greenTag)
        try container.encode(.blueTag, blueTag)
        try container.encode(.yellowTag, yellowTag)
        try container.encode(.orangeTag, orangeTag)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        redTag = container.decode(.redTag, Bool.self, false)
        greenTag = container.decode(.greenTag, Bool.self, false)
        blueTag = container.decode(.blueTag, Bool.self, false)
        yellowTag = container.decode(.yellowTag, Bool.self, false)
        orangeTag = container.decode(.orangeTag, Bool.self, false)
    }

    func isEnabled() -> Bool {
        return redTag || greenTag || blueTag || yellowTag || orangeTag
    }
}

class SettingsChatNickname: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var user: String = ""
    @Published var nickname: String = ""

    enum CodingKeys: CodingKey {
        case id,
             user,
             nickname
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.user, user)
        try container.encode(.nickname, nickname)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        user = container.decode(.user, String.self, "")
        nickname = container.decode(.nickname, String.self, "")
    }
}

class SettingsChatNicknames: Codable, ObservableObject {
    @Published var nicknames: [SettingsChatNickname] = []

    enum CodingKeys: CodingKey {
        case nicknames
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.nicknames, nicknames)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nicknames = container.decode(.nicknames, [SettingsChatNickname].self, [])
    }

    func getNickname(user: String) -> String? {
        return nicknames.first(where: { $0.user == user })?.nickname
    }
}

class SettingsChatBotAi: Codable, ObservableObject {
    @Published var baseUrl: String = "https://generativelanguage.googleapis.com/v1beta/openai"
    @Published var apiKey: String = ""
    @Published var model: String = "gemini-2.0-flash"
    @Published var role: String = "You give fast and short answers."

    enum CodingKeys: CodingKey {
        case baseUrl,
             apiKey,
             model,
             role
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.baseUrl, baseUrl)
        try container.encode(.apiKey, apiKey)
        try container.encode(.model, model)
        try container.encode(.role, role)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseUrl = container.decode(.baseUrl, String.self, "https://generativelanguage.googleapis.com/v1beta/openai")
        apiKey = container.decode(.apiKey, String.self, "")
        model = container.decode(.model, String.self, "gemini-2.0-flash")
        role = container.decode(.role, String.self, "You give fast and short answers.")
    }
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
    @Published var maximumAgeEnabled: Bool = false
    var meInUsernameColor: Bool = true
    @Published var enabled: Bool = true
    @Published var filters: [SettingsChatFilter] = []
    var textToSpeechEnabled: Bool = false
    @Published var textToSpeechDetectLanguagePerMessage: Bool = false
    @Published var textToSpeechSayUsername: Bool = true
    @Published var textToSpeechRate: Float = 0.4
    @Published var textToSpeechSayVolume: Float = 0.6
    @Published var textToSpeechLanguageVoices: [String: String] = .init()
    @Published var textToSpeechSubscribersOnly: Bool = false
    @Published var textToSpeechFilter: Bool = true
    @Published var textToSpeechFilterMentions: Bool = true
    @Published var mirrored: Bool = false
    @Published var botEnabled: Bool = false
    var botCommandPermissions: SettingsChatBotPermissions = .init()
    var botSendLowBatteryWarning: Bool = false
    var botCommandAi: SettingsChatBotAi = .init()
    @Published var badges: Bool = true
    var showFirstTimeChatterMessage: Bool = true
    var showNewFollowerMessage: Bool = true
    @Published var bottom: Double = 0.0
    @Published var bottomPoints: Double = 80
    @Published var newMessagesAtTop: Bool = false
    @Published var textToSpeechPauseBetweenMessages: Double = 1.0
    @Published var platform: Bool = true
    @Published var showDeletedMessages: Bool = false
    @Published var aliases: [SettingsChatBotAlias] = []
    @Published var predefinedMessages: [SettingsChatPredefinedMessage] = []
    @Published var predefinedMessagesFilter: SettingsChatPredefinedMessagesFilter = .init()
    @Published var nicknames: SettingsChatNicknames = .init()

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
             botCommandAi,
             badges,
             showFirstTimeChatterMessage,
             showNewFollowerMessage,
             bottom,
             bottomPoints,
             newMessagesAtTop,
             textToSpeechPauseBetweenMessages,
             platform,
             showDeletedMessages,
             aliases,
             predefinedMessages,
             predefinedMessagesFilter,
             sendMessagesTo,
             nicknames
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
        try container.encode(.botCommandAi, botCommandAi)
        try container.encode(.badges, badges)
        try container.encode(.showFirstTimeChatterMessage, showFirstTimeChatterMessage)
        try container.encode(.showNewFollowerMessage, showNewFollowerMessage)
        try container.encode(.bottom, bottom)
        try container.encode(.bottomPoints, bottomPoints)
        try container.encode(.newMessagesAtTop, newMessagesAtTop)
        try container.encode(.textToSpeechPauseBetweenMessages, textToSpeechPauseBetweenMessages)
        try container.encode(.platform, platform)
        try container.encode(.showDeletedMessages, showDeletedMessages)
        try container.encode(.aliases, aliases)
        try container.encode(.predefinedMessages, predefinedMessages)
        try container.encode(.predefinedMessagesFilter, predefinedMessagesFilter)
        try container.encode(.nicknames, nicknames)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = container.decode(.fontSize, Float.self, 19.0)
        usernameColor = container.decode(.usernameColor, RgbColor.self, .init(red: 255, green: 163, blue: 0))
        usernameColorColor = usernameColor.color()
        messageColor = container.decode(.messageColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        messageColorColor = messageColor.color()
        backgroundColor = container.decode(.backgroundColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        backgroundColorColor = backgroundColor.color()
        backgroundColorEnabled = container.decode(.backgroundColorEnabled, Bool.self, false)
        shadowColor = container.decode(.shadowColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        shadowColorColor = shadowColor.color()
        shadowColorEnabled = container.decode(.shadowColorEnabled, Bool.self, true)
        boldUsername = container.decode(.boldUsername, Bool.self, true)
        boldMessage = container.decode(.boldMessage, Bool.self, true)
        animatedEmotes = container.decode(.animatedEmotes, Bool.self, false)
        timestampColor = container.decode(.timestampColor, RgbColor.self, .init(red: 180, green: 180, blue: 180))
        timestampColorColor = timestampColor.color()
        timestampColorEnabled = container.decode(.timestampColorEnabled, Bool.self, false)
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
        botCommandAi = container.decode(.botCommandAi, SettingsChatBotAi.self, .init())
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
        aliases = container.decode(.aliases, [SettingsChatBotAlias].self, [])
        predefinedMessages = container.decode(.predefinedMessages, [SettingsChatPredefinedMessage].self, [])
        predefinedMessagesFilter = container.decode(
            .predefinedMessagesFilter,
            SettingsChatPredefinedMessagesFilter.self,
            .init()
        )
        nicknames = container.decode(.nicknames, SettingsChatNicknames.self, .init())
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

    init(from decoder: Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            getDefaultMic()
    }
}

class SettingsMicsMic: Codable, Identifiable, Equatable, ObservableObject {
    static func == (lhs: SettingsMicsMic, rhs: SettingsMicsMic) -> Bool {
        return lhs.inputUid == rhs.inputUid && lhs.dataSourceId == rhs.dataSourceId
    }

    var id: String {
        "\(inputUid) \(dataSourceId ?? 0)"
    }

    var name: String = ""
    var inputUid: String = ""
    var dataSourceId: Int?
    var builtInOrientation: SettingsMic?
    @Published var connected: Bool = false

    func isAudioSession() -> Bool {
        return isBuiltin() || isExternal()
    }

    func isBuiltin() -> Bool {
        return builtInOrientation != nil
    }

    func isExternal() -> Bool {
        if isBuiltin() {
            return false
        }
        if isRtmpCameraOrMic(camera: name) {
            return false
        }
        if isSrtlaCameraOrMic(camera: name) {
            return false
        }
        if isRistCameraOrMic(camera: name) {
            return false
        }
        if isMediaPlayerCameraOrMic(camera: name) {
            return false
        }
        return true
    }

    func isAlwaysConnected() -> Bool {
        if builtInOrientation != nil {
            return true
        }
        if isMediaPlayerCameraOrMic(camera: name) {
            return true
        }
        return false
    }

    func isRtmp() -> Bool {
        return isRtmpCameraOrMic(camera: name)
    }

    func isSrtla() -> Bool {
        return isSrtlaCameraOrMic(camera: name)
    }

    func isRist() -> Bool {
        return isRistCameraOrMic(camera: name)
    }

    func isMediaPlayer() -> Bool {
        return isMediaPlayerCameraOrMic(camera: name)
    }

    enum CodingKeys: CodingKey {
        case name,
             inputUid,
             dataSourceID,
             builtInOrientation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.inputUid, inputUid)
        try container.encode(.dataSourceID, dataSourceId)
        try container.encode(.builtInOrientation, builtInOrientation)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        inputUid = container.decode(.inputUid, String.self, "")
        dataSourceId = container.decode(.dataSourceID, Int?.self, nil)
        builtInOrientation = container.decode(.builtInOrientation, SettingsMic?.self, nil)
    }
}

class SettingsMics: Codable, ObservableObject {
    @Published var mics: [SettingsMicsMic] = []
    @Published var autoSwitch: Bool = true
    var defaultMic: String = ""

    enum CodingKeys: CodingKey {
        case all,
             autoSwitch,
             defaultMic
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.all, mics)
        try container.encode(.autoSwitch, autoSwitch)
        try container.encode(.defaultMic, defaultMic)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mics = container.decode(.all, [SettingsMicsMic].self, [])
        autoSwitch = container.decode(.autoSwitch, Bool.self, true)
        defaultMic = container.decode(.defaultMic, String.self, "")
    }
}

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"

    init(from decoder: Decoder) throws {
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
    var enabled: Bool = true

    enum CodingKeys: CodingKey {
        case vin,
             privateKey,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.vin, vin)
        try container.encode(.privateKey, privateKey)
        try container.encode(.enabled, enabled)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vin = container.decode(.vin, String.self, "")
        privateKey = container.decode(.privateKey, String.self, "")
        enabled = container.decode(.enabled, Bool.self, true)
    }
}

enum SettingsDnsLookupStrategy: String, Codable, CaseIterable {
    case system = "System"
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case ipv4AndIpv6 = "IPv4 and IPv6"

    init(from decoder: Decoder) throws {
        self = try SettingsDnsLookupStrategy(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .system
    }
}

let dnsLookupStrategies = SettingsDnsLookupStrategy.allCases.map { $0.rawValue }

enum SettingsSelfieStickButtonFunction: String, Codable, CaseIterable {
    case switchScene

    init(from decoder: Decoder) throws {
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
    @Published var debugOverlay: Bool = false
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
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system
    var cameraControlsEnabled: Bool = true
    @Published var dataRateLimitFactor: Float = 2.0
    @Published var bitrateDropFix: Bool = false
    @Published var relaxedBitrate: Bool = false
    var externalDisplayChat: Bool = false
    var videoSourceWidgetTrackFace: Bool = false
    var replay: Bool = false
    var recordSegmentLength: Double = 5.0
    @Published var builtinAudioAndVideoDelay: Double = 0.0
    @Published var autoLowPowerMode: Bool = false
    @Published var newSrt: Bool = false

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
             builtinAudioAndVideoDelay,
             overrideSceneMic,
             autoLowPowerMode,
             newSrt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.logLevel, logLevel)
        try container.encode(.srtOverlay, debugOverlay)
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
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
        try container.encode(.cameraControlsEnabled, cameraControlsEnabled)
        try container.encode(.dataRateLimitFactor, dataRateLimitFactor)
        try container.encode(.bitrateDropFix, bitrateDropFix)
        try container.encode(.relaxedBitrate, relaxedBitrate)
        try container.encode(.externalDisplayChat, externalDisplayChat)
        try container.encode(.videoSourceWidgetTrackFace, videoSourceWidgetTrackFace)
        try container.encode(.replay, replay)
        try container.encode(.recordSegmentLength, recordSegmentLength)
        try container.encode(.builtinAudioAndVideoDelay, builtinAudioAndVideoDelay)
        try container.encode(.autoLowPowerMode, autoLowPowerMode)
        try container.encode(.newSrt, newSrt)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logLevel = container.decode(.logLevel, SettingsLogLevel.self, .error)
        debugOverlay = container.decode(.srtOverlay, Bool.self, false)
        srtOverheadBandwidth = container.decode(.srtOverheadBandwidth, Int32.self, 25)
        cameraSwitchRemoveBlackish = container.decode(.cameraSwitchRemoveBlackish, Float.self, 0.3)
        maximumBandwidthFollowInput = container.decode(.maximumBandwidthFollowInput, Bool.self, true)
        audioOutputToInputChannelsMap = container.decode(.audioOutputToInputChannelsMap,
                                                         SettingsDebugAudioOutputToInputChannelsMap.self,
                                                         .init())
        bluetoothOutputOnly = container.decode(.bluetoothOutputOnly, Bool.self, true)
        maximumLogLines = container.decode(.maximumLogLines, Int.self, 500)
        pixelFormat = container.decode(.pixelFormat, String.self, pixelFormats[1])
        beautyFilter = container.decode(.beautyFilter, Bool.self, false)
        beautyFilterSettings = container.decode(.beautyFilterSettings, SettingsDebugBeautyFilter.self, .init())
        allowVideoRangePixelFormat = container.decode(.allowVideoRangePixelFormat, Bool.self, false)
        blurSceneSwitch = container.decode(.blurSceneSwitch, Bool.self, true)
        metalPetalFilters = container.decode(.metalPetalFilters, Bool.self, false)
        preferStereoMic = container.decode(.preferStereoMic, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, Bool.self, false)
        removeWindNoise = container.decode(.removeWindNoise, Bool.self, false)
        httpProxy = container.decode(.httpProxy, SettingsHttpProxy.self, .init())
        tesla = container.decode(.tesla, SettingsTesla.self, .init())
        reliableChat = container.decode(.reliableChat, Bool.self, false)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
        cameraControlsEnabled = container.decode(.cameraControlsEnabled, Bool.self, true)
        dataRateLimitFactor = container.decode(.dataRateLimitFactor, Float.self, 2.0)
        bitrateDropFix = container.decode(.bitrateDropFix, Bool.self, false)
        relaxedBitrate = container.decode(.relaxedBitrate, Bool.self, false)
        externalDisplayChat = container.decode(.externalDisplayChat, Bool.self, false)
        videoSourceWidgetTrackFace = container.decode(.videoSourceWidgetTrackFace, Bool.self, false)
        replay = container.decode(.replay, Bool.self, false)
        recordSegmentLength = container.decode(.recordSegmentLength, Double.self, 5.0)
        builtinAudioAndVideoDelay = container.decode(.builtinAudioAndVideoDelay, Double.self, 0.0)
        autoLowPowerMode = container.decode(.autoLowPowerMode, Bool.self, false)
        newSrt = container.decode(.newSrt, Bool.self, false)
    }
}

class SettingsRtmpServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamKey: String = ""
    @Published var latency: Int32 = defaultRtmpLatency
    @Published var latencyString: String = .init(defaultRtmpLatency)
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             streamKey,
             latency
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamKey, streamKey)
        try container.encode(.latency, latency)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamKey = container.decode(.streamKey, String.self, "")
        latency = container.decode(.latency, Int32.self, defaultRtmpLatency)
        latencyString = String(latency)
    }

    func camera() -> String {
        return rtmpCamera(name: name)
    }

    func clone() -> SettingsRtmpServerStream {
        let new = SettingsRtmpServerStream()
        new.id = id
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        return new
    }
}

class SettingsRtmpServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 1935
    @Published var portString: String = "1935"
    @Published var streams: [SettingsRtmpServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             port,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 1935)
        portString = String(port)
        streams = container.decode(.streams, [SettingsRtmpServerStream].self, [])
    }

    func clone() -> SettingsRtmpServer {
        let new = SettingsRtmpServer()
        new.enabled = enabled
        new.port = port
        new.portString = portString
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }
}

class SettingsSrtlaServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var streamId: String = ""
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             streamId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.streamId, streamId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        streamId = container.decode(.streamId, String.self, "")
    }

    func camera() -> String {
        return srtlaCamera(name: name)
    }

    func clone() -> SettingsSrtlaServerStream {
        let new = SettingsSrtlaServerStream()
        new.name = name
        new.streamId = streamId
        return new
    }
}

class SettingsSrtlaServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var srtPort: UInt16 = 4000
    @Published var srtPortString: String = "4000"
    @Published var srtlaPort: UInt16 = 5000
    @Published var srtlaPortString: String = "5000"
    @Published var streams: [SettingsSrtlaServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             srtPort,
             srtlaPort,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.srtPort, srtPort)
        try container.encode(.srtlaPort, srtlaPort)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        srtPort = container.decode(.srtPort, UInt16.self, 4000)
        srtPortString = String(srtPort)
        srtlaPort = container.decode(.srtlaPort, UInt16.self, 5000)
        srtlaPortString = String(srtlaPort)
        streams = container.decode(.streams, [SettingsSrtlaServerStream].self, [])
    }

    func clone() -> SettingsSrtlaServer {
        let new = SettingsSrtlaServer()
        new.enabled = enabled
        new.srtPort = srtPort
        new.srtPortString = srtPortString
        new.srtlaPort = srtlaPort
        new.srtlaPortString = srtlaPortString
        for stream in streams {
            new.streams.append(stream.clone())
        }
        return new
    }

    func srtlaSrtPort() -> UInt16 {
        return srtlaPort + 1
    }
}

class SettingsRistServerStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var virtualDestinationPort: UInt16 = 1
    @Published var virtualDestinationPortString: String = "1"
    var connected: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             name,
             virtualDestinationPort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.virtualDestinationPort, virtualDestinationPort)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        virtualDestinationPort = container.decode(.virtualDestinationPort, UInt16.self, 1)
        virtualDestinationPortString = String(virtualDestinationPort)
    }

    func camera() -> String {
        return ristCamera(name: name)
    }
}

class SettingsRistServer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 6500
    @Published var portString: String = "6500"
    @Published var streams: [SettingsRistServerStream] = []

    enum CodingKeys: CodingKey {
        case enabled,
             port,
             streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 6500)
        portString = String(port)
        streams = container.decode(.streams, [SettingsRistServerStream].self, [])
    }

    func makeUniqueVirtualDestinationPort() -> UInt16 {
        var port: UInt16 = 1
        while streams.contains(where: { $0.virtualDestinationPort == port }) {
            port += 1
        }
        return port
    }
}

class SettingsRtspClientStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = ""
    @Published var enabled: Bool = false
    @Published var latency: Int32 = 2000
    @Published var latencyString: String = "2000"

    enum CodingKeys: CodingKey {
        case id,
             name,
             url,
             enabled,
             latency
    }

    func latencySeconds() -> Double {
        return Double(latency) / 1000
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
        try container.encode(.latency, latency)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        latency = container.decode(.latency, Int32.self, 2000)
        latencyString = String(latency)
    }

    func camera() -> String {
        return rtspCamera(name: name)
    }
}

class SettingsRtspClient: Codable, ObservableObject {
    @Published var streams: [SettingsRtspClientStream] = []

    enum CodingKeys: CodingKey {
        case streams
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsRtspClientStream].self, [])
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

class SettingsMediaPlayer: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My player")
    var id: UUID = .init()
    @Published var name: String = baseName
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
        name = container.decode(.name, String.self, Self.baseName)
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

class SettingsDjiDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var wifiSsid: String = ""
    @Published var wifiPassword: String = ""
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
        name = container.decode(.name, String.self, Self.baseName)
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

class SettingsGoProWifiCredentials: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My SSID")
    var id: UUID = .init()
    @Published var name = baseName
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
        name = container.decode(.name, String.self, Self.baseName)
        ssid = container.decode(.ssid, String.self, "")
        password = container.decode(.password, String.self, "")
    }
}

class SettingsGoProRtmpUrl: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My URL")
    var id: UUID = .init()
    @Published var name = baseName
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
        name = container.decode(.name, String.self, Self.baseName)
        type = container.decode(.type, SettingsDjiDeviceUrlType.self, .server)
        serverStreamId = container.decode(.serverStreamId, UUID.self, .init())
        serverUrl = container.decode(.serverUrl, String.self, "")
        customUrl = container.decode(.customUrl, String.self, "")
    }
}

enum SettingsGoProLaunchLiveStreamResolution: String, CaseIterable, Codable {
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"

    init(from decoder: Decoder) throws {
        self = try SettingsGoProLaunchLiveStreamResolution(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .r1080p
    }
}

class SettingsGoProLaunchLiveStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My live")
    var id: UUID = .init()
    @Published var name = baseName
    @Published var isHero12Or13: Bool = true
    @Published var resolution: SettingsGoProLaunchLiveStreamResolution = .r1080p

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             isHero12Or13,
             resolution
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.isHero12Or13, isHero12Or13)
        try container.encode(.resolution, resolution)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        isHero12Or13 = container.decode(.isHero12Or13, Bool.self, true)
        resolution = container.decode(.resolution, SettingsGoProLaunchLiveStreamResolution.self, .r1080p)
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

    init(from decoder: Decoder) throws {
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

class SettingsReplay: Codable, ObservableObject {
    static let stop: Double = 30.0
    @Published var start: Double = 20.0
    @Published var stop: Double = SettingsReplay.stop
    @Published var speed: SettingsReplaySpeed = .one

    init() {}

    enum CodingKeys: CodingKey {
        case start,
             stop,
             speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.start, start)
        try container.encode(.stop, stop)
        try container.encode(.speed, speed)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = container.decode(.start, Double.self, 20.0)
        stop = container.decode(.stop, Double.self, SettingsReplay.stop)
        speed = container.decode(.speed, SettingsReplaySpeed.self, .one)
    }
}

class SettingsCatPrinter: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My printer")
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

class SettingsCyclingPowerDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
    }
}

class SettingsCyclingPowerDevices: Codable, ObservableObject {
    @Published var devices: [SettingsCyclingPowerDevice] = []

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
        devices = container.decode(.devices, [SettingsCyclingPowerDevice].self, [])
    }
}

class SettingsHeartRateDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
    }
}

class SettingsHeartRateDevices: Codable, ObservableObject {
    @Published var devices: [SettingsHeartRateDevice] = []

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
        devices = container.decode(.devices, [SettingsHeartRateDevice].self, [])
    }
}

private let defaultRgbLightColor = RgbColor(red: 0, green: 255, blue: 0)

class SettingsBlackSharkCoolerDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My cooler")
    var id: UUID = .init()
    @Published var name: String = baseName
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
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        rgbLightEnabled = container.decode(.rgbLightEnabled, Bool.self, false)
        rgbLightColor = container.decode(.rgbLightColor, RgbColor.self, defaultRgbLightColor)
        rgbLightColorColor = rgbLightColor.color()
        rgbLightBrightness = container.decode(.rgbLightBrightness, Double.self, 100.0)
    }
}

class SettingsBlackSharkCoolerDevices: Codable, ObservableObject {
    @Published var devices: [SettingsBlackSharkCoolerDevice] = []

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
        devices = container.decode(.devices, [SettingsBlackSharkCoolerDevice].self, [])
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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
    @Published var widgetId: UUID = .init()

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

class SettingsRemoteControlAssistant: Codable, ObservableObject, Identifiable, Named {
    static let baseName = String(localized: "Streamer name")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = true
    @Published var port: UInt16 = 2345
    var relay: SettingsRemoteControlServerRelay = .init()

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             port,
             relay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.relay, relay)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, true)
        port = container.decode(.port, UInt16.self, 2345)
        relay = container.decode(.relay, SettingsRemoteControlServerRelay.self, .init())
    }
}

class SettingsRemoteControlStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var url: String = ""
    @Published var previewFps: Float = 1.0

    enum CodingKeys: CodingKey {
        case enabled,
             url,
             previewFps
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.previewFps, previewFps)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        url = container.decode(.url, String.self, "")
        previewFps = container.decode(.previewFps, Float.self, 1.0)
    }
}

class SettingsRemoteControlServerRelay: Codable, ObservableObject {
    @Published var enabled: Bool = true
    @Published var baseUrl: String = "wss://moblin.mys-lang.org/moblin-remote-control-relay"
    @Published var bridgeId: String = UUID().uuidString.lowercased()

    enum CodingKeys: CodingKey {
        case enabled,
             baseUrl,
             bridgeId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.baseUrl, baseUrl)
        try container.encode(.bridgeId, bridgeId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        baseUrl = container.decode(.baseUrl, String.self, "wss://moblin.mys-lang.org/moblin-remote-control-relay")
        bridgeId = container.decode(.bridgeId, String.self, UUID().uuidString.lowercased())
    }
}

class SettingsRemoteControl: Codable, ObservableObject {
    var assistant: SettingsRemoteControlAssistant = .init()
    var streamer: SettingsRemoteControlStreamer = .init()
    var password: String = randomGoodPassword()
    @Published var streamers: [SettingsRemoteControlAssistant] = []
    @Published var selectedStreamer: UUID?
    var hasMigratedAssistant: Bool = true

    enum CodingKeys: CodingKey {
        case client,
             server,
             password,
             streamers,
             selectedStreamer,
             hasMigratedAssistant
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.client, assistant)
        try container.encode(.server, streamer)
        try container.encode(.password, password)
        try container.encode(.streamers, streamers)
        try container.encode(.selectedStreamer, selectedStreamer)
        try container.encode(.hasMigratedAssistant, hasMigratedAssistant)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistant = container.decode(.client, SettingsRemoteControlAssistant.self, .init())
        streamer = container.decode(.server, SettingsRemoteControlStreamer.self, .init())
        password = container.decode(.password, String.self, randomGoodPassword())
        streamers = container.decode(.streamers, [SettingsRemoteControlAssistant].self, [])
        selectedStreamer = container.decode(.selectedStreamer, UUID?.self, nil)
        hasMigratedAssistant = container.decode(.hasMigratedAssistant, Bool.self, false)
        if !hasMigratedAssistant {
            let streamer = SettingsRemoteControlAssistant()
            streamer.name = "Streamer"
            streamer.enabled = assistant.enabled
            streamer.port = assistant.port
            streamer.relay.enabled = assistant.relay.enabled
            streamer.relay.baseUrl = assistant.relay.baseUrl
            streamer.relay.bridgeId = assistant.relay.bridgeId
            streamers.append(streamer)
            selectedStreamer = streamer.id
            hasMigratedAssistant = true
        }
    }

    func getSelectedStreamerName() -> String? {
        return streamers.first(where: { $0.id == selectedStreamer })?.name
    }
}

class SettingsMoblinkStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 7777

    enum CodingKeys: CodingKey {
        case enabled,
             port
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 7777)
    }
}

class SettingsMoblinkRelay: Codable, ObservableObject {
    @Published var enabled: Bool = false
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
    var streamer: SettingsMoblinkStreamer = .init()
    var relay: SettingsMoblinkRelay = .init()
    var password = "1234"

    enum CodingKeys: CodingKey {
        case server,
             client,
             password
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.server, streamer)
        try container.encode(.client, relay)
        try container.encode(.password, password)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamer = container.decode(.server, SettingsMoblinkStreamer.self, .init())
        relay = container.decode(.client, SettingsMoblinkRelay.self, .init())
        password = container.decode(.password, String.self, "1234")
    }
}

enum SettingsSceneSwitchTransition: String, Codable, CaseIterable {
    case blur = "Blur"
    case freeze = "Freeze"
    case blurAndZoom = "Blur & zoom"

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

private func formatMeters(value: Int) -> String {
    if value == 1 {
        return String(localized: "\(value) meter")
    } else {
        return String(localized: "\(value) meters")
    }
}

enum SettingsLocationDesiredAccuracy: Codable, CaseIterable {
    case best
    case nearestTenMeters
    case hundredMeters

    func toString() -> String {
        switch self {
        case .best:
            return String(localized: "Best")
        case .nearestTenMeters:
            return formatMeters(value: 10)
        case .hundredMeters:
            return formatMeters(value: 100)
        }
    }
}

enum SettingsLocationDistanceFilter: Codable, CaseIterable {
    case none
    case oneMeter
    case threeMeters
    case fiveMeters
    case tenMeters
    case twentyMeters
    case fiftyMeters
    case hundredMeters
    case twoHundredMeters

    func toString() -> String {
        switch self {
        case .none:
            return String(localized: "None")
        case .oneMeter:
            return formatMeters(value: 1)
        case .threeMeters:
            return formatMeters(value: 3)
        case .fiveMeters:
            return formatMeters(value: 5)
        case .tenMeters:
            return formatMeters(value: 10)
        case .twentyMeters:
            return formatMeters(value: 20)
        case .fiftyMeters:
            return formatMeters(value: 50)
        case .hundredMeters:
            return formatMeters(value: 100)
        case .twoHundredMeters:
            return formatMeters(value: 200)
        }
    }
}

class SettingsLocation: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var privacyRegions: [SettingsPrivacyRegion] = []
    @Published var distance: Double = 0.0
    @Published var resetWhenGoingLive: Bool = false
    @Published var desiredAccuracy: SettingsLocationDesiredAccuracy = .best
    @Published var distanceFilter: SettingsLocationDistanceFilter = .none

    enum CodingKeys: CodingKey {
        case enabled,
             privacyRegions,
             distance,
             resetWhenGoingLive,
             desiredAccuracy,
             distanceFilter
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.privacyRegions, privacyRegions)
        try container.encode(.distance, distance)
        try container.encode(.resetWhenGoingLive, resetWhenGoingLive)
        try container.encode(.desiredAccuracy, desiredAccuracy)
        try container.encode(.distanceFilter, distanceFilter)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        privacyRegions = container.decode(.privacyRegions, [SettingsPrivacyRegion].self, [])
        distance = container.decode(.distance, Double.self, 0.0)
        resetWhenGoingLive = container.decode(.resetWhenGoingLive, Bool.self, false)
        desiredAccuracy = container.decode(.desiredAccuracy, SettingsLocationDesiredAccuracy.self, .best)
        distanceFilter = container.decode(.distanceFilter, SettingsLocationDistanceFilter.self, .none)
    }
}

class SettingsAudioOutputToInputChannelsMap: Codable {
    var channel1: Int = 0
    var channel2: Int = 1
}

class AudioSettings: Codable {
    var audioOutputToInputChannelsMap: SettingsAudioOutputToInputChannelsMap? = .init()
}

class WebBrowserBookmarkSettings: Identifiable, Codable, ObservableObject {
    var id: UUID = .init()
    @Published var url: String = "https://google.com"

    enum CodingKeys: CodingKey {
        case url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.url, url)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.decode(.url, String.self, "https://google.com")
    }
}

class WebBrowserSettings: Codable, ObservableObject {
    @Published var home: String = "https://google.com"
    @Published var bookmarks: [WebBrowserBookmarkSettings] = []

    enum CodingKeys: CodingKey {
        case home,
             bookmarks
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.home, home)
        try container.encode(.bookmarks, bookmarks)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        home = container.decode(.home, String.self, "https://google.com")
        bookmarks = container.decode(.bookmarks, [WebBrowserBookmarkSettings].self, [])
    }
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

class SettingsDisconnectProtection: Codable, ObservableObject {
    @Published var liveSceneId: UUID?
    @Published var fallbackSceneId: UUID?

    enum CodingKeys: CodingKey {
        case liveSceneId,
             fallbackSceneId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.liveSceneId, liveSceneId)
        try container.encode(.fallbackSceneId, fallbackSceneId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        liveSceneId = container.decode(.liveSceneId, UUID?.self, .init())
        fallbackSceneId = container.decode(.fallbackSceneId, UUID?.self, .init())
    }
}

class Database: Codable, ObservableObject {
    @Published var streams: [SettingsStream] = []
    @Published var scenes: [SettingsScene] = []
    @Published var widgets: [SettingsWidget] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    @Published var tapToFocus: Bool = false
    @Published var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var mic: SettingsMic = getDefaultMic()
    var mics: SettingsMics = .init()
    var debug: SettingsDebug = .init()
    var quickButtonsGeneral: SettingsQuickButtons = .init()
    @Published var quickButtons: [SettingsQuickButton] = []
    var rtmpServer: SettingsRtmpServer = .init()
    @Published var networkInterfaceNames: [SettingsNetworkInterfaceName] = []
    @Published var lowBitrateWarning: Bool = true
    @Published var vibrate: Bool = false
    @Published var gameControllers: [SettingsGameController] = [.init()]
    var remoteControl: SettingsRemoteControl = .init()
    @Published var startStopRecordingConfirmations: Bool = true
    var color: SettingsColor = .init()
    @Published var mirrorFrontCameraOnStream: Bool = true
    var streamButtonColor: RgbColor = defaultStreamButtonColor
    @Published var streamButtonColorColor: Color = defaultStreamButtonColor.color()
    var location: SettingsLocation = .init()
    var watch: WatchSettings = .init()
    var audio: AudioSettings = .init()
    var webBrowser: WebBrowserSettings = .init()
    var deepLinkCreator: DeepLinkCreator = .init()
    var srtlaServer: SettingsSrtlaServer = .init()
    var mediaPlayers: SettingsMediaPlayers = .init()
    @Published var showAllSettings: Bool = false
    @Published var portrait: Bool = false
    var djiDevices: SettingsDjiDevices = .init()
    var alertsMediaGallery: SettingsAlertsMediaGallery = .init()
    var catPrinters: SettingsCatPrinters = .init()
    @Published var verboseStatuses: Bool = false
    @Published var scoreboardPlayers: [SettingsWidgetScoreboardPlayer] = .init()
    var keyboard: SettingsKeyboard = .init()
    var tesla: SettingsTesla = .init()
    var srtlaRelay: SettingsMoblink = .init()
    @Published var pixellateStrength: Float = 0.3
    var moblink: SettingsMoblink = .init()
    @Published var sceneSwitchTransition: SettingsSceneSwitchTransition = .blur
    @Published var forceSceneSwitchTransition: Bool = false
    @Published var cameraControlsEnabled: Bool = true
    @Published var externalDisplayContent: SettingsExternalDisplayContent = .stream
    var cyclingPowerDevices: SettingsCyclingPowerDevices = .init()
    var heartRateDevices: SettingsHeartRateDevices = .init()
    var blackSharkCoolerDevices: SettingsBlackSharkCoolerDevices = .init()
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
    var ristServer: SettingsRistServer = .init()
    var disconnectProtection: SettingsDisconnectProtection = .init()
    var rtspClient: SettingsRtspClient = .init()

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
             bigButtons,
             ristServer,
             disconnectProtection,
             rtspClient
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
        try container.encode(.phoneCoolerDevices, blackSharkCoolerDevices)
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
        try container.encode(.ristServer, ristServer)
        try container.encode(.disconnectProtection, disconnectProtection)
        try container.encode(.rtspClient, rtspClient)
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
        streamButtonColorColor = streamButtonColor.color()
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
        blackSharkCoolerDevices = container.decode(.phoneCoolerDevices, SettingsBlackSharkCoolerDevices.self, .init())
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
        ristServer = container.decode(.ristServer, SettingsRistServer.self, .init())
        disconnectProtection = container.decode(.disconnectProtection, SettingsDisconnectProtection.self, .init())
        rtspClient = container.decode(.rtspClient, SettingsRtspClient.self, .init())
    }
}

private func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.cameraPosition = getDefaultBackCameraPosition()
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
                x: x
            ))
        }
    } else {
        database.zoom.back = [
            SettingsZoomPreset(id: UUID(), name: "0.5x", x: 0.5),
            SettingsZoomPreset(id: UUID(), name: "1x", x: 1.0),
            SettingsZoomPreset(id: UUID(), name: "2x", x: 2.0),
            SettingsZoomPreset(id: UUID(), name: "4x", x: 4.0),
            SettingsZoomPreset(id: UUID(), name: "8x", x: 8.0),
        ]
    }
}

private func addDefaultFrontZoomPresets(database: Database) {
    database.zoom.front = [
        SettingsZoomPreset(id: UUID(), name: "0.5x", x: 0.5),
        SettingsZoomPreset(id: UUID(), name: "1x", x: 1.0),
        SettingsZoomPreset(id: UUID(), name: "2x", x: 2.0),
        SettingsZoomPreset(id: UUID(), name: "4x", x: 4.0),
        SettingsZoomPreset(id: UUID(), name: "8x", x: 8.0),
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

    button = SettingsQuickButton(name: String(localized: "Scene widgets"))
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

    button = SettingsQuickButton(name: String(localized: "Camera level"))
    button.id = UUID()
    button.type = .cameraLevel
    button.imageType = "System name"
    button.systemImageNameOn = "level.fill"
    button.systemImageNameOff = "level"
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
        store()
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
        for stream in realDatabase.streams {
            for priority in stream.srt.connectionPriorities.priorities where priority.enabled == nil {
                priority.enabled = true
                store()
            }
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
        for widget in realDatabase.widgets where widget.map.northUp == nil {
            widget.map.northUp = false
            store()
        }
        for widget in database.widgets where widget.map.delay == nil {
            widget.map.delay = 0.0
            store()
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
                        case .r960x540:
                            width = 960
                            height = 540
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
                        sceneWidget.width = (100 * Double(widget.map.width) / width).clamped(to: 1 ... 100)
                        sceneWidget.height = (100 * Double(widget.map.height) / height).clamped(to: 1 ... 100)
                    }
                }
            }
            store()
        }
        let allLuts = realDatabase.color.bundledLuts + realDatabase.color.diskLuts
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
        for widget in realDatabase.widgets {
            for command in widget.alerts.chatBot.commands where command.imageType == nil {
                command.imageType = .file
                store()
            }
            for command in widget.alerts.chatBot.commands where command.imagePlaygroundImageId == nil {
                command.imagePlaygroundImageId = .init()
                store()
            }
        }
        for button in realDatabase.quickButtons where button.page == nil {
            button.page = 1
            store()
        }
    }
}
