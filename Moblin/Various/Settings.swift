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

    func dimensions() -> CMVideoDimensions {
        switch self {
        case .r3840x2160:
            return .init(width: 3840, height: 2160)
        case .r2560x1440:
            return .init(width: 2560, height: 1440)
        case .r1920x1080:
            return .init(width: 1920, height: 1080)
        case .r1280x720:
            return .init(width: 1280, height: 720)
        case .r854x480:
            return .init(width: 854, height: 480)
        case .r640x360:
            return .init(width: 640, height: 360)
        case .r426x240:
            return .init(width: 426, height: 240)
        }
    }
}

let resolutions = SettingsStreamResolution.allCases

let fpss = ["60", "50", "30", "25", "15"]

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

    static func fromString(value: String) -> SettingsStreamSrtAdaptiveBitrateAlgorithm {
        switch value {
        case String(localized: "Fast IRL"):
            return .fastIrl
        case String(localized: "Slow IRL"):
            return .slowIrl
        case String(localized: "Custom IRL"):
            return .customIrl
        case String(localized: "BELABOX"):
            return .belabox
        default:
            return .fastIrl
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

let adaptiveBitrateAlgorithms = SettingsStreamSrtAdaptiveBitrateAlgorithm.allCases.map { $0.toString() }

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

class SettingsStreamTwitchReward: Codable, Identifiable {
    var id: UUID = .init()
    // periphery:ignore
    var rewardId: String = ""
    var title: String = ""
    // periphery:ignore
    var alert: SettingsWidgetAlertsAlert = .init()
}

class SettingsStream: Codable, Identifiable, Equatable {
    static func == (lhs: SettingsStream, rhs: SettingsStream) -> Bool {
        lhs.id == rhs.id
    }

    var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    var url: String = defaultStreamUrl
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var twitchShowFollows: Bool? = true
    var twitchAccessToken: String? = ""
    var twitchLoggedIn: Bool? = false
    var twitchRewards: [SettingsStreamTwitchReward]? = []
    var kickChatroomId: String = ""
    var kickChannelName: String? = ""
    var youTubeApiKey: String? = ""
    var youTubeVideoId: String? = ""
    var afreecaTvChannelName: String? = ""
    var afreecaTvStreamId: String? = ""
    var openStreamingPlatformUrl: String? = ""
    var openStreamingPlatformChannelId: String? = ""
    var obsWebSocketEnabled: Bool? = false
    var obsWebSocketUrl: String? = ""
    var obsWebSocketPassword: String? = ""
    var obsSourceName: String? = ""
    var obsMainScene: String? = ""
    var obsBrbScene: String? = ""
    var obsBrbSceneVideoSourceBroken: Bool? = false
    var obsAutoStartStream: Bool? = false
    var obsAutoStopStream: Bool? = false
    var obsAutoStartRecording: Bool? = false
    var obsAutoStopRecording: Bool? = false
    var discordSnapshotWebhook: String? = ""
    var discordChatBotSnapshotWebhook: String? = ""
    var discordSnapshotWebhookOnlyWhenLive: Bool? = true
    var resolution: SettingsStreamResolution = .r1920x1080
    var fps: Int = 30
    var autoFps: Bool? = false
    var bitrate: UInt32 = 5_000_000
    var codec: SettingsStreamCodec = .h265hevc
    var bFrames: Bool? = false
    var adaptiveEncoderResolution: Bool? = false
    var adaptiveBitrate: Bool? = true
    var srt: SettingsStreamSrt = .init()
    var rtmp: SettingsStreamRtmp? = .init()
    var rist: SettingsStreamRist? = .init()
    var captureSessionPresetEnabled: Bool? = false
    var captureSessionPreset: SettingsCaptureSessionPreset? = .medium
    var maxKeyFrameInterval: Int32? = 2
    var audioBitrate: Int? = 128_000
    var chat: SettingsStreamChat? = .init()
    var recording: SettingsStreamRecording? = .init()
    var realtimeIrlEnabled: Bool? = false
    var realtimeIrlPushKey: String? = ""
    var portrait: Bool? = false
    var backgroundStreaming: Bool? = false
    var estimatedViewerDelay: Float? = 8.0
    var twitchMultiTrackEnabled: Bool? = false
    var ntpPoolAddress: String? = "time.apple.com"
    var timecodesEnabled: Bool? = false

    init(name: String) {
        self.name = name
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
        new.rtmp = rtmp!.clone()
        new.rist = rist!.clone()
        new.captureSessionPresetEnabled = captureSessionPresetEnabled
        new.captureSessionPreset = captureSessionPreset
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.chat = chat?.clone()
        new.recording = recording?.clone()
        new.realtimeIrlEnabled = realtimeIrlEnabled
        new.realtimeIrlPushKey = realtimeIrlPushKey
        new.portrait = portrait
        new.backgroundStreaming = backgroundStreaming
        new.estimatedViewerDelay = estimatedViewerDelay
        new.twitchMultiTrackEnabled = twitchMultiTrackEnabled
        new.ntpPoolAddress = ntpPoolAddress
        new.timecodesEnabled = timecodesEnabled
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
        if getProtocol() == .rist && rist!.bonding {
            return true
        }
        return false
    }

    func resolutionString() -> String {
        return resolution.shortString()
    }

    func codecString() -> String {
        return codec.shortString()
    }

    func bitrateString() -> String {
        var bitrate = formatBytesPerSecond(speed: Int64(bitrate))
        if getProtocol() == .srt && (srt.adaptiveBitrateEnabled ?? false) {
            bitrate = "<\(bitrate)"
        } else if getProtocol() == .rtmp && (rtmp?.adaptiveBitrateEnabled ?? false) {
            bitrate = "<\(bitrate)"
        }
        return bitrate
    }

    func audioBitrateString() -> String {
        return formatBytesPerSecond(speed: Int64(audioBitrate!))
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
}

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

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = true
    var cameraType: SettingsSceneCameraPosition = .back
    var cameraPosition: SettingsSceneCameraPosition? = .back
    var backCameraId: String? = getBestBackCameraId()
    var frontCameraId: String? = getBestFrontCameraId()
    var rtmpCameraId: UUID? = .init()
    var srtlaCameraId: UUID? = .init()
    var mediaPlayerCameraId: UUID? = .init()
    var externalCameraId: String? = ""
    var externalCameraName: String? = ""
    var widgets: [SettingsSceneWidget] = []
    var videoSourceRotation: Double? = 0.0
    var videoStabilizationMode: SettingsVideoStabilizationMode? = .off
    var overrideVideoStabilizationMode: Bool? = false
    var fillFrame: Bool? = false

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsScene, rhs: SettingsScene) -> Bool {
        return lhs.id == rhs.id
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
        switch cameraPosition! {
        case .back:
            return .back(id: backCameraId!)
        case .front:
            return .front(id: frontCameraId!)
        case .rtmp:
            return .rtmp(id: rtmpCameraId!)
        case .external:
            return .external(id: externalCameraId!, name: externalCameraName!)
        case .srtla:
            return .srtla(id: srtlaCameraId!)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId!)
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

enum SettingsFontDesign: String, Codable, CaseIterable {
    case `default` = "Default"
    case serif = "Serif"
    case rounded = "Rounded"
    case monospaced = "Monospaced"

    public init(from decoder: Decoder) throws {
        self = try SettingsFontDesign(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .default
    }

    static func fromString(value: String) -> SettingsFontDesign {
        switch value {
        case String(localized: "Default"):
            return .default
        case String(localized: "Serif"):
            return .serif
        case String(localized: "Rounded"):
            return .rounded
        case String(localized: "Monospaced"):
            return .monospaced
        default:
            return .default
        }
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

let textWidgetFontDesigns = SettingsFontDesign.allCases.map { $0.toString() }

enum SettingsFontWeight: String, Codable, CaseIterable {
    case regular = "Regular"
    case light = "Light"
    case bold = "Bold"

    public init(from decoder: Decoder) throws {
        self = try SettingsFontWeight(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .regular
    }

    static func fromString(value: String) -> SettingsFontWeight {
        switch value {
        case String(localized: "Regular"):
            return .regular
        case String(localized: "Light"):
            return .light
        case String(localized: "Bold"):
            return .bold
        default:
            return .regular
        }
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

let textWidgetFontWeights = SettingsFontWeight.allCases.map { $0.toString() }

enum SettingsHorizontalAlignment: String, Codable, CaseIterable {
    case leading = "Leading"
    case trailing = "Trailing"

    public init(from decoder: Decoder) throws {
        self = try SettingsHorizontalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .leading
    }

    static func fromString(value: String) -> SettingsHorizontalAlignment {
        switch value {
        case String(localized: "Leading"):
            return .leading
        case String(localized: "Trailing"):
            return .trailing
        default:
            return .leading
        }
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

let textWidgetHorizontalAlignments = SettingsHorizontalAlignment.allCases.map { $0.toString() }

enum SettingsVerticalAlignment: String, Codable, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"

    public init(from decoder: Decoder) throws {
        self = try SettingsVerticalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .top
    }

    static func fromString(value: String) -> SettingsVerticalAlignment {
        switch value {
        case String(localized: "Top"):
            return .top
        case String(localized: "Bottom"):
            return .bottom
        default:
            return .top
        }
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

let textWidgetVerticalAlignments = SettingsVerticalAlignment.allCases.map { $0.toString() }

class SettingsWidgetTextTimer: Codable, Identifiable {
    var id: UUID = .init()
    var delta: Int = 5
    var endTime: Double = 0
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

class SettingsWidgetText: Codable {
    var formatString: String = "{shortTime}"
    var backgroundColor: RgbColor? = .init(red: 0, green: 0, blue: 0, opacity: 0.75)
    var clearBackgroundColor: Bool? = false
    var foregroundColor: RgbColor? = .init(red: 255, green: 255, blue: 255)
    var clearForegroundColor: Bool? = false
    var fontSize: Int? = 30
    var fontDesign: SettingsFontDesign? = .default
    var fontWeight: SettingsFontWeight? = .regular
    var fontMonospacedDigits: Bool? = false
    var alignment: SettingsHorizontalAlignment? = .leading
    var horizontalAlignment: SettingsHorizontalAlignment? = .leading
    var verticalAlignment: SettingsVerticalAlignment? = .top
    var delay: Double? = 0.0
    var timers: [SettingsWidgetTextTimer]? = []
    var needsWeather: Bool? = false
    var needsGeography: Bool? = false
    var needsSubtitles: Bool? = false
    var checkboxes: [SettingsWidgetTextCheckbox]? = []
    var ratings: [SettingsWidgetTextRating]? = []
    var lapTimes: [SettingsWidgetTextLapTimes]? = []
}

class SettingsWidgetCrop: Codable {
    var sourceWidgetId: UUID = .init()
    var x: Int = 0
    var y: Int = 0
    var width: Int = 200
    var height: Int = 200
}

class SettingsWidgetBrowser: Codable {
    var url: String = ""
    var width: Int = 500
    var height: Int = 500
    var audioOnly: Bool? = false
    var scaleToFitVideo: Bool? = false
    var fps: Float? = 5.0
    var styleSheet: String? = ""
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

    static func fromString(value: String) -> SettingsWidgetAlertPositionType {
        switch value {
        case String(localized: "Scene"):
            return .scene
        case String(localized: "Face"):
            return .face
        default:
            return .scene
        }
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

let alertPositionTypes = SettingsWidgetAlertPositionType.allCases.map { $0.toString() }

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

    static func fromString(value: String) -> SettingsWidgetAlertsChatBotCommandImageType {
        switch value {
        case String(localized: "File"):
            return .file
        case String(localized: "Image Playground"):
            return .imagePlayground
        default:
            return .file
        }
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

let chatBotCommandImageTypes = SettingsWidgetAlertsChatBotCommandImageType.allCases.map { $0.toString() }

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

class SettingsWidgetVideoSource: Codable {
    var cornerRadius: Float = 0
    var cameraPosition: SettingsSceneCameraPosition? = .screenCapture
    var backCameraId: String? = getBestBackCameraId()
    var frontCameraId: String? = getBestFrontCameraId()
    var rtmpCameraId: UUID? = .init()
    var srtlaCameraId: UUID? = .init()
    var mediaPlayerCameraId: UUID? = .init()
    var externalCameraId: String? = ""
    var externalCameraName: String? = ""
    var cropEnabled: Bool? = false
    var cropX: Double? = 0.25
    var cropY: Double? = 0.0
    var cropWidth: Double? = 0.5
    var cropHeight: Double? = 1.0
    var rotation: Double? = 0.0
    var trackFaceEnabled: Bool? = false
    var trackFaceZoom: Double? = 0.75
    var mirror: Bool? = false
    var borderWidth: Double? = 0
    var borderColor: RgbColor? = .init(red: 0, green: 0, blue: 0)

    func toEffectSettings() -> VideoSourceEffectSettings {
        return .init(cornerRadius: cornerRadius,
                     cropEnabled: cropEnabled!,
                     cropX: cropX!,
                     cropY: cropY!,
                     cropWidth: cropWidth!,
                     cropHeight: cropHeight!,
                     rotation: rotation!,
                     trackFaceEnabled: trackFaceEnabled!,
                     trackFaceZoom: 1.5 + (1 - trackFaceZoom!) * 4,
                     mirror: mirror!,
                     borderWidth: borderWidth!,
                     borderColor: CIColor(
                         red: Double(borderColor!.red) / 255,
                         green: Double(borderColor!.green) / 255,
                         blue: Double(borderColor!.blue) / 255
                     ))
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition! {
        case .back:
            return .back(id: backCameraId!)
        case .front:
            return .front(id: frontCameraId!)
        case .rtmp:
            return .rtmp(id: rtmpCameraId!)
        case .external:
            return .external(id: externalCameraId!, name: externalCameraName!)
        case .srtla:
            return .srtla(id: srtlaCameraId!)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId!)
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

    static func fromString(value: String) -> SettingsWidgetScoreboardType {
        switch value {
        case String(localized: "Padel"):
            return .padel
        default:
            return .padel
        }
    }

    func toString() -> String {
        switch self {
        case .padel:
            return String(localized: "Padel")
        }
    }
}

let scoreboardTypes = SettingsWidgetScoreboardType.allCases.map { $0.toString() }

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

    static func fromString(value: String) -> SettingsWidgetPadelScoreboardGameType {
        switch value {
        case String(localized: "Doubles"):
            return .doubles
        case String(localized: "Singles"):
            return .singles
        default:
            return .doubles
        }
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

let scoreboardGameTypes = SettingsWidgetPadelScoreboardGameType.allCases.map { $0.toString() }

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

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .text
    }

    static func fromString(value: String) -> SettingsWidgetType {
        switch value {
        case String(localized: "Browser"):
            return .browser
        case String(localized: "Image"):
            return .image
        case String(localized: "Text"):
            return .text
        case String(localized: "Video effect"):
            return .videoEffect
        case String(localized: "Crop"):
            return .crop
        case String(localized: "Map"):
            return .map
        case String(localized: "Scene"):
            return .scene
        case String(localized: "QR code"):
            return .qrCode
        case String(localized: "Alerts"):
            return .alerts
        case String(localized: "Video source"):
            return .videoSource
        case String(localized: "Scoreboard"):
            return .scoreboard
        default:
            return .videoEffect
        }
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
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases
    .filter { $0 != .videoEffect }
    .map { $0.toString() }

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .browser
    var text: SettingsWidgetText = .init()
    var browser: SettingsWidgetBrowser = .init()
    var crop: SettingsWidgetCrop? = .init()
    var map: SettingsWidgetMap? = .init()
    var scene: SettingsWidgetScene? = .init()
    var qrCode: SettingsWidgetQrCode? = .init()
    var alerts: SettingsWidgetAlerts? = .init()
    var videoSource: SettingsWidgetVideoSource? = .init()
    var scoreboard: SettingsWidgetScoreboard? = .init()
    var enabled: Bool? = true

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsWidget, rhs: SettingsWidget) -> Bool {
        return lhs.id == rhs.id
    }
}

enum SettingsButtonType: String, Codable, CaseIterable {
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

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Chat"
        }
        self = SettingsButtonType(rawValue: value) ?? .unknown
    }
}

class SettingsButton: Codable, Identifiable, Equatable, Hashable {
    var name: String
    var id: UUID = .init()
    var type: SettingsButtonType = .widget
    // periphery:ignore
    var imageType: String? = "System name"
    var systemImageNameOn: String = "mic.slash"
    var systemImageNameOff: String = "mic"
    var isOn: Bool = false
    var enabled: Bool? = true
    var backgroundColor: RgbColor? = defaultQuickButtonColor

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsButton, rhs: SettingsButton) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

class SettingsShow: Codable {
    var chat: Bool = true
    var viewers: Bool = true
    var uptime: Bool = true
    var stream: Bool = false
    var speed: Bool = true
    var audioLevel: Bool = true
    var zoom: Bool = false
    var zoomPresets: Bool = true
    var microphone: Bool = false
    // periphery:ignore
    var audioBar: Bool? = true
    var cameras: Bool? = false
    var obsStatus: Bool? = true
    var rtmpSpeed: Bool? = true
    var gameController: Bool? = true
    var location: Bool? = true
    var remoteControl: Bool? = true
    var browserWidgets: Bool? = true
    var bonding: Bool? = true
    var events: Bool? = true
    var djiDevices: Bool? = true
    var bondingRtts: Bool? = false
    var moblink: Bool? = true
    var catPrinter: Bool? = true
    var cyclingPowerDevice: Bool? = true
    var heartRateDevice: Bool? = true
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

class SettingsBitratePreset: Codable, Identifiable {
    var id: UUID
    var bitrate: UInt32 = 5_000_000

    init(id: UUID, bitrate: UInt32) {
        self.id = id
        self.bitrate = bitrate
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

    static func fromString(value: String) -> SettingsVideoStabilizationMode {
        switch value {
        case String(localized: "Off"):
            return .off
        case String(localized: "Standard"):
            return .standard
        case String(localized: "Cinematic"):
            return .cinematic
        case String(localized: "Cinematic extended enhanced"):
            return .cinematicExtendedEnhanced
        default:
            return .off
        }
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
    .map { $0.toString() }

class SettingsChatUsername: Identifiable, Codable {
    var id = UUID()
    var value: String = ""
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
}

class SettingsChat: Codable {
    var fontSize: Float = 19.0
    var usernameColor: RgbColor = .init(red: 255, green: 163, blue: 0)
    var messageColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    var backgroundColorEnabled: Bool = false
    var shadowColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    var shadowColorEnabled: Bool = true
    var boldUsername: Bool = true
    var boldMessage: Bool = true
    var animatedEmotes: Bool = false
    var timestampColor: RgbColor = .init(red: 180, green: 180, blue: 180)
    var timestampColorEnabled: Bool = false
    var height: Double? = 0.7
    var width: Double? = 1.0
    var maximumAge: Int? = 30
    var maximumAgeEnabled: Bool? = false
    var meInUsernameColor: Bool? = true
    var enabled: Bool? = true
    var usernamesToIgnore: [SettingsChatUsername]? = []
    var textToSpeechEnabled: Bool? = false
    var textToSpeechDetectLanguagePerMessage: Bool? = false
    var textToSpeechSayUsername: Bool? = true
    var textToSpeechRate: Float? = 0.4
    var textToSpeechSayVolume: Float? = 0.6
    var textToSpeechLanguageVoices: [String: String]? = .init()
    var textToSpeechSubscribersOnly: Bool? = false
    var textToSpeechFilter: Bool? = true
    var textToSpeechFilterMentions: Bool? = true
    var mirrored: Bool? = false
    var botEnabled: Bool? = false
    var botCommandPermissions: SettingsChatBotPermissions? = .init()
    var botSendLowBatteryWarning: Bool? = false
    var badges: Bool? = true
    var showFirstTimeChatterMessage: Bool? = true
    var showNewFollowerMessage: Bool? = true
    var bottom: Double? = 0.0
    var newMessagesAtTop: Bool? = false
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

class SettingsDebugBeautyFilter: Codable {
    var showBlur = false
    var showBlurBackground: Bool? = false
    var showMoblin = false
    var showCute: Bool? = false
    var cuteRadius: Float? = 0.5
    var cuteScale: Float? = 0.0
    var cuteOffset: Float? = 0.5
    var showBeauty: Bool? = false
    var shapeRadius: Float? = 0.5
    var shapeScale: Float? = 0.0
    var shapeOffset: Float? = 0.5
    var smoothAmount: Float? = 0.65
    var smoothRadius: Float? = 20.0
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

class SettingsDebug: Codable {
    var logLevel: SettingsLogLevel = .error
    var srtOverlay: Bool = false
    var srtOverheadBandwidth: Int32? = 25
    var cameraSwitchRemoveBlackish: Float? = 0.3
    var maximumBandwidthFollowInput: Bool? = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap? = .init()
    var bluetoothOutputOnly: Bool? = true
    var maximumLogLines: Int? = 500
    var pixelFormat: String? = pixelFormats[1]
    var beautyFilter: Bool? = false
    var beautyFilterSettings: SettingsDebugBeautyFilter? = .init()
    var allowVideoRangePixelFormat: Bool? = false
    var blurSceneSwitch: Bool? = true
    var metalPetalFilters: Bool? = false
    var preferStereoMic: Bool? = false
    var twitchRewards: Bool? = false
    var removeWindNoise: Bool? = false
    var httpProxy: SettingsHttpProxy? = .init()
    var tesla: SettingsTesla? = .init()
    var reliableChat: Bool? = false
    var timecodesEnabled: Bool? = false
    var dnsLookupStrategy: SettingsDnsLookupStrategy? = .system
    var srtlaBatchSend: Bool? = false
    var cameraControlsEnabled: Bool? = true
    var dataRateLimitFactor: Float? = 2.0
    var bitrateDropFix: Bool? = false
    var relaxedBitrate: Bool? = false
    var externalDisplayChat: Bool? = false
    var videoSourceWidgetTrackFace: Bool? = false
    var srtlaBatchSendEnabled: Bool? = true
    var replay: Bool? = false
    var recordSegmentLength: Double? = 5.0
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

class SettingsMediaPlayer: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My player"
    var playerId: String = ""
    var autoSelectMic: Bool = true
    var playlist: [SettingsMediaPlayerFile] = []

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

class SettingsMediaPlayers: Codable {
    var players: [SettingsMediaPlayer] = []
}

enum SettingsDjiDeviceUrlType: String, Codable, CaseIterable {
    case server = "Server"
    case custom = "Custom"

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceUrlType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .server
    }

    static func fromString(value: String) -> SettingsDjiDeviceUrlType {
        switch value {
        case String(localized: "Server"):
            return .server
        case String(localized: "Custom"):
            return .custom
        default:
            return .server
        }
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

var djiDeviceUrlTypes = SettingsDjiDeviceUrlType.allCases.map { $0.toString() }

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

    static func fromString(value: String) -> SettingsDjiDeviceImageStabilization {
        switch value {
        case String(localized: "Off"):
            return .off
        case String(localized: "RockSteady"):
            return .rockSteady
        case String(localized: "RockSteady+"):
            return .rockSteadyPlus
        case String(localized: "HorizonBalancing"):
            return .horizonBalancing
        case String(localized: "HorizonSteady"):
            return .horizonSteady
        default:
            return .rockSteady
        }
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

var djiDeviceImageStabilizations = SettingsDjiDeviceImageStabilization.allCases.map { $0.toString() }

enum SettingsDjiDeviceResolution: String, CaseIterable, Codable {
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"

    public init(from decoder: Decoder) throws {
        self = try SettingsDjiDeviceResolution(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .r1080p
    }
}

var djiDeviceResolutions = SettingsDjiDeviceResolution.allCases.map { $0.rawValue }

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

class SettingsDjiDevice: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
    var wifiSsid: String = ""
    var wifiPassword: String = ""
    var rtmpUrlType: SettingsDjiDeviceUrlType? = .server
    var serverRtmpStreamId: UUID? = .init()
    var serverRtmpUrl: String? = ""
    var customRtmpUrl: String? = ""
    var autoRestartStream: Bool? = false
    var imageStabilization: SettingsDjiDeviceImageStabilization? = .off
    var resolution: SettingsDjiDeviceResolution? = .r1080p
    var fps: Int? = 30
    var bitrate: UInt32? = 6_000_000
    var isStarted: Bool? = false
    var model: SettingsDjiDeviceModel? = .unknown
}

class SettingsDjiDevices: Codable {
    var devices: [SettingsDjiDevice] = []
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

class SettingsGoProWifiCredentials: Codable, Identifiable {
    var id: UUID = .init()
    var name = "My SSID"
    var ssid = ""
    var password = ""
}

class SettingsGoProRtmpUrl: Codable, Identifiable {
    var id: UUID = .init()
    var name = "My URL"
    var type: SettingsDjiDeviceUrlType = .server
    var serverStreamId: UUID = .init()
    var serverUrl = ""
    var customUrl = ""
}

class SettingsGoProLaunchLiveStream: Codable, Identifiable {
    var id: UUID = .init()
    var name = "1080p"
    var isHero12Or13: Bool? = true
}

class SettingsGoPro: Codable {
    var launchLiveStream: [SettingsGoProLaunchLiveStream] = []
    var selectedLaunchLiveStream: UUID?
    var wifiCredentials: [SettingsGoProWifiCredentials] = []
    var selectedWifiCredentials: UUID?
    var rtmpUrls: [SettingsGoProRtmpUrl] = []
    var selectedRtmpUrl: UUID?
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

class SettingsCatPrinter: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var enabled: Bool = false
    var bluetoothPeripheralName: String?
    var bluetoothPeripheralId: UUID?
    var printChat: Bool? = true
    var faxMeowSound: Bool? = true
    var printSnapshots: Bool? = true
}

class SettingsCatPrinters: Codable {
    var devices: [SettingsCatPrinter] = []
    var backgroundPrinting: Bool? = false
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

class SettingsQuickButtons: Codable {
    var twoColumns: Bool = true
    var showName: Bool = true
    var enableScroll: Bool = true
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

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Interactive chat"
        }
        self = SettingsGameControllerButtonFunction(rawValue: value) ?? .unused
    }

    static func fromString(value: String) -> SettingsGameControllerButtonFunction {
        switch value {
        case String(localized: "Unused"):
            return .unused
        case String(localized: "Record"):
            return .record
        case String(localized: "Stream"):
            return .stream
        case String(localized: "Zoom in"):
            return .zoomIn
        case String(localized: "Zoom out"):
            return .zoomOut
        case String(localized: "Mute"):
            return .mute
        case String(localized: "Torch"):
            return .torch
        case String(localized: "Black screen"):
            return .blackScreen
        case String(localized: "Chat"):
            return .chat
        case String(localized: "Scene"):
            return .scene
        default:
            return .unused
        }
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
            return String(localized: "Black screen")
        case .chat:
            return String(localized: "Chat")
        case .scene:
            return String(localized: "Scene")
        }
    }
}

var gameControllerButtonFunctions = SettingsGameControllerButtonFunction.allCases.map { $0.toString() }

class SettingsGameControllerButton: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""
    var text: String? = ""
    var function: SettingsGameControllerButtonFunction = .unused
    var sceneId: UUID = .init()
}

class SettingsGameController: Codable, Identifiable {
    var id: UUID = .init()
    var buttons: [SettingsGameControllerButton] = []

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

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Interactive chat"
        }
        self = SettingsKeyboardKeyFunction(rawValue: value) ?? .unused
    }

    static func fromString(value: String) -> SettingsKeyboardKeyFunction {
        switch value {
        case String(localized: "Unused"):
            return .unused
        case String(localized: "Record"):
            return .record
        case String(localized: "Stream"):
            return .stream
        case String(localized: "Mute"):
            return .mute
        case String(localized: "Torch"):
            return .torch
        case String(localized: "Black screen"):
            return .blackScreen
        case String(localized: "Scene"):
            return .scene
        case String(localized: "Widget"):
            return .widget
        default:
            return .unused
        }
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
            return String(localized: "Black screen")
        case .scene:
            return String(localized: "Scene")
        case .widget:
            return String(localized: "Widget")
        }
    }
}

var keyboardKeyFunctions = SettingsKeyboardKeyFunction.allCases.map { $0.toString() }

class SettingsKeyboardKey: Codable, Identifiable {
    var id: UUID = .init()
    var key: String = ""
    var function: SettingsKeyboardKeyFunction = .unused
    var sceneId: UUID = .init()
    var widgetId: UUID? = .init()
}

class SettingsKeyboard: Codable {
    var keys: [SettingsKeyboardKey] = []
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

class SettingsMoblinkRelay: Codable {
    var enabled: Bool = false
    var name: String = randomName()
    var url: String = ""
    var manual: Bool? = false
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

    static func fromString(value: String) -> SettingsSceneSwitchTransition {
        switch value {
        case String(localized: "Blur"):
            return .blur
        case String(localized: "Freeze"):
            return .freeze
        case String(localized: "Blur & zoom"):
            return .blurAndZoom
        default:
            return .blur
        }
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

let sceneSwitchTransitions = SettingsSceneSwitchTransition.allCases.map { $0.toString() }

enum SettingsExternalDisplayContent: String, Codable, CaseIterable {
    case stream = "Stream"
    case cleanStream = "Clean stream"
    case chat = "Chat"
    case mirror = "Mirror"

    public init(from decoder: Decoder) throws {
        self = try SettingsExternalDisplayContent(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .stream
    }

    static func fromString(value: String) -> SettingsExternalDisplayContent {
        switch value {
        case String(localized: "Stream"):
            return .stream
        case String(localized: "Clean stream"):
            return .cleanStream
        case String(localized: "Chat"):
            return .chat
        case String(localized: "Mirror"):
            return .mirror
        default:
            return .stream
        }
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

let externalDisplayContents = SettingsExternalDisplayContent.allCases.map { $0.toString() }

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

class DeepLinkCreatorStreamVideo: Codable {
    var resolution: SettingsStreamResolution? = .r1920x1080
    var fps: Int? = 30
    var bitrate: UInt32? = 5_000_000
    var codec: SettingsStreamCodec = .h265hevc
    var bFrames: Bool? = false
    var maxKeyFrameInterval: Int32? = 2
}

class DeepLinkCreatorStreamAudio: Codable {
    var bitrate: Int = 128_000
}

class DeepLinkCreatorStreamSrt: Codable {
    var latency: Int32 = defaultSrtLatency
    var adaptiveBitrateEnabled: Bool = true
    var dnsLookupStrategy: SettingsDnsLookupStrategy? = .system
}

class DeepLinkCreatorStreamObs: Codable {
    var webSocketUrl: String = ""
    var webSocketPassword: String = ""
}

class DeepLinkCreatorStreamTwitch: Codable {
    var channelName: String = ""
    var channelId: String = ""
}

class DeepLinkCreatorStreamKick: Codable {
    var channelName: String = ""
}

class DeepLinkCreatorStream: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My stream"
    var url: String = defaultStreamUrl
    var selected: Bool = false
    var video: DeepLinkCreatorStreamVideo = .init()
    var audio: DeepLinkCreatorStreamAudio? = .init()
    var srt: DeepLinkCreatorStreamSrt = .init()
    var obs: DeepLinkCreatorStreamObs = .init()
    var twitch: DeepLinkCreatorStreamTwitch? = .init()
    var kick: DeepLinkCreatorStreamKick? = .init()
}

class DeepLinkCreatorQuickButton: Codable, Identifiable {
    var id: UUID = .init()
    var type: SettingsButtonType = .unknown
    var enabled: Bool = false
}

class DeepLinkCreatorQuickButtons: Codable {
    var twoColumns: Bool = true
    var showName: Bool = true
    var enableScroll: Bool = true
    var buttons: [DeepLinkCreatorQuickButton] = []
}

class DeepLinkCreatorWebBrowser: Codable {
    var home: String = ""
}

class DeepLinkCreator: Codable {
    var streams: [DeepLinkCreatorStream] = []
    var quickButtonsEnabled: Bool? = false
    var quickButtons: DeepLinkCreatorQuickButtons? = .init()
    var webBrowserEnabled: Bool? = false
    var webBrowser: DeepLinkCreatorWebBrowser? = .init()
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

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    var tapToFocus: Bool = false
    var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var batteryPercentage: Bool = true
    var mic: SettingsMic = getDefaultMic()
    var debug: SettingsDebug = .init()
    var quickButtons: SettingsQuickButtons? = .init()
    var globalButtons: [SettingsButton]? = []
    var rtmpServer: SettingsRtmpServer? = .init()
    var networkInterfaceNames: [SettingsNetworkInterfaceName]? = []
    var lowBitrateWarning: Bool? = true
    var vibrate: Bool? = false
    var gameControllers: [SettingsGameController]? = [.init()]
    var remoteControl: SettingsRemoteControl? = .init()
    var startStopRecordingConfirmations: Bool? = true
    var color: SettingsColor? = .init()
    var mirrorFrontCameraOnStream: Bool? = true
    var streamButtonColor: RgbColor? = defaultStreamButtonColor
    var location: SettingsLocation? = .init()
    var watch: WatchSettings? = .init()
    var audio: AudioSettings? = .init()
    var webBrowser: WebBrowserSettings? = .init()
    var deepLinkCreator: DeepLinkCreator? = .init()
    var srtlaServer: SettingsSrtlaServer? = .init()
    var mediaPlayers: SettingsMediaPlayers? = .init()
    var showAllSettings: Bool? = false
    var portrait: Bool? = false
    var djiDevices: SettingsDjiDevices? = .init()
    var alertsMediaGallery: SettingsAlertsMediaGallery? = .init()
    var catPrinters: SettingsCatPrinters? = .init()
    var verboseStatuses: Bool? = false
    var scoreboardPlayers: [SettingsWidgetScoreboardPlayer]? = .init()
    var keyboard: SettingsKeyboard? = .init()
    var tesla: SettingsTesla? = .init()
    var srtlaRelay: SettingsMoblink? = .init()
    var pixellateStrength: Float? = 0.3
    var moblink: SettingsMoblink? = .init()
    var sceneSwitchTransition: SettingsSceneSwitchTransition? = .blur
    var forceSceneSwitchTransition: Bool? = false
    var cameraControlsEnabled: Bool? = true
    var externalDisplayContent: SettingsExternalDisplayContent? = .stream
    var cyclingPowerDevices: SettingsCyclingPowerDevices? = .init()
    var heartRateDevices: SettingsHeartRateDevices? = .init()
    var djiGimbalDevices: SettingsDjiGimbalDevices? = .init()
    var remoteSceneId: UUID?
    var sceneNumericInput: Bool? = false
    var goPro: SettingsGoPro? = .init()
    var replay: SettingsReplay? = .init()
    var portraitVideoOffsetFromTop: Double? = 0.0

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
        for button in database.globalButtons! where button.type != .interactiveChat && button.type != .cameraPreview {
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
        SettingsBitratePreset(id: UUID(), bitrate: 11_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 9_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 7_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
    ]
}

private func updateQuickButton(database: Database, button: SettingsButton) {
    let existingButton = database.globalButtons!.first(where: { globalButton in
        globalButton.type == button.type
    })
    if let existingButton {
        existingButton.name = button.name
        existingButton.systemImageNameOn = button.systemImageNameOn
        existingButton.systemImageNameOff = button.systemImageNameOff
    } else {
        database.globalButtons!.append(button)
    }
}

private func addMissingQuickButtons(database: Database) {
    if database.globalButtons == nil {
        database.globalButtons = []
    }
    var button = SettingsButton(name: String(localized: "Torch"))
    button.id = UUID()
    button.type = .torch
    button.imageType = "System name"
    button.systemImageNameOn = "flashlight.on.fill"
    button.systemImageNameOff = "flashlight.off.fill"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Mute"))
    button.id = UUID()
    button.type = .mute
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Bitrate"))
    button.id = UUID()
    button.type = .bitrate
    button.imageType = "System name"
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Mic"))
    button.id = UUID()
    button.type = .mic
    button.imageType = "System name"
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Chat"))
    button.id = UUID()
    button.type = .chat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Interactive chat"))
    button.id = UUID()
    button.type = .interactiveChat
    button.imageType = "System name"
    button.systemImageNameOn = "arrow.up.message.fill"
    button.systemImageNameOff = "arrow.up.message"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Black screen"))
    button.id = UUID()
    button.type = .blackScreen
    button.imageType = "System name"
    button.systemImageNameOn = "sunset.fill"
    button.systemImageNameOff = "sunset"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Lock screen"))
    button.id = UUID()
    button.type = .lockScreen
    button.imageType = "System name"
    button.systemImageNameOn = "lock.fill"
    button.systemImageNameOff = "lock"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Record"))
    button.id = UUID()
    button.type = .record
    button.imageType = "System name"
    button.systemImageNameOn = "record.circle.fill"
    button.systemImageNameOff = "record.circle"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Stream"))
    button.id = UUID()
    button.type = .stream
    button.imageType = "System name"
    button.systemImageNameOn = "dot.radiowaves.left.and.right"
    button.systemImageNameOff = "dot.radiowaves.left.and.right"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Recordings"))
    button.id = UUID()
    button.type = .recordings
    button.imageType = "System name"
    button.systemImageNameOn = "photo.on.rectangle.angled.fill"
    button.systemImageNameOff = "photo.on.rectangle.angled"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Snapshot"))
    button.id = UUID()
    button.type = .snapshot
    button.imageType = "System name"
    button.systemImageNameOn = "camera.aperture"
    button.systemImageNameOff = "camera.aperture"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Replay"))
    button.id = UUID()
    button.type = .replay
    button.imageType = "System name"
    button.systemImageNameOn = "play.fill"
    button.systemImageNameOff = "play"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Instant replay"))
    button.id = UUID()
    button.type = .instantReplay
    button.imageType = "System name"
    button.systemImageNameOn = "memories"
    button.systemImageNameOff = "memories"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "OBS"))
    button.id = UUID()
    button.type = .obs
    button.imageType = "System name"
    button.systemImageNameOn = "xserve"
    button.systemImageNameOff = "xserve"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Remote"))
    button.id = UUID()
    button.type = .remote
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Widgets"))
    button.id = UUID()
    button.type = .widgets
    button.imageType = "System name"
    button.systemImageNameOn = "photo.on.rectangle.fill"
    button.systemImageNameOff = "photo.on.rectangle"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Draw"))
    button.id = UUID()
    button.type = .draw
    button.imageType = "System name"
    button.systemImageNameOn = "pencil.line"
    button.systemImageNameOff = "pencil.line"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Camera"))
    button.id = UUID()
    button.type = .image
    button.imageType = "System name"
    button.systemImageNameOn = "camera.fill"
    button.systemImageNameOff = "camera"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Browser"))
    button.id = UUID()
    button.type = .browser
    button.imageType = "System name"
    button.systemImageNameOn = "globe"
    button.systemImageNameOff = "globe"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Grid"))
    button.id = UUID()
    button.type = .grid
    button.imageType = "System name"
    button.systemImageNameOn = "grid"
    button.systemImageNameOff = "grid"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Face"))
    button.id = UUID()
    button.type = .face
    button.imageType = "System name"
    button.systemImageNameOn = "theatermask.and.paintbrush.fill"
    button.systemImageNameOff = "theatermask.and.paintbrush"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Movie"))
    button.id = UUID()
    button.type = .movie
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "4:3"))
    button.id = UUID()
    button.type = .fourThree
    button.imageType = "System name"
    button.systemImageNameOn = "square.fill"
    button.systemImageNameOff = "square"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Gray scale"))
    button.id = UUID()
    button.type = .grayScale
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Sepia"))
    button.id = UUID()
    button.type = .sepia
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent.inverse"
    button.systemImageNameOff = "moonphase.waning.crescent"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Triple"))
    button.id = UUID()
    button.type = .triple
    button.imageType = "System name"
    button.systemImageNameOn = "person.3.fill"
    button.systemImageNameOff = "person.3"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Twin"))
    button.id = UUID()
    button.type = .twin
    button.imageType = "System name"
    button.systemImageNameOn = "person.2.fill"
    button.systemImageNameOff = "person.2"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Pixellate"))
    button.id = UUID()
    button.type = .pixellate
    button.imageType = "System name"
    button.systemImageNameOn = "squareshape.split.2x2"
    button.systemImageNameOff = "squareshape.split.2x2"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Local overlays"))
    button.id = UUID()
    button.type = .localOverlays
    button.imageType = "System name"
    button.systemImageNameOn = "square.stack.3d.up.slash.fill"
    button.systemImageNameOff = "square.stack.3d.up.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Poll"))
    button.id = UUID()
    button.type = .poll
    button.imageType = "System name"
    button.systemImageNameOn = "chart.bar.xaxis"
    button.systemImageNameOff = "chart.bar.xaxis"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "LUTs"))
    button.id = UUID()
    button.type = .luts
    button.imageType = "System name"
    button.systemImageNameOn = "camera.filters"
    button.systemImageNameOff = "camera.filters"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Workout"))
    button.id = UUID()
    button.type = .workout
    button.imageType = "System name"
    button.systemImageNameOn = "figure.run"
    button.systemImageNameOff = "figure.run"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Skip current TTS"))
    button.id = UUID()
    button.type = .skipCurrentTts
    button.imageType = "System name"
    button.systemImageNameOn = "waveform.slash"
    button.systemImageNameOff = "waveform.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Ads"))
    button.id = UUID()
    button.type = .ads
    button.imageType = "System name"
    button.systemImageNameOn = "cup.and.saucer.fill"
    button.systemImageNameOff = "cup.and.saucer"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Stream marker"))
    button.id = UUID()
    button.type = .streamMarker
    button.imageType = "System name"
    button.systemImageNameOn = "bookmark.fill"
    button.systemImageNameOff = "bookmark"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Reload browser widgets"))
    button.id = UUID()
    button.type = .reloadBrowserWidgets
    button.imageType = "System name"
    button.systemImageNameOn = "arrow.clockwise"
    button.systemImageNameOff = "arrow.clockwise"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "DJI devices"))
    button.id = UUID()
    button.type = .djiDevices
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "GoPro"))
    button.id = UUID()
    button.type = .goPro
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Camera preview"))
    button.id = UUID()
    button.type = .cameraPreview
    button.imageType = "System name"
    button.systemImageNameOn = "camera.rotate.fill"
    button.systemImageNameOff = "camera.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Portrait"))
    button.id = UUID()
    button.type = .portrait
    button.imageType = "System name"
    button.systemImageNameOn = "rectangle.portrait.rotate"
    button.systemImageNameOff = "rectangle.portrait.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Connection priorities"))
    button.id = UUID()
    button.type = .connectionPriorities
    button.imageType = "System name"
    button.systemImageNameOn = "phone.connection.fill"
    button.systemImageNameOff = "phone.connection"
    updateQuickButton(database: database, button: button)

    database.globalButtons = database.globalButtons!.filter { button in
        if button.type == .unknown {
            return false
        }
        if button.type == .workout, !isPhone() {
            return false
        }
        if button.type == .portrait, ProcessInfo().isiOSAppOnMac {
            return false
        }
        return true
    }
}

private func addMissingDeepLinkQuickButtons(database: Database) {
    if database.deepLinkCreator == nil {
        database.deepLinkCreator = .init()
    }
    if database.deepLinkCreator!.quickButtons == nil {
        database.deepLinkCreator!.quickButtons = .init()
    }
    let quickButtons = database.deepLinkCreator!.quickButtons!
    for quickButton in database.globalButtons! where quickButton.type != .lut {
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
    if database.color == nil {
        database.color = .init()
    }
    var bundledLuts: [SettingsColorLut] = []
    for lut in allBundledLuts {
        if let existingLut = database.color!.bundledLuts.first(where: { $0.name == lut.name }) {
            bundledLuts.append(existingLut)
        } else {
            bundledLuts.append(lut)
        }
    }
    database.color!.bundledLuts = bundledLuts
}

private func addMissingGoPro(database: Database) {
    if database.goPro == nil {
        database.goPro = .init()
    }
    let goPro = database.goPro!
    if goPro.launchLiveStream.isEmpty {
        goPro.launchLiveStream = [.init()]
        goPro.selectedLaunchLiveStream = goPro.launchLiveStream.first?.id
    }
}

private func updateBundledAlertsMediaGallery(database: Database) {
    var bundledImages: [SettingsAlertsMediaGalleryItem] = []
    for image in allBundledAlertsMediaGalleryImages {
        if let existingImage = database.alertsMediaGallery!.bundledImages
            .first(where: { $0.name == image.name })
        {
            bundledImages.append(existingImage)
        } else {
            bundledImages.append(image)
        }
    }
    database.alertsMediaGallery!.bundledImages = bundledImages
    var bundledSounds: [SettingsAlertsMediaGalleryItem] = []
    for sound in allBundledAlertsMediaGallerySounds {
        if let existingSound = database.alertsMediaGallery!.bundledSounds
            .first(where: { $0.name == sound.name })
        {
            bundledSounds.append(existingSound)
        } else {
            bundledSounds.append(sound)
        }
    }
    database.alertsMediaGallery!.bundledSounds = bundledSounds
}

private func addScenesToGameController(database: Database) {
    var button = database.gameControllers![0].buttons[0]
    button.function = .scene
    button.sceneId = database.scenes[0].id
    button = database.gameControllers![0].buttons[1]
    button.function = .scene
    button.sceneId = database.scenes[1].id
}

private func getDefaultMic() -> SettingsMic {
    if ProcessInfo().isiOSAppOnMac {
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
        if realDatabase.chat.height == nil {
            realDatabase.chat.height = 0.7
            store()
        }
        if realDatabase.chat.width == nil {
            realDatabase.chat.width = 1.0
            store()
        }
        for stream in realDatabase.streams where stream.youTubeVideoId == nil {
            stream.youTubeVideoId = ""
            store()
        }
        if realDatabase.chat.maximumAge == nil {
            realDatabase.chat.maximumAge = 30
            store()
        }
        if realDatabase.chat.maximumAgeEnabled == nil {
            realDatabase.chat.maximumAgeEnabled = false
            store()
        }
        if realDatabase.debug.srtOverheadBandwidth == nil {
            realDatabase.debug.srtOverheadBandwidth = 25
            store()
        }
        for stream in realDatabase.streams where stream.maxKeyFrameInterval == nil {
            stream.maxKeyFrameInterval = 2
            store()
        }
        for scene in realDatabase.scenes where scene.cameraPosition == nil {
            scene.cameraPosition = scene.cameraType
            store()
        }
        if realDatabase.zoom.speed == nil {
            realDatabase.zoom.speed = 5.0
            store()
        }
        if realDatabase.show.cameras == nil {
            realDatabase.show.cameras = false
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
        for stream in realDatabase.streams where stream.afreecaTvChannelName == nil {
            stream.afreecaTvChannelName = ""
            store()
        }
        for stream in realDatabase.streams where stream.afreecaTvStreamId == nil {
            stream.afreecaTvStreamId = ""
            store()
        }
        for stream in realDatabase.streams where stream.obsWebSocketUrl == nil {
            stream.obsWebSocketUrl = ""
            store()
        }
        for stream in realDatabase.streams where stream.obsWebSocketPassword == nil {
            stream.obsWebSocketPassword = ""
            store()
        }
        if realDatabase.show.obsStatus == nil {
            realDatabase.show.obsStatus = true
            store()
        }
        for stream in realDatabase.streams where stream.obsWebSocketEnabled == nil {
            stream.obsWebSocketEnabled = true
            store()
        }
        if realDatabase.chat.meInUsernameColor == nil {
            realDatabase.chat.meInUsernameColor = true
            store()
        }
        for stream in realDatabase.streams where stream.audioBitrate == nil {
            stream.audioBitrate = 128_000
            store()
        }
        if realDatabase.quickButtons == nil {
            realDatabase.quickButtons = .init()
            store()
        }
        for stream in realDatabase.streams where stream.chat == nil {
            stream.chat = .init()
            store()
        }
        for stream in realDatabase.streams where stream.bFrames == nil {
            stream.bFrames = false
            store()
        }
        if realDatabase.rtmpServer == nil {
            realDatabase.rtmpServer = .init()
            store()
        }
        for scene in realDatabase.scenes where scene.rtmpCameraId == nil {
            scene.rtmpCameraId = .init()
            store()
        }
        if realDatabase.show.rtmpSpeed == nil {
            realDatabase.show.rtmpSpeed = true
            store()
        }
        if realDatabase.networkInterfaceNames == nil {
            realDatabase.networkInterfaceNames = []
            store()
        }
        if realDatabase.lowBitrateWarning == nil {
            realDatabase.lowBitrateWarning = true
            store()
        }
        for stream in realDatabase.rtmpServer!.streams where stream.latency == nil {
            stream.latency = defaultRtmpLatency
            store()
        }
        if realDatabase.vibrate == nil {
            realDatabase.vibrate = false
            store()
        }
        for stream in realDatabase.streams where stream.recording == nil {
            stream.recording = .init()
            store()
        }
        if realDatabase.show.gameController == nil {
            realDatabase.show.gameController = true
            store()
        }
        if realDatabase.gameControllers == nil {
            realDatabase.gameControllers = [.init()]
            store()
        }
        for controller in realDatabase.gameControllers! {
            for button in controller.buttons where button.text == nil {
                button.text = ""
                store()
            }
        }
        if realDatabase.debug.cameraSwitchRemoveBlackish == nil {
            realDatabase.debug.cameraSwitchRemoveBlackish = 0.3
            store()
        }
        for stream in database.streams where stream.realtimeIrlEnabled == nil {
            stream.realtimeIrlEnabled = false
            store()
        }
        for stream in database.streams where stream.realtimeIrlPushKey == nil {
            stream.realtimeIrlPushKey = ""
            store()
        }
        if realDatabase.show.location == nil {
            realDatabase.show.location = true
            store()
        }
        for button in realDatabase.globalButtons! where button.type == .image {
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
        for stream in realDatabase.streams where stream.obsSourceName == nil {
            stream.obsSourceName = ""
            store()
        }
        for stream in realDatabase.streams where stream.srt.connectionPriorities == nil {
            stream.srt.connectionPriorities = .init()
            store()
        }
        for button in realDatabase.globalButtons! where button.backgroundColor == nil {
            button.backgroundColor = defaultQuickButtonColor
            store()
        }
        if realDatabase.debug.maximumBandwidthFollowInput == nil {
            realDatabase.debug.maximumBandwidthFollowInput = true
            store()
        }
        if realDatabase.remoteControl == nil {
            realDatabase.remoteControl = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.type == .browser {
            if widget.browser.audioOnly == nil {
                widget.browser.audioOnly = false
                store()
            }
        }
        for stream in realDatabase.streams where stream.srt.overheadBandwidth == nil {
            stream.srt.overheadBandwidth = realDatabase.debug.srtOverheadBandwidth!
            store()
        }
        for stream in realDatabase.streams where stream.srt.maximumBandwidthFollowInput == nil {
            stream.srt.maximumBandwidthFollowInput = realDatabase.debug.maximumBandwidthFollowInput!
            store()
        }
        for stream in realDatabase.streams where stream.srt.adaptiveBitrate == nil {
            stream.srt.adaptiveBitrate = .init()
            store()
        }
        if realDatabase.startStopRecordingConfirmations == nil {
            realDatabase.startStopRecordingConfirmations = true
            store()
        }
        if realDatabase.remoteControl!.password == nil {
            realDatabase.remoteControl!.password = randomGoodPassword()
            store()
        }
        for widget in realDatabase.widgets where widget.browser.scaleToFitVideo == nil {
            widget.browser.scaleToFitVideo = false
            store()
        }
        for widget in realDatabase.widgets where widget.browser.fps == nil {
            widget.browser.fps = 5.0
            store()
        }
        for stream in realDatabase.streams {
            for priority in stream.srt.connectionPriorities!.priorities where priority.enabled == nil {
                priority.enabled = true
                store()
            }
        }
        if realDatabase.debug.audioOutputToInputChannelsMap == nil {
            realDatabase.debug.audioOutputToInputChannelsMap = .init()
            store()
        }
        if realDatabase.show.remoteControl == nil {
            realDatabase.show.remoteControl = true
            store()
        }
        if realDatabase.show.browserWidgets == nil {
            realDatabase.show.browserWidgets = true
            store()
        }
        if realDatabase.debug.bluetoothOutputOnly == nil {
            realDatabase.debug.bluetoothOutputOnly = true
            store()
        }
        if realDatabase.debug.maximumLogLines == nil {
            realDatabase.debug.maximumLogLines = 500
            store()
        }
        if realDatabase.color == nil {
            realDatabase.color = .init()
            store()
        }
        if realDatabase.color!.diskLuts == nil {
            realDatabase.color!.diskLuts = []
            store()
        }
        for scene in realDatabase.scenes where scene.externalCameraId == nil {
            scene.externalCameraId = ""
            store()
        }
        for scene in realDatabase.scenes where scene.externalCameraName == nil {
            scene.externalCameraName = ""
            store()
        }
        if realDatabase.streamButtonColor == nil {
            realDatabase.streamButtonColor = defaultStreamButtonColor
            store()
        }
        if realDatabase.location == nil {
            realDatabase.location = .init()
            store()
        }
        for stream in database.streams where stream.srt.adaptiveBitrate!.fastIrlSettings == nil {
            stream.srt.adaptiveBitrate!.fastIrlSettings = .init()
            store()
        }
        if realDatabase.chat.enabled == nil {
            realDatabase.chat.enabled = true
            store()
        }
        for stream in database.streams where stream.rtmp == nil {
            stream.rtmp = .init()
            store()
        }
        for stream in database.streams where stream.srt.adaptiveBitrateEnabled == nil {
            stream.srt.adaptiveBitrateEnabled = stream.adaptiveBitrate!
            store()
        }
        if realDatabase.watch == nil {
            realDatabase.watch = .init()
            store()
        }
        if realDatabase.watch!.chat.timestampEnabled == nil {
            realDatabase.watch!.chat.timestampEnabled = true
            store()
        }
        if realDatabase.watch!.chat.notificationOnMessage == nil {
            realDatabase.watch!.chat.notificationOnMessage = false
            store()
        }
        if realDatabase.chat.usernamesToIgnore == nil {
            realDatabase.chat.usernamesToIgnore = []
            store()
        }
        for scene in realDatabase.scenes where scene.backCameraId == nil {
            scene.backCameraId = getBestBackCameraId()
            store()
        }
        for scene in realDatabase.scenes where scene.frontCameraId == nil {
            scene.frontCameraId = getBestFrontCameraId()
            store()
        }
        for stream in realDatabase.streams where stream.openStreamingPlatformUrl == nil {
            stream.openStreamingPlatformUrl = ""
            store()
        }
        for stream in realDatabase.streams where stream.openStreamingPlatformChannelId == nil {
            stream.openStreamingPlatformChannelId = ""
            store()
        }
        for widget in realDatabase.widgets where widget.crop == nil {
            widget.crop = .init()
            store()
        }
        if realDatabase.chat.textToSpeechEnabled == nil {
            realDatabase.chat.textToSpeechEnabled = false
            store()
        }
        if realDatabase.chat.textToSpeechDetectLanguagePerMessage == nil {
            realDatabase.chat.textToSpeechDetectLanguagePerMessage = false
            store()
        }
        if realDatabase.chat.textToSpeechSayUsername == nil {
            realDatabase.chat.textToSpeechSayUsername = true
            store()
        }
        if realDatabase.chat.textToSpeechRate == nil {
            realDatabase.chat.textToSpeechRate = 0.4
            store()
        }
        if realDatabase.chat.textToSpeechSayVolume == nil {
            realDatabase.chat.textToSpeechSayVolume = 0.6
            store()
        }
        if realDatabase.chat.textToSpeechLanguageVoices == nil {
            realDatabase.chat.textToSpeechLanguageVoices = .init()
            store()
        }
        for stream in realDatabase.streams where stream.kickChannelName == nil {
            stream.kickChannelName = ""
            store()
        }
        if realDatabase.chat.textToSpeechSubscribersOnly == nil {
            realDatabase.chat.textToSpeechSubscribersOnly = false
            store()
        }
        for stream in database.streams where stream.portrait == nil {
            stream.portrait = false
            store()
        }
        if realDatabase.audio == nil {
            realDatabase.audio = .init()
            realDatabase.audio!.audioOutputToInputChannelsMap!.channel1 = realDatabase.debug
                .audioOutputToInputChannelsMap!.channel0
            realDatabase.audio!.audioOutputToInputChannelsMap!.channel2 = realDatabase.debug
                .audioOutputToInputChannelsMap!.channel1
            store()
        }
        if realDatabase.webBrowser == nil {
            realDatabase.webBrowser = .init()
            store()
        }
        if realDatabase.chat.textToSpeechFilter == nil {
            realDatabase.chat.textToSpeechFilter = true
            store()
        }
        if realDatabase.watch!.show == nil {
            realDatabase.watch!.show = .init()
            store()
        }
        if realDatabase.debug.pixelFormat == nil {
            realDatabase.debug.pixelFormat = pixelFormats[1]
            store()
        }
        if realDatabase.chat.mirrored == nil {
            realDatabase.chat.mirrored = false
            store()
        }
        if realDatabase.debug.beautyFilter == nil {
            realDatabase.debug.beautyFilter = false
            store()
        }
        if realDatabase.debug.beautyFilterSettings == nil {
            realDatabase.debug.beautyFilterSettings = .init()
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.showBeauty == nil {
            realDatabase.debug.beautyFilterSettings!.showBeauty = realDatabase.debug.beautyFilterSettings!
                .showCute ?? false
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.shapeRadius == nil {
            realDatabase.debug.beautyFilterSettings!.shapeRadius = realDatabase.debug.beautyFilterSettings!
                .cuteRadius ?? 0.5
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.shapeScale == nil {
            realDatabase.debug.beautyFilterSettings!.shapeScale = realDatabase.debug.beautyFilterSettings!
                .cuteScale ?? 0.0
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.shapeOffset == nil {
            realDatabase.debug.beautyFilterSettings!.shapeOffset = realDatabase.debug.beautyFilterSettings!
                .cuteOffset ?? 0.5
            store()
        }
        for stream in realDatabase.streams where stream.recording!.autoStartRecording == nil {
            stream.recording!.autoStartRecording = false
            store()
        }
        for stream in realDatabase.streams where stream.recording!.autoStopRecording == nil {
            stream.recording!.autoStopRecording = false
            store()
        }
        if realDatabase.debug.allowVideoRangePixelFormat == nil {
            realDatabase.debug.allowVideoRangePixelFormat = false
            store()
        }
        for stream in realDatabase.streams where stream.rist == nil {
            stream.rist = .init()
            store()
        }
        for stream in realDatabase.streams where stream.recording!.audioBitrate == nil {
            stream.recording!.audioBitrate = 128_000
            store()
        }
        if realDatabase.show.bonding == nil {
            realDatabase.show.bonding = true
            store()
        }
        if realDatabase.debug.blurSceneSwitch == nil {
            realDatabase.debug.blurSceneSwitch = true
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.smoothAmount == nil {
            realDatabase.debug.beautyFilterSettings!.smoothAmount = 0.65
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.smoothRadius == nil {
            realDatabase.debug.beautyFilterSettings!.smoothRadius = 20.0
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
        if realDatabase.mirrorFrontCameraOnStream == nil {
            realDatabase.mirrorFrontCameraOnStream = true
            store()
        }
        if realDatabase.debug.metalPetalFilters == nil {
            realDatabase.debug.metalPetalFilters = false
            store()
        }
        for stream in realDatabase.streams
            where stream.srt.adaptiveBitrate!.customSettings.minimumBitrate == nil
        {
            stream.srt.adaptiveBitrate!.customSettings.minimumBitrate = 250
            store()
        }
        if realDatabase.deepLinkCreator == nil {
            realDatabase.deepLinkCreator = .init()
            store()
        }
        if realDatabase.deepLinkCreator!.webBrowser == nil {
            realDatabase.deepLinkCreator!.webBrowser = .init()
            store()
        }
        if realDatabase.deepLinkCreator!.quickButtons == nil {
            realDatabase.deepLinkCreator!.quickButtons = .init()
            store()
        }
        if realDatabase.deepLinkCreator!.quickButtonsEnabled == nil {
            realDatabase.deepLinkCreator!.quickButtonsEnabled = false
            store()
        }
        if realDatabase.deepLinkCreator!.webBrowserEnabled == nil {
            realDatabase.deepLinkCreator!.webBrowserEnabled = false
            store()
        }
        if realDatabase.srtlaServer == nil {
            realDatabase.srtlaServer = .init()
            store()
        }
        for stream in realDatabase.streams
            where stream.srt.adaptiveBitrate!.fastIrlSettings!.minimumBitrate == nil
        {
            stream.srt.adaptiveBitrate!.fastIrlSettings!.minimumBitrate = 250
            store()
        }
        for stream in realDatabase.streams where stream.backgroundStreaming == nil {
            stream.backgroundStreaming = false
            store()
        }
        for scene in realDatabase.scenes where scene.srtlaCameraId == nil {
            scene.srtlaCameraId = .init()
            store()
        }
        for stream in realDatabase.rtmpServer!.streams where stream.autoSelectMic == nil {
            stream.autoSelectMic = true
            store()
        }
        for stream in realDatabase.srtlaServer!.streams where stream.autoSelectMic == nil {
            stream.autoSelectMic = true
            store()
        }
        if realDatabase.debug.preferStereoMic == nil {
            realDatabase.debug.preferStereoMic = false
            store()
        }
        if realDatabase.remoteControl!.server.previewFps == nil {
            realDatabase.remoteControl!.server.previewFps = 1.0
            store()
        }
        for stream in realDatabase.streams where stream.srt.adaptiveBitrate!.belaboxSettings == nil {
            stream.srt.adaptiveBitrate!.belaboxSettings = .init()
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.video.bFrames == nil {
            stream.video.bFrames = false
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.twitch == nil {
            stream.twitch = .init()
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.kick == nil {
            stream.kick = .init()
            store()
        }
        if realDatabase.chat.botEnabled == nil {
            realDatabase.chat.botEnabled = false
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.video.resolution == nil {
            stream.video.resolution = .r1920x1080
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.video.fps == nil {
            stream.video.fps = 30
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.video.bitrate == nil {
            stream.video.bitrate = 5_000_000
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.video.maxKeyFrameInterval == nil {
            stream.video.maxKeyFrameInterval = 2
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.audio == nil {
            stream.audio = .init()
            store()
        }
        if realDatabase.mediaPlayers == nil {
            realDatabase.mediaPlayers = .init()
            store()
        }
        if realDatabase.showAllSettings == nil {
            realDatabase.showAllSettings = true
            store()
        }
        for stream in realDatabase.streams where stream.obsBrbScene == nil {
            stream.obsBrbScene = ""
            store()
        }
        for widget in realDatabase.widgets where widget.map == nil {
            widget.map = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.map!.northUp == nil {
            widget.map!.northUp = false
            store()
        }
        if realDatabase.portrait == nil {
            realDatabase.portrait = false
            store()
        }
        for widget in realDatabase.widgets where widget.scene == nil {
            widget.scene = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.qrCode == nil {
            widget.qrCode = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.text.backgroundColor == nil {
            widget.text.backgroundColor = .init(red: 0, green: 0, blue: 0, opacity: 0.75)
            store()
        }
        for widget in realDatabase.widgets where widget.text.clearBackgroundColor == nil {
            widget.text.clearBackgroundColor = false
            store()
        }
        for widget in realDatabase.widgets where widget.text.foregroundColor == nil {
            widget.text.foregroundColor = .init(red: 255, green: 255, blue: 255)
            store()
        }
        for widget in realDatabase.widgets where widget.text.clearForegroundColor == nil {
            widget.text.clearForegroundColor = false
            store()
        }
        for widget in realDatabase.widgets where widget.text.fontSize == nil {
            widget.text.fontSize = 30
            store()
        }
        for widget in realDatabase.widgets where widget.text.fontDesign == nil {
            widget.text.fontDesign = .default
            store()
        }
        for widget in realDatabase.widgets where widget.text.fontWeight == nil {
            widget.text.fontWeight = .regular
            store()
        }
        for stream in realDatabase.streams where stream.obsAutoStartStream == nil {
            stream.obsAutoStartStream = false
            store()
        }
        for stream in realDatabase.streams where stream.obsAutoStopStream == nil {
            stream.obsAutoStopStream = false
            store()
        }
        for stream in realDatabase.streams where stream.obsAutoStartRecording == nil {
            stream.obsAutoStartRecording = false
            store()
        }
        for stream in realDatabase.streams where stream.obsAutoStopRecording == nil {
            stream.obsAutoStopRecording = false
            store()
        }
        for stream in realDatabase.streams where stream.obsBrbSceneVideoSourceBroken == nil {
            stream.obsBrbSceneVideoSourceBroken = false
            store()
        }
        if realDatabase.djiDevices == nil {
            realDatabase.djiDevices = .init()
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.rtmpUrlType == nil {
            device.rtmpUrlType = .server
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.serverRtmpStreamId == nil {
            device.serverRtmpStreamId = .init()
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.serverRtmpUrl == nil {
            device.serverRtmpUrl = ""
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.customRtmpUrl == nil {
            device.customRtmpUrl = ""
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.autoRestartStream == nil {
            device.autoRestartStream = false
            store()
        }
        if realDatabase.chat.textToSpeechFilterMentions == nil {
            realDatabase.chat.textToSpeechFilterMentions = true
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.imageStabilization == nil {
            device.imageStabilization = .off
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.resolution == nil {
            device.resolution = .r1080p
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.bitrate == nil {
            device.bitrate = 6_000_000
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.isStarted == nil {
            device.isStarted = false
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.fps == nil {
            device.fps = 30
            store()
        }
        for device in realDatabase.djiDevices!.devices where device.model == nil {
            device.model = .unknown
            store()
        }
        for widget in database.widgets where widget.text.delay == nil {
            widget.text.delay = 0.0
            store()
        }
        for widget in database.widgets where widget.map!.delay == nil {
            widget.map!.delay = 0.0
            store()
        }
        for widget in database.widgets where widget.enabled == nil {
            widget.enabled = true
            store()
        }
        for widget in database.widgets where widget.text.timers == nil {
            widget.text.timers = []
            store()
        }
        for widget in database.widgets where widget.text.needsWeather == nil {
            widget.text.needsWeather = false
            store()
        }
        for widget in database.widgets where widget.text.clearForegroundColor! {
            widget.text.foregroundColor!.opacity = 0.0
            widget.text.clearForegroundColor = false
            store()
        }
        for widget in database.widgets where widget.text.clearBackgroundColor! {
            widget.text.backgroundColor!.opacity = 0.0
            widget.text.clearBackgroundColor = false
            store()
        }
        for widget in database.widgets where widget.text.needsGeography == nil {
            widget.text.needsGeography = false
            store()
        }
        for widget in database.widgets where widget.text.checkboxes == nil {
            widget.text.checkboxes = []
            store()
        }
        for widget in realDatabase.widgets where widget.alerts == nil {
            widget.alerts = .init()
            store()
        }
        for stream in realDatabase.streams where stream.twitchAccessToken == nil {
            stream.twitchAccessToken = ""
            store()
        }
        for widget in realDatabase.widgets where widget.alerts!.twitch == nil {
            widget.alerts!.twitch = .init()
            store()
        }
        for widget in realDatabase.widgets {
            if widget.alerts!.twitch!.follows.textToSpeechEnabled == nil {
                widget.alerts!.twitch!.follows.textToSpeechEnabled = true
                store()
            }
            if widget.alerts!.twitch!.follows.textToSpeechDelay == nil {
                widget.alerts!.twitch!.follows.textToSpeechDelay = 1.5
                store()
            }
            if widget.alerts!.twitch!.follows.textToSpeechLanguageVoices == nil {
                widget.alerts!.twitch!.follows.textToSpeechLanguageVoices = .init()
                store()
            }
            if widget.alerts!.twitch!.follows.imageLoopCount == nil {
                widget.alerts!.twitch!.follows.imageLoopCount = 1
                store()
            }
            if widget.alerts!.twitch!.follows.positionType == nil {
                widget.alerts!.twitch!.follows.positionType = .scene
                store()
            }
            if widget.alerts!.twitch!.follows.facePosition == nil {
                widget.alerts!.twitch!.follows.facePosition = .init()
                store()
            }
            if widget.alerts!.twitch!.subscriptions.textToSpeechEnabled == nil {
                widget.alerts!.twitch!.subscriptions.textToSpeechEnabled = true
                store()
            }
            if widget.alerts!.twitch!.subscriptions.textToSpeechDelay == nil {
                widget.alerts!.twitch!.subscriptions.textToSpeechDelay = 1.5
                store()
            }
            if widget.alerts!.twitch!.subscriptions.textToSpeechLanguageVoices == nil {
                widget.alerts!.twitch!.subscriptions.textToSpeechLanguageVoices = .init()
                store()
            }
            if widget.alerts!.twitch!.subscriptions.imageLoopCount == nil {
                widget.alerts!.twitch!.subscriptions.imageLoopCount = 1
                store()
            }
            if widget.alerts!.twitch!.subscriptions.positionType == nil {
                widget.alerts!.twitch!.subscriptions.positionType = .scene
                store()
            }
            if widget.alerts!.twitch!.subscriptions.facePosition == nil {
                widget.alerts!.twitch!.subscriptions.facePosition = .init()
                store()
            }
        }
        for widget in database.widgets where widget.text.ratings == nil {
            widget.text.ratings = []
            store()
        }
        if realDatabase.chat.botCommandPermissions == nil {
            realDatabase.chat.botCommandPermissions = .init()
            store()
        }
        for stream in realDatabase.streams where stream.twitchLoggedIn == nil {
            stream.twitchLoggedIn = false
            store()
        }
        if realDatabase.alertsMediaGallery == nil {
            realDatabase.alertsMediaGallery = .init()
            store()
        }
        updateBundledAlertsMediaGallery(database: realDatabase)
        if realDatabase.show.events == nil {
            realDatabase.show.events = true
            store()
        }
        for stream in realDatabase.streams where stream.twitchRewards == nil {
            stream.twitchRewards = .init()
            store()
        }
        if realDatabase.debug.twitchRewards == nil {
            realDatabase.debug.twitchRewards = false
            store()
        }
        for widget in realDatabase.widgets where widget.map!.migrated == nil {
            widget.map!.migrated = false
            store()
        }
        for widget in realDatabase.widgets where !widget.map!.migrated! {
            widget.map!.migrated = true
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
                        sceneWidget.width = (100 * Double(widget.map!.width) / width)
                            .clamped(to: 1 ... 100)
                        sceneWidget.height = (100 * Double(widget.map!.height) / height)
                            .clamped(to: 1 ... 100)
                    }
                }
            }
            store()
        }
        for widget in database.widgets where widget.text.needsSubtitles == nil {
            widget.text.needsSubtitles = false
            store()
        }
        for widget in realDatabase.widgets where widget.alerts!.chatBot == nil {
            widget.alerts!.chatBot = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions!.alert == nil {
            realDatabase.chat.botCommandPermissions!.alert = .init()
            store()
        }
        if realDatabase.chat.botSendLowBatteryWarning == nil {
            realDatabase.chat.botSendLowBatteryWarning = false
            store()
        }
        if realDatabase.catPrinters == nil {
            realDatabase.catPrinters = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fax == nil {
            realDatabase.chat.botCommandPermissions!.fax = .init()
            store()
        }
        let allLuts = realDatabase.color!.bundledLuts + (realDatabase.color!.diskLuts ?? [])
        for lut in allLuts where lut.enabled == nil {
            if let button = realDatabase.globalButtons!.first(where: { $0.id == lut.buttonId }) {
                lut.enabled = button.isOn
            } else {
                lut.enabled = false
            }
            store()
        }
        let newButtons = realDatabase.globalButtons!.filter { $0.type != .lut }
        if realDatabase.globalButtons!.count != newButtons.count {
            realDatabase.globalButtons = newButtons
            store()
        }
        for stream in realDatabase.streams where stream.obsMainScene == nil {
            stream.obsMainScene = ""
            store()
        }
        if realDatabase.verboseStatuses == nil {
            realDatabase.verboseStatuses = false
            store()
        }
        for widget in database.widgets where widget.alerts!.twitch!.raids == nil {
            widget.alerts!.twitch!.raids = .init()
            store()
        }
        for device in realDatabase.catPrinters!.devices where device.printChat == nil {
            device.printChat = true
            store()
        }
        if realDatabase.chat.badges == nil {
            realDatabase.chat.badges = true
            store()
        }
        if realDatabase.watch!.chat.badges == nil {
            realDatabase.watch!.chat.badges = true
            store()
        }
        if realDatabase.chat.botCommandPermissions!.tts.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions!.tts.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fix.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions!.fix.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.map.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions!.map.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.alert!.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions!.alert!.subscribersEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fax!.subscribersEnabled == nil {
            realDatabase.chat.botCommandPermissions!.fax!.subscribersEnabled = false
            store()
        }
        for stream in realDatabase.streams where stream.discordSnapshotWebhook == nil {
            stream.discordSnapshotWebhook = ""
            store()
        }
        for stream in realDatabase.streams where stream.discordSnapshotWebhookOnlyWhenLive == nil {
            stream.discordSnapshotWebhookOnlyWhenLive = true
            store()
        }
        if realDatabase.chat.botCommandPermissions!.snapshot == nil {
            realDatabase.chat.botCommandPermissions!.snapshot = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions!.filter == nil {
            realDatabase.chat.botCommandPermissions!.filter = .init()
            store()
        }
        for device in realDatabase.catPrinters!.devices where device.faxMeowSound == nil {
            device.faxMeowSound = true
            store()
        }
        if realDatabase.chat.botCommandPermissions!.tts.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.tts.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fix.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.fix.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.map.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.map.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.alert!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.alert!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fax!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.fax!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.snapshot!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.snapshot!.minimumSubscriberTier = 1
            store()
        }
        if realDatabase.chat.botCommandPermissions!.filter!.minimumSubscriberTier == nil {
            realDatabase.chat.botCommandPermissions!.filter!.minimumSubscriberTier = 1
            store()
        }
        for widget in database.widgets where widget.alerts!.twitch!.cheers == nil {
            widget.alerts!.twitch!.cheers = .init()
            store()
        }
        if realDatabase.debug.beautyFilterSettings!.showBlurBackground == nil {
            realDatabase.debug.beautyFilterSettings!.showBlurBackground = false
            store()
        }
        for widget in realDatabase.widgets where widget.browser.styleSheet == nil {
            widget.browser.styleSheet = ""
            store()
        }
        if realDatabase.chat.showFirstTimeChatterMessage == nil {
            realDatabase.chat.showFirstTimeChatterMessage = true
            store()
        }
        if realDatabase.chat.showNewFollowerMessage == nil {
            realDatabase.chat.showNewFollowerMessage = true
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource == nil {
            widget.videoSource = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cameraPosition == nil {
            widget.videoSource!.cameraPosition = .screenCapture
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.backCameraId == nil {
            widget.videoSource!.backCameraId = getBestBackCameraId()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.frontCameraId == nil {
            widget.videoSource!.frontCameraId = getBestFrontCameraId()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.rtmpCameraId == nil {
            widget.videoSource!.rtmpCameraId = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.srtlaCameraId == nil {
            widget.videoSource!.srtlaCameraId = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.mediaPlayerCameraId == nil {
            widget.videoSource!.mediaPlayerCameraId = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.externalCameraId == nil {
            widget.videoSource!.externalCameraId = ""
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.externalCameraName == nil {
            widget.videoSource!.externalCameraName = ""
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropEnabled == nil {
            widget.videoSource!.cropEnabled = false
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropX == nil {
            widget.videoSource!.cropX = 0.25
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropY == nil {
            widget.videoSource!.cropY = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropWidth == nil {
            widget.videoSource!.cropWidth = 0.5
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropHeight == nil {
            widget.videoSource!.cropHeight = 1.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropX! > 1.0 {
            widget.videoSource!.cropX = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropY! > 1.0 {
            widget.videoSource!.cropY = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropWidth! > 1.0 {
            widget.videoSource!.cropWidth = 1.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.cropHeight! > 1.0 {
            widget.videoSource!.cropHeight = 1.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.rotation == nil {
            widget.videoSource!.rotation = 0.0
            store()
        }
        if realDatabase.debug.removeWindNoise == nil {
            realDatabase.debug.removeWindNoise = false
            store()
        }
        for widget in realDatabase.widgets where widget.scoreboard == nil {
            widget.scoreboard = .init()
            store()
        }
        if realDatabase.scoreboardPlayers == nil {
            realDatabase.scoreboardPlayers = .init()
            store()
        }
        for widget in database.widgets where widget.alerts!.twitch!.cheerBits == nil {
            widget.alerts!.twitch!.cheerBits = createDefaultCheerBits()
            widget.alerts!.twitch!.cheerBits![0].alert = widget.alerts!.twitch!.cheers!.clone()
            store()
        }
        for stream in database.streams where stream.adaptiveEncoderResolution == nil {
            stream.adaptiveEncoderResolution = false
            store()
        }
        if realDatabase.debug.httpProxy == nil {
            realDatabase.debug.httpProxy = .init()
            store()
        }
        for stream in realDatabase.streams where stream.discordChatBotSnapshotWebhook == nil {
            stream.discordChatBotSnapshotWebhook = stream.discordSnapshotWebhook
            store()
        }
        for stream in realDatabase.streams where stream.estimatedViewerDelay == nil {
            stream.estimatedViewerDelay = 8.0
            store()
        }
        if realDatabase.remoteControl!.client.relay == nil {
            realDatabase.remoteControl!.client.relay = .init()
            store()
        }
        if realDatabase.debug.tesla == nil {
            realDatabase.debug.tesla = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions!.tesla == nil {
            realDatabase.chat.botCommandPermissions!.tesla = .init()
            store()
        }
        if realDatabase.watch!.viaRemoteControl == nil {
            realDatabase.watch!.viaRemoteControl = false
            store()
        }
        if realDatabase.keyboard == nil {
            realDatabase.keyboard = .init()
            store()
        }
        for stream in realDatabase.streams where stream.twitchMultiTrackEnabled == nil {
            stream.twitchMultiTrackEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.audio == nil {
            realDatabase.chat.botCommandPermissions!.audio = .init()
            store()
        }
        if realDatabase.tesla == nil {
            realDatabase.tesla = .init()
            realDatabase.tesla!.vin = realDatabase.debug.tesla!.vin
            realDatabase.tesla!.privateKey = realDatabase.debug.tesla!.privateKey
            store()
        }
        if realDatabase.debug.reliableChat == nil {
            realDatabase.debug.reliableChat = false
            store()
        }
        for scene in realDatabase.scenes where scene.videoSourceRotation == nil {
            scene.videoSourceRotation = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.alerts!.speechToText == nil {
            widget.alerts!.speechToText = .init()
            store()
        }
        for widget in realDatabase.widgets where widget.alerts!.needsSubtitles == nil {
            widget.alerts!.needsSubtitles = false
            store()
        }
        for stream in realDatabase.streams where stream.ntpPoolAddress == nil {
            stream.ntpPoolAddress = "time.apple.com"
            store()
        }
        for stream in realDatabase.streams where stream.timecodesEnabled == nil {
            stream.timecodesEnabled = false
            store()
        }
        if realDatabase.debug.timecodesEnabled == nil {
            realDatabase.debug.timecodesEnabled = false
            store()
        }
        if realDatabase.srtlaRelay == nil {
            realDatabase.srtlaRelay = .init()
            store()
        }
        if realDatabase.debug.dnsLookupStrategy == nil {
            realDatabase.debug.dnsLookupStrategy = .system
            store()
        }
        for stream in realDatabase.streams where stream.srt.dnsLookupStrategy == nil {
            stream.srt.dnsLookupStrategy = .system
            store()
        }
        for stream in realDatabase.deepLinkCreator!.streams where stream.srt.dnsLookupStrategy == nil {
            stream.srt.dnsLookupStrategy = .system
            store()
        }
        if realDatabase.debug.srtlaBatchSend == nil {
            realDatabase.debug.srtlaBatchSend = false
            store()
        }
        if realDatabase.chat.bottom == nil {
            realDatabase.chat.bottom = 0.0
            store()
        }
        if realDatabase.pixellateStrength == nil {
            realDatabase.pixellateStrength = 0.3
            store()
        }
        if realDatabase.moblink == nil {
            realDatabase.moblink = realDatabase.srtlaRelay
            store()
        }
        if realDatabase.debug.cameraControlsEnabled == nil {
            realDatabase.debug.cameraControlsEnabled = true
            store()
        }
        if realDatabase.show.djiDevices == nil {
            realDatabase.show.djiDevices = true
            store()
        }
        for stream in realDatabase.streams where stream.autoFps == nil {
            stream.autoFps = false
            store()
        }
        if realDatabase.chat.newMessagesAtTop == nil {
            realDatabase.chat.newMessagesAtTop = false
            store()
        }
        if realDatabase.color!.diskLutsPng == nil {
            realDatabase.color!.diskLutsPng = realDatabase.color!.diskLuts
            store()
        }
        if realDatabase.color!.diskLutsCube == nil {
            realDatabase.color!.diskLutsCube = []
            store()
        }
        if realDatabase.show.bondingRtts == nil {
            realDatabase.show.bondingRtts = false
            store()
        }
        if realDatabase.show.moblink == nil {
            realDatabase.show.moblink = true
            store()
        }
        if realDatabase.debug.dataRateLimitFactor == nil {
            realDatabase.debug.dataRateLimitFactor = 2.0
            store()
        }
        if realDatabase.debug.bitrateDropFix == nil {
            realDatabase.debug.bitrateDropFix = false
            store()
        }
        if realDatabase.debug.relaxedBitrate == nil {
            realDatabase.debug.relaxedBitrate = false
            store()
        }
        for scene in realDatabase.scenes where scene.videoStabilizationMode == nil {
            scene.videoStabilizationMode = .off
            store()
        }
        for scene in realDatabase.scenes where scene.overrideVideoStabilizationMode == nil {
            scene.overrideVideoStabilizationMode = false
            store()
        }
        for key in realDatabase.keyboard!.keys where key.widgetId == nil {
            key.widgetId = .init()
            store()
        }
        if realDatabase.sceneSwitchTransition == nil {
            realDatabase.sceneSwitchTransition = realDatabase.debug.blurSceneSwitch! ? .blur : .freeze
            store()
        }
        if realDatabase.forceSceneSwitchTransition == nil {
            realDatabase.forceSceneSwitchTransition = false
            store()
        }
        if realDatabase.location!.distance == nil {
            realDatabase.location!.distance = 0.0
            store()
        }
        if realDatabase.catPrinters!.backgroundPrinting == nil {
            realDatabase.catPrinters!.backgroundPrinting = false
            store()
        }
        if realDatabase.show.catPrinter == nil {
            realDatabase.show.catPrinter = true
            store()
        }
        if realDatabase.moblink!.client.manual == nil {
            realDatabase.moblink!.client.manual = !realDatabase.moblink!.client.url.isEmpty
            store()
        }
        if realDatabase.cameraControlsEnabled == nil {
            realDatabase.cameraControlsEnabled = realDatabase.debug.cameraControlsEnabled!
            store()
        }
        for widget in realDatabase.widgets where widget.text.alignment == nil {
            widget.text.alignment = .leading
            store()
        }
        if realDatabase.debug.externalDisplayChat == nil {
            realDatabase.debug.externalDisplayChat = false
            store()
        }
        if realDatabase.externalDisplayContent == nil {
            if realDatabase.debug.externalDisplayChat! {
                realDatabase.externalDisplayContent = .chat
            } else {
                realDatabase.externalDisplayContent = .stream
            }
            store()
        }
        for stream in realDatabase.streams where stream.recording!.cleanRecordings == nil {
            stream.recording!.cleanRecordings = false
            store()
        }
        for stream in realDatabase.streams where stream.recording!.cleanSnapshots == nil {
            stream.recording!.cleanSnapshots = false
            store()
        }
        for widget in realDatabase.widgets where widget.text.horizontalAlignment == nil {
            widget.text.horizontalAlignment = widget.text.alignment!
            store()
        }
        for widget in realDatabase.widgets where widget.text.verticalAlignment == nil {
            widget.text.verticalAlignment = .top
            store()
        }
        if realDatabase.cyclingPowerDevices == nil {
            realDatabase.cyclingPowerDevices = .init()
            store()
        }
        if realDatabase.heartRateDevices == nil {
            realDatabase.heartRateDevices = .init()
            store()
        }
        if realDatabase.show.cyclingPowerDevice == nil {
            realDatabase.show.cyclingPowerDevice = true
            store()
        }
        if realDatabase.show.heartRateDevice == nil {
            realDatabase.show.heartRateDevice = true
            store()
        }
        if realDatabase.djiGimbalDevices == nil {
            realDatabase.djiGimbalDevices = .init()
            store()
        }
        for widget in database.widgets where widget.text.lapTimes == nil {
            widget.text.lapTimes = []
            store()
        }
        for widget in realDatabase.widgets where widget.text.fontMonospacedDigits == nil {
            widget.text.fontMonospacedDigits = false
            store()
        }
        for scene in realDatabase.scenes where scene.fillFrame == nil {
            scene.fillFrame = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.reaction == nil {
            realDatabase.chat.botCommandPermissions!.reaction = .init()
            store()
        }
        if realDatabase.chat.botCommandPermissions!.scene == nil {
            realDatabase.chat.botCommandPermissions!.scene = .init()
            store()
        }
        if realDatabase.location!.resetWhenGoingLive == nil {
            realDatabase.location!.resetWhenGoingLive = false
            store()
        }
        if realDatabase.debug.videoSourceWidgetTrackFace == nil {
            realDatabase.debug.videoSourceWidgetTrackFace = false
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.trackFaceEnabled == nil {
            widget.videoSource!.trackFaceEnabled = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.tts.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.tts.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fix.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.fix.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.map.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.map.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.alert!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.alert!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.fax!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.fax!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.snapshot!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.snapshot!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.filter!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.filter!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.tesla!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.tesla!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.audio!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.audio!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.reaction!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.reaction!.sendChatMessages = false
            store()
        }
        if realDatabase.chat.botCommandPermissions!.scene!.sendChatMessages == nil {
            realDatabase.chat.botCommandPermissions!.scene!.sendChatMessages = false
            store()
        }
        for device in realDatabase.catPrinters!.devices where device.printSnapshots == nil {
            device.printSnapshots = true
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.mirror == nil {
            widget.videoSource!.mirror = false
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.trackFaceZoom == nil {
            widget.videoSource!.trackFaceZoom = 0.75
            store()
        }
        if realDatabase.sceneNumericInput == nil {
            realDatabase.sceneNumericInput = false
            store()
        }
        for widget in realDatabase.widgets {
            for command in widget.alerts!.chatBot!.commands where command.imageType == nil {
                command.imageType = .file
                store()
            }
            for command in widget.alerts!.chatBot!.commands where command.imagePlaygroundImageId == nil {
                command.imagePlaygroundImageId = .init()
                store()
            }
        }
        if realDatabase.debug.srtlaBatchSendEnabled == nil {
            realDatabase.debug.srtlaBatchSendEnabled = true
            store()
        }
        if realDatabase.goPro == nil {
            realDatabase.goPro = .init()
            store()
        }
        for launchLiveStream in realDatabase.goPro!.launchLiveStream where launchLiveStream.isHero12Or13 == nil {
            launchLiveStream.isHero12Or13 = true
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.borderWidth == nil {
            widget.videoSource!.borderWidth = 0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource!.borderColor == nil {
            widget.videoSource!.borderColor = .init(red: 0, green: 0, blue: 0)
            store()
        }
        if realDatabase.tesla!.enabled == nil {
            realDatabase.tesla!.enabled = true
            store()
        }
        if realDatabase.debug.replay == nil {
            realDatabase.debug.replay = false
            store()
        }
        if realDatabase.debug.recordSegmentLength == nil {
            realDatabase.debug.recordSegmentLength = 5.0
            store()
        }
        for stream in realDatabase.streams where stream.twitchShowFollows == nil {
            stream.twitchShowFollows = true
            store()
        }
        if realDatabase.replay == nil {
            realDatabase.replay = .init()
            store()
        }
        if realDatabase.replay!.position == nil {
            realDatabase.replay!.position = 10.0
            store()
        }
        if realDatabase.replay!.start == nil {
            realDatabase.replay!.start = 20.0
            store()
        }
        if realDatabase.replay!.stop == nil {
            realDatabase.replay!.stop = 30.0
            store()
        }
        if realDatabase.portraitVideoOffsetFromTop == nil {
            realDatabase.portraitVideoOffsetFromTop = 0.0
            store()
        }
    }
}
