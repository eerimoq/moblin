import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"
let defaultQuickButtonColor = RgbColor(red: 255 / 4, green: 255 / 4, blue: 255 / 4)
let defaultStreamButtonColor = RgbColor(red: 255, green: 59, blue: 48)
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
}

let resolutions = SettingsStreamResolution.allCases.map { $0.rawValue }

let fpss = ["60", "50", "30", "25", "15"]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
    case rist = "RIST"

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

    init(name: String) {
        self.name = name
    }

    func clone() -> SettingsStreamSrtConnectionPriority {
        let new = SettingsStreamSrtConnectionPriority(name: name)
        new.priority = priority
        new.enabled = enabled
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
    case fastIrl
    case slowIrl
    case customIrl

    static func fromString(value: String) -> SettingsStreamSrtAdaptiveBitrateAlgorithm {
        switch value {
        case String(localized: "Fast IRL"):
            return .fastIrl
        case String(localized: "Slow IRL"):
            return .slowIrl
        case String(localized: "Custom IRL"):
            return .customIrl
        default:
            return .fastIrl
        }
    }

    func toString() -> String {
        switch self {
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

    func clone() -> SettingsStreamSrtAdaptiveBitrateFastIrlSettings {
        let new = SettingsStreamSrtAdaptiveBitrateFastIrlSettings()
        new.packetsInFlight = packetsInFlight
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrateCustomSettings: Codable {
    var packetsInFlight: Int32 = 200
    var pifDiffIncreaseFactor: Float = 100
    var rttDiffHighDecreaseFactor: Float = 0.9
    var rttDiffHighAllowedSpike: Float = 50
    var rttDiffHighMinimumDecrease: Float = 250

    func clone() -> SettingsStreamSrtAdaptiveBitrateCustomSettings {
        let new = SettingsStreamSrtAdaptiveBitrateCustomSettings()
        new.packetsInFlight = packetsInFlight
        new.pifDiffIncreaseFactor = pifDiffIncreaseFactor
        new.rttDiffHighDecreaseFactor = rttDiffHighDecreaseFactor
        new.rttDiffHighAllowedSpike = rttDiffHighAllowedSpike
        new.rttDiffHighMinimumDecrease = rttDiffHighMinimumDecrease
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrate: Codable {
    var algorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm = .fastIrl
    var fastIrlSettings: SettingsStreamSrtAdaptiveBitrateFastIrlSettings? = .init()
    var customSettings: SettingsStreamSrtAdaptiveBitrateCustomSettings = .init()

    func clone() -> SettingsStreamSrtAdaptiveBitrate {
        let new = SettingsStreamSrtAdaptiveBitrate()
        new.algorithm = algorithm
        new.fastIrlSettings = fastIrlSettings!.clone()
        new.customSettings = customSettings.clone()
        return new
    }
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = 2000
    var maximumBandwidthFollowInput: Bool? = true
    var overheadBandwidth: Int32? = 25
    var adaptiveBitrateEnabled: Bool? = true
    var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate? = .init()
    var connectionPriorities: SettingsStreamSrtConnectionPriorities? = .init()
    var mpegtsPacketsPerPacket: Int = 7

    func clone() -> SettingsStreamSrt {
        let new = SettingsStreamSrt()
        new.latency = latency
        new.overheadBandwidth = overheadBandwidth
        new.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.adaptiveBitrate = adaptiveBitrate!.clone()
        new.connectionPriorities = connectionPriorities!.clone()
        new.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
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
    var bttvEmotes: Bool = true
    var ffzEmotes: Bool = true
    var seventvEmotes: Bool = true

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

    func clone() -> SettingsStreamRecording {
        let new = SettingsStreamRecording()
        new.videoCodec = videoCodec
        new.videoBitrate = videoBitrate
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.autoStartRecording = autoStartRecording
        new.autoStopRecording = autoStopRecording
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

class SettingsStream: Codable, Identifiable, Equatable {
    static func == (lhs: SettingsStream, rhs: SettingsStream) -> Bool {
        lhs.id == rhs.id
    }

    var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    var url: String = defaultStreamUrl
    var twitchEnabled: Bool? = true
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var kickEnabled: Bool? = true
    var kickChatroomId: String = ""
    var kickChannelName: String? = ""
    var youTubeEnabled: Bool? = true
    var youTubeApiKey: String? = ""
    var youTubeVideoId: String? = ""
    var afreecaTvEnabled: Bool? = true
    var afreecaTvChannelName: String? = ""
    var afreecaTvStreamId: String? = ""
    var openStreamingPlatformEnabled: Bool? = true
    var openStreamingPlatformUrl: String? = ""
    var openStreamingPlatformChannelId: String? = ""
    var obsWebSocketEnabled: Bool? = true
    var obsWebSocketUrl: String? = ""
    var obsWebSocketPassword: String? = ""
    var obsSourceName: String? = ""
    var resolution: SettingsStreamResolution = .r1920x1080
    var fps: Int = 30
    var bitrate: UInt32 = 5_000_000
    var codec: SettingsStreamCodec = .h265hevc
    var bFrames: Bool? = false
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

    init(name: String) {
        self.name = name
    }

    func clone() -> SettingsStream {
        let new = SettingsStream(name: name)
        new.url = url
        new.twitchEnabled = twitchEnabled
        new.twitchChannelName = twitchChannelName
        new.twitchChannelId = twitchChannelId
        new.kickEnabled = kickEnabled
        new.kickChatroomId = kickChatroomId
        new.kickChannelName = kickChannelName
        new.youTubeEnabled = youTubeEnabled
        new.youTubeApiKey = youTubeApiKey
        new.youTubeVideoId = youTubeVideoId
        new.afreecaTvEnabled = afreecaTvEnabled
        new.afreecaTvChannelName = afreecaTvChannelName
        new.afreecaTvStreamId = afreecaTvStreamId
        new.openStreamingPlatformEnabled = openStreamingPlatformEnabled
        new.openStreamingPlatformUrl = openStreamingPlatformUrl
        new.openStreamingPlatformChannelId = openStreamingPlatformChannelId
        new.obsWebSocketEnabled = obsWebSocketEnabled
        new.obsWebSocketUrl = obsWebSocketUrl
        new.obsWebSocketPassword = obsWebSocketPassword
        new.obsSourceName = obsSourceName
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
}

// periphery:ignore
class SettingsSceneButton: Codable {}

enum SettingsSceneCameraPosition: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"
    case rtmp = "RTMP"
    case external = "External"

    public init(from decoder: Decoder) throws {
        self = try SettingsSceneCameraPosition(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .back
    }
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
    var externalCameraId: String? = ""
    var externalCameraName: String? = ""
    var widgets: [SettingsSceneWidget] = []
    // periphery:ignore
    var buttons: [SettingsSceneButton]? = []

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
        new.externalCameraId = externalCameraId
        new.externalCameraName = externalCameraName
        for widget in widgets {
            new.widgets.append(widget.clone())
        }
        return new
    }
}

class SettingsWidgetText: Codable {
    var formatString: String = "{time}"
}

// periphery:ignore
class SettingsWidgetImage: Codable {
    var url: String = "https://"
}

// periphery:ignore
class SettingsWidgetVideo: Codable {
    var url: String = "https://"
}

class SettingsWidgetChat: Codable {}

class SettingsWidgetRecording: Codable {}

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

    static func fromString(value: String) -> SettingsWidgetVideoEffectType {
        switch value {
        case String(localized: "Movie"):
            return .movie
        case String(localized: "Gray scale"):
            return .grayScale
        case String(localized: "Sepia"):
            return .sepia
        case String(localized: "Bloom"):
            return .bloom
        case String(localized: "Random"):
            return .random
        case String(localized: "Triple"):
            return .triple
        case String(localized: "Noise reduction"):
            return .noiseReduction
        case String(localized: "Pixellate"):
            return .pixellate
        default:
            return .movie
        }
    }

    func toString() -> String {
        switch self {
        case .movie:
            return String(localized: "Movie")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .bloom:
            return String(localized: "Bloom")
        case .random:
            return String(localized: "Random")
        case .triple:
            return String(localized: "Triple")
        case .noiseReduction:
            return String(localized: "Noise reduction")
        case .pixellate:
            return String(localized: "Pixellate")
        }
    }
}

let videoEffects = SettingsWidgetVideoEffectType.allCases.filter { effect in
    effect == .noiseReduction
}.map { $0.toString() }

class SettingsWidgetVideoEffect: Codable {
    var type: SettingsWidgetVideoEffectType = .noiseReduction
    var noiseReductionNoiseLevel: Float = 0.01
    var noiseReductionSharpness: Float = 1.5
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case browser = "Browser"
    case image = "Image"
    case time = "Time"
    case videoEffect = "Video effect"
    case crop = "Crop"

    public init(from decoder: Decoder) throws {
        self = try SettingsWidgetType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .browser
    }

    static func fromString(value: String) -> SettingsWidgetType {
        switch value {
        case String(localized: "Browser"):
            return .browser
        case String(localized: "Image"):
            return .image
        case String(localized: "Time"):
            return .time
        case String(localized: "Video effect"):
            return .videoEffect
        case String(localized: "Crop"):
            return .crop
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
        case .time:
            return String(localized: "Time")
        case .videoEffect:
            return String(localized: "Video effect")
        case .crop:
            return String(localized: "Crop")
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases.map { $0.toString() }

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .browser
    var text: SettingsWidgetText = .init()
    // periphery:ignore
    var image: SettingsWidgetImage? = .init()
    // periphery:ignore
    var video: SettingsWidgetVideo? = .init()
    // periphery:ignore
    var chat: SettingsWidgetChat? = .init()
    // periphery:ignore
    var recording: SettingsWidgetRecording? = .init()
    var browser: SettingsWidgetBrowser = .init()
    var videoEffect: SettingsWidgetVideoEffect = .init()
    var crop: SettingsWidgetCrop? = .init()

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsWidget, rhs: SettingsWidget) -> Bool {
        return lhs.id == rhs.id
    }
}

// periphery:ignore
class SettingsVariableText: Codable {
    var value: String = "15.0"
}

// periphery:ignore
class SettingsVariableHttp: Codable {
    var url: String = "https://"
}

// periphery:ignore
class SettingsVariableTwitchPubSub: Codable {
    var pattern: String = ""
}

// periphery:ignore
class SettingsVariableTextWebsocket: Codable {
    var url: String = "https://"
    var pattern: String = ""
}

enum SettingsVariableType: String, Codable {
    case text = "Camera"
    case http = "HTTP"
    case twitchPubSub = "Twitch PubSub"
    case websocket = "Websocket"

    public init(from decoder: Decoder) throws {
        self = try SettingsVariableType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .text
    }
}

// periphery:ignore
class SettingsVariable: Codable, Identifiable {
    var name: String
    var id: UUID = .init()
    var type: SettingsVariableType = .text
    var text: SettingsVariableText = .init()
    var http: SettingsVariableHttp = .init()
    var twitchPubSub: SettingsVariableTwitchPubSub = .init()
    var websocket: SettingsVariableTextWebsocket = .init()
}

enum SettingsButtonType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case widget = "Widget"
    case mic = "Mic"
    case chat = "Chat"
    case interactiveChat = "Interactive chat"
    case blackScreen = "Black screen"
    case record = "Record"
    case recordings = "Recrodings"
    case image = "Image"
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case random = "Random"
    case triple = "Triple"
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

    public init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Interactive chat"
        }
        self = SettingsButtonType(rawValue: value) ?? .unknown
    }
}

// periphery:ignore
class SettingsButtonWidget: Codable, Identifiable {
    var widgetId: UUID
    var id: UUID = .init()

    init(widgetId: UUID) {
        self.widgetId = widgetId
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
    // periphery:ignore
    var widget: SettingsButtonWidget? = .init(widgetId: UUID())
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
    var buttonId: UUID?

    init(type: SettingsColorLutType, name: String) {
        self.type = type
        self.name = name
    }
}

enum SettingsColorSpace: String, Codable, CaseIterable {
    case srgb = "Standard RGB"
    case p3D65 = "P3 D65"
    // case hlgBt2020 = "HLG BT2020"
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

private let bundledLutsButtonIcons = [
    "Apple Log To Rec 709": "apple.logo",
    "Moblin Meme": "tornado",
]

class SettingsColor: Codable {
    var space: SettingsColorSpace = .srgb
    var lutEnabled: Bool = true
    var lut: UUID = .init()
    var bundledLuts = allBundledLuts
    var diskLuts: [SettingsColorLut]? = []
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
    var audioBar: Bool = true
    var cameras: Bool? = false
    var obsStatus: Bool? = true
    var rtmpSpeed: Bool? = true
    var gameController: Bool? = true
    var location: Bool? = true
    var remoteControl: Bool? = true
    var browserWidgets: Bool? = true
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
        }
    }
}

var videoStabilizationModes = SettingsVideoStabilizationMode.allCases.map { $0.toString() }

class RgbColor: Codable {
    var red: Int = 0
    var green: Int = 0
    var blue: Int = 0

    init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

class SettingsChatUsername: Identifiable, Codable {
    var id = UUID()
    var value: String = ""
}

class SettingsChat: Codable {
    var fontSize: Float = 17.0
    var usernameColor: RgbColor = .init(red: 255, green: 163, blue: 0)
    var messageColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    var backgroundColorEnabled: Bool = true
    var shadowColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    var shadowColorEnabled: Bool = false
    // periphery:ignore
    var alignedMessages: Bool? = false
    var boldUsername: Bool = false
    var boldMessage: Bool = false
    var animatedEmotes: Bool = false
    var timestampColor: RgbColor = .init(red: 180, green: 180, blue: 180)
    var timestampColorEnabled: Bool = true
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
    var mirrored: Bool? = false
}

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
    case top = "Top"

    public init(from decoder: Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .bottom
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

let logLevels = SettingsLogLevel.allCases.map { $0.rawValue }

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
    var showColors = false
    var showMoblin = false
    // periphery:ignore
    var showComic = false
    // periphery:ignore
    var showFaceRectangle = false
    var showFaceLandmarks = false
    var brightness: Float = 0.0
    var contrast: Float = 1.0
    var saturation: Float = 1.0
    var showCute: Bool? = false
    var cuteRadius: Float? = 0.5
    var cuteScale: Float? = 0.0
    var cuteOffset: Float? = 0.5
}

class SettingsDebug: Codable {
    var logLevel: SettingsLogLevel = .error
    var srtOverlay: Bool = false
    var srtOverheadBandwidth: Int32? = 25
    var letItSnow: Bool? = false
    var recordingsFolder: Bool? = false
    var cameraSwitchRemoveBlackish: Float? = 0.3
    var maximumBandwidthFollowInput: Bool? = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap? = .init()
    var bluetoothOutputOnly: Bool? = false
    var maximumLogLines: Int? = 500
    var pixelFormat: String? = pixelFormats[1]
    var beautyFilter: Bool? = false
    var beautyFilterSettings: SettingsDebugBeautyFilter? = .init()
    var allowVideoRangePixelFormat: Bool? = false
}

class SettingsRtmpServerStream: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My stream"
    var streamKey: String = ""
    var latency: Int32? = 2000
    var fps: Double? = 0

    func camera() -> String {
        return rtmpCamera(name: name)
    }

    func clone() -> SettingsRtmpServerStream {
        let new = SettingsRtmpServerStream()
        new.name = name
        new.streamKey = streamKey
        new.latency = latency
        new.fps = fps
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

class SettingsQuickButtons: Codable {
    var twoColumns: Bool = true
    var showName: Bool = false
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
    case interactiveChat = "Interactive chat"
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
        case String(localized: "Interactive chat"):
            return .interactiveChat
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
        case .interactiveChat:
            return String(localized: "Interactive chat")
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
        button.function = .interactiveChat
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
        button.function = .interactiveChat
        buttons.append(button)
    }
}

class SettingsRemoteControlClient: Codable {
    var enabled: Bool = false
    // periphery:ignore
    var address: String = ""
    var port: UInt16 = 2345
    // periphery:ignore
    var password: String? = ""
}

class SettingsRemoteControlServer: Codable {
    var enabled: Bool = false
    var url: String = ""
    // periphery:ignore
    var password: String? = ""
}

class SettingsRemoteControl: Codable {
    var client: SettingsRemoteControlClient = .init()
    var server: SettingsRemoteControlServer = .init()
    var password: String? = ""
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

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    // periphery:ignore
    var variables: [SettingsVariable]? = []
    // periphery:ignore
    var buttons: [SettingsButton]? = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    var tapToFocus: Bool = false
    var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var batteryPercentage: Bool? = true
    var mic: SettingsMic? = getDefaultMic()
    var debug: SettingsDebug? = .init()
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
    // periphery:ignore
    var mirrorFrontCameraOnStream: Bool? = false
    var streamButtonColor: RgbColor? = defaultStreamButtonColor
    var location: SettingsLocation? = .init()
    var watch: WatchSettings? = .init()
    var audio: AudioSettings? = .init()
    var webBrowser: WebBrowserSettings? = .init()

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
        addMissingGlobalButtons(database: database)
        for button in database.globalButtons! {
            button.isOn = false
        }
        addMissingBundledLuts(database: database)
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
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
            let nameX = x < 1 ? formatOneDecimal(value: x) : String(Int(x))
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
        SettingsBitratePreset(id: UUID(), bitrate: 7_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
    ]
}

private func updateGlobalButton(database: Database, button: SettingsButton) {
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

private func addMissingGlobalButtons(database: Database) {
    if database.globalButtons == nil {
        database.globalButtons = []
    }
    var button = SettingsButton(name: String(localized: "Torch"))
    button.id = UUID()
    button.type = .torch
    button.imageType = "System name"
    button.systemImageNameOn = "flashlight.on.fill"
    button.systemImageNameOff = "flashlight.off.fill"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Mute"))
    button.id = UUID()
    button.type = .mute
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Bitrate"))
    button.id = UUID()
    button.type = .bitrate
    button.imageType = "System name"
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Mic"))
    button.id = UUID()
    button.type = .mic
    button.imageType = "System name"
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Chat"))
    button.id = UUID()
    button.type = .chat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Interactive chat"))
    button.id = UUID()
    button.type = .interactiveChat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Draw"))
    button.id = UUID()
    button.type = .draw
    button.imageType = "System name"
    button.systemImageNameOn = "pencil.line"
    button.systemImageNameOff = "pencil.line"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Camera"))
    button.id = UUID()
    button.type = .image
    button.imageType = "System name"
    button.systemImageNameOn = "camera"
    button.systemImageNameOff = "camera"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Black screen"))
    button.id = UUID()
    button.type = .blackScreen
    button.imageType = "System name"
    button.systemImageNameOn = "sunset"
    button.systemImageNameOff = "sunset"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "OBS"))
    button.id = UUID()
    button.type = .obs
    button.imageType = "System name"
    button.systemImageNameOn = "xserve"
    button.systemImageNameOff = "xserve"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Remote"))
    button.id = UUID()
    button.type = .remote
    button.imageType = "System name"
    button.systemImageNameOn = "appletvremote.gen1"
    button.systemImageNameOff = "appletvremote.gen1"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Record"))
    button.id = UUID()
    button.type = .record
    button.imageType = "System name"
    button.systemImageNameOn = "record.circle.fill"
    button.systemImageNameOff = "record.circle"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Stream"))
    button.id = UUID()
    button.type = .stream
    button.imageType = "System name"
    button.systemImageNameOn = "dot.radiowaves.left.and.right"
    button.systemImageNameOff = "dot.radiowaves.left.and.right"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Recordings"))
    button.id = UUID()
    button.type = .recordings
    button.imageType = "System name"
    button.systemImageNameOn = "photo.on.rectangle.angled"
    button.systemImageNameOff = "photo.on.rectangle.angled"
    updateGlobalButton(database: database, button: button)

    // button = SettingsButton(name: String(localized: "Camera preview"))
    // button.id = UUID()
    // button.type = .cameraPreview
    // button.imageType = "System name"
    // button.systemImageNameOn = "photo.tv"
    // button.systemImageNameOff = "photo.tv"
    // updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Browser"))
    button.id = UUID()
    button.type = .browser
    button.imageType = "System name"
    button.systemImageNameOn = "globe"
    button.systemImageNameOff = "globe"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Grid"))
    button.id = UUID()
    button.type = .grid
    button.imageType = "System name"
    button.systemImageNameOn = "grid"
    button.systemImageNameOff = "grid"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Face"))
    button.id = UUID()
    button.type = .face
    button.imageType = "System name"
    button.systemImageNameOn = "theatermask.and.paintbrush"
    button.systemImageNameOff = "theatermask.and.paintbrush"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Movie"))
    button.id = UUID()
    button.type = .movie
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Gray scale"))
    button.id = UUID()
    button.type = .grayScale
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Sepia"))
    button.id = UUID()
    button.type = .sepia
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent"
    button.systemImageNameOff = "moonphase.waning.crescent"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Random"))
    button.id = UUID()
    button.type = .random
    button.imageType = "System name"
    button.systemImageNameOn = "dice.fill"
    button.systemImageNameOff = "dice"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Triple"))
    button.id = UUID()
    button.type = .triple
    button.imageType = "System name"
    button.systemImageNameOn = "person.3.fill"
    button.systemImageNameOff = "person.3"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Pixellate"))
    button.id = UUID()
    button.type = .pixellate
    button.imageType = "System name"
    button.systemImageNameOn = "squareshape.split.2x2"
    button.systemImageNameOff = "squareshape.split.2x2"
    updateGlobalButton(database: database, button: button)

    button = SettingsButton(name: String(localized: "Local overlays"))
    button.id = UUID()
    button.type = .localOverlays
    button.imageType = "System name"
    button.systemImageNameOn = "square.stack.3d.up.slash.fill"
    button.systemImageNameOff = "square.stack.3d.up.slash"
    updateGlobalButton(database: database, button: button)

    database.globalButtons = database.globalButtons!.filter { button in
        button.type != .unknown
    }
}

private func addMissingBundledLutButton(database: Database, lut: SettingsColorLut) {
    if lut.buttonId == nil {
        let button = SettingsButton(name: lut.name)
        button.type = .lut
        lut.buttonId = button.id
        database.globalButtons!.append(button)
    }
    if let button = database.globalButtons!.first(where: { $0.id == lut.buttonId }) {
        let imageName = bundledLutsButtonIcons[lut.name] ?? "apple.logo"
        button.systemImageNameOn = imageName
        button.systemImageNameOff = imageName
    }
}

private func addMissingBundledLuts(database: Database) {
    var bundledLuts: [SettingsColorLut] = []
    for lut in allBundledLuts {
        if let existingLut = database.color!.bundledLuts.first(where: { $0.name == lut.name }) {
            addMissingBundledLutButton(database: database, lut: existingLut)
            bundledLuts.append(existingLut)
        } else {
            addMissingBundledLutButton(database: database, lut: lut)
            bundledLuts.append(lut)
        }
    }
    database.color!.bundledLuts = bundledLuts
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
    addMissingGlobalButtons(database: database)
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
        migrateFromOlderVersions()
    }

    func store() {
        do {
            storage = try realDatabase.toString()
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

    private func migrateFromOlderVersions() {
        if realDatabase.batteryPercentage == nil {
            realDatabase.batteryPercentage = true
            store()
        }
        if realDatabase.chat.height == nil {
            realDatabase.chat.height = 1.0
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
        if realDatabase.mic == nil {
            realDatabase.mic = getDefaultMic()
            store()
        }
        if realDatabase.debug == nil {
            realDatabase.debug = .init()
            store()
        }
        if realDatabase.debug!.srtOverheadBandwidth == nil {
            realDatabase.debug!.srtOverheadBandwidth = 25
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
        var bloomWidgets: [SettingsWidget] = []
        for widget in realDatabase.widgets where widget.type == .videoEffect {
            if widget.videoEffect.type == .bloom {
                bloomWidgets.append(widget)
            }
        }
        if !bloomWidgets.isEmpty {
            realDatabase.widgets = realDatabase.widgets.filter { widget in
                !bloomWidgets.contains(widget)
            }
            for scene in realDatabase.scenes {
                scene.widgets = scene.widgets.filter { widget in
                    !bloomWidgets.contains { bloomWidget in
                        bloomWidget.id == widget.widgetId
                    }
                }
            }
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
        for stream in realDatabase.streams where stream.twitchEnabled == nil {
            stream.twitchEnabled = true
            store()
        }
        for stream in realDatabase.streams where stream.kickEnabled == nil {
            stream.kickEnabled = true
            store()
        }
        for stream in realDatabase.streams where stream.youTubeEnabled == nil {
            stream.youTubeEnabled = true
            store()
        }
        for stream in realDatabase.streams where stream.afreecaTvEnabled == nil {
            stream.afreecaTvEnabled = true
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
        if realDatabase.debug!.letItSnow == nil {
            realDatabase.debug!.letItSnow = false
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
            stream.latency = 2000
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
        if realDatabase.debug!.recordingsFolder == nil {
            realDatabase.debug!.recordingsFolder = false
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
        if realDatabase.debug!.cameraSwitchRemoveBlackish == nil {
            realDatabase.debug!.cameraSwitchRemoveBlackish = 0.3
            store()
        }
        for stream in realDatabase.rtmpServer!.streams where stream.fps == nil {
            stream.fps = 0
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
            if button.name != "Camera" {
                button.name = "Camera"
                store()
            }
            if button.systemImageNameOn != "camera" {
                button.systemImageNameOn = "camera"
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
        if realDatabase.debug!.maximumBandwidthFollowInput == nil {
            realDatabase.debug!.maximumBandwidthFollowInput = true
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
            stream.srt.overheadBandwidth = realDatabase.debug!.srtOverheadBandwidth!
            store()
        }
        for stream in realDatabase.streams where stream.srt.maximumBandwidthFollowInput == nil {
            stream.srt.maximumBandwidthFollowInput = realDatabase.debug!.maximumBandwidthFollowInput!
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
            realDatabase.remoteControl!.password = ""
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
        if realDatabase.debug!.audioOutputToInputChannelsMap == nil {
            realDatabase.debug!.audioOutputToInputChannelsMap = .init()
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
        if realDatabase.debug!.bluetoothOutputOnly == nil {
            realDatabase.debug!.bluetoothOutputOnly = false
            store()
        }
        if realDatabase.debug!.maximumLogLines == nil {
            realDatabase.debug!.maximumLogLines = 500
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
        for stream in realDatabase.streams where stream.openStreamingPlatformEnabled == nil {
            stream.openStreamingPlatformEnabled = true
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
            realDatabase.audio!.audioOutputToInputChannelsMap!.channel1 = realDatabase.debug!
                .audioOutputToInputChannelsMap!.channel0
            realDatabase.audio!.audioOutputToInputChannelsMap!.channel2 = realDatabase.debug!
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
        if realDatabase.debug!.pixelFormat == nil {
            realDatabase.debug!.pixelFormat = pixelFormats[1]
            store()
        }
        if realDatabase.chat.mirrored == nil {
            realDatabase.chat.mirrored = false
            store()
        }
        if realDatabase.debug!.beautyFilter == nil {
            realDatabase.debug!.beautyFilter = false
            store()
        }
        if realDatabase.debug!.beautyFilterSettings == nil {
            realDatabase.debug!.beautyFilterSettings = .init()
            store()
        }
        if realDatabase.debug!.beautyFilterSettings!.showCute == nil {
            realDatabase.debug!.beautyFilterSettings!.showCute = false
            store()
        }
        if realDatabase.debug!.beautyFilterSettings!.cuteRadius == nil {
            realDatabase.debug!.beautyFilterSettings!.cuteRadius = 0.5
            store()
        }
        if realDatabase.debug!.beautyFilterSettings!.cuteScale == nil {
            realDatabase.debug!.beautyFilterSettings!.cuteScale = 0.0
            store()
        }
        if realDatabase.debug!.beautyFilterSettings!.cuteOffset == nil {
            realDatabase.debug!.beautyFilterSettings!.cuteOffset = 0.5
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
        if realDatabase.debug!.allowVideoRangePixelFormat == nil {
            realDatabase.debug!.allowVideoRangePixelFormat = false
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
    }
}
