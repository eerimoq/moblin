import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"
let defaultQuickButtonColor = RgbColor(red: 255 / 4, green: 255 / 4, blue: 255 / 4)
let defaultStreamButtonBackgroundColor = RgbColor(red: 255, green: 59, blue: 48)
let defaultStreamButtonForegroundColor = RgbColor(red: 254, green: 254, blue: 254)

enum SettingsStreamCodec: String, Codable, CaseIterable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"
}

let codecs = SettingsStreamCodec.allCases.map { $0.rawValue }

enum SettingsStreamResolution: String, Codable, CaseIterable {
    case r3840x2160 = "3840x2160"
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"
}

let resolutions = SettingsStreamResolution.allCases.map { $0.rawValue }

let fpss = ["60", "50", "30", "25", "15"]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
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
    var customSettings: SettingsStreamSrtAdaptiveBitrateCustomSettings = .init()

    func clone() -> SettingsStreamSrtAdaptiveBitrate {
        let new = SettingsStreamSrtAdaptiveBitrate()
        new.algorithm = algorithm
        new.customSettings = customSettings.clone()
        return new
    }
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = 2000
    var maximumBandwidthFollowInput: Bool? = true
    var overheadBandwidth: Int32? = 25
    var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate? = .init()
    var connectionPriorities: SettingsStreamSrtConnectionPriorities? = .init()
    var mpegtsPacketsPerPacket: Int = 7

    func clone() -> SettingsStreamSrt {
        let new = SettingsStreamSrt()
        new.latency = latency
        new.overheadBandwidth = overheadBandwidth
        new.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        new.adaptiveBitrate = adaptiveBitrate!.clone()
        new.connectionPriorities = connectionPriorities!.clone()
        new.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
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

    func clone() -> SettingsStreamRecording {
        let new = SettingsStreamRecording()
        new.videoCodec = videoCodec
        new.videoBitrate = videoBitrate
        new.maxKeyFrameInterval = maxKeyFrameInterval
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
    var youTubeEnabled: Bool? = true
    var youTubeApiKey: String? = ""
    var youTubeVideoId: String? = ""
    var afreecaTvEnabled: Bool? = true
    var afreecaTvChannelName: String? = ""
    var afreecaTvStreamId: String? = ""
    var obsWebSocketEnabled: Bool? = true
    var obsWebSocketUrl: String? = ""
    var obsWebSocketPassword: String? = ""
    var obsSourceName: String? = ""
    var resolution: SettingsStreamResolution = .r1920x1080
    var fps: Int = 30
    var bitrate: UInt32 = 5_000_000
    var codec: SettingsStreamCodec = .h265hevc
    var bFrames: Bool? = false
    var adaptiveBitrate: Bool = true
    var srt: SettingsStreamSrt = .init()
    var captureSessionPresetEnabled: Bool? = false
    var captureSessionPreset: SettingsCaptureSessionPreset? = .medium
    var maxKeyFrameInterval: Int32? = 2
    var audioBitrate: Int? = 128_000
    var chat: SettingsStreamChat? = .init()
    var recording: SettingsStreamRecording? = .init()
    var realtimeIrlEnabled: Bool? = false
    var realtimeIrlPushKey: String? = ""

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
        new.youTubeEnabled = youTubeEnabled
        new.youTubeApiKey = youTubeApiKey
        new.youTubeVideoId = youTubeVideoId
        new.afreecaTvEnabled = afreecaTvEnabled
        new.afreecaTvChannelName = afreecaTvChannelName
        new.afreecaTvStreamId = afreecaTvStreamId
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
        new.captureSessionPresetEnabled = captureSessionPresetEnabled
        new.captureSessionPreset = captureSessionPreset
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.chat = chat?.clone()
        new.recording = recording?.clone()
        new.realtimeIrlEnabled = realtimeIrlEnabled
        new.realtimeIrlPushKey = realtimeIrlPushKey
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

    func resolutionString() -> String {
        switch resolution {
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

    func codecString() -> String {
        switch codec {
        case .h265hevc:
            return "H.265"
        case .h264avc:
            return "H.264"
        }
    }

    func bitrateString() -> String {
        var bitrate = formatBytesPerSecond(speed: Int64(bitrate))
        if getProtocol() == .srt && adaptiveBitrate {
            bitrate = "<\(bitrate)"
        }
        return bitrate
    }

    func audioBitrateString() -> String {
        return formatBytesPerSecond(speed: Int64(audioBitrate!))
    }

    func audioCodecString() -> String {
        return "AAC"
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

class SettingsSceneButton: Codable, Identifiable, Equatable {
    static func == (lhs: SettingsSceneButton, rhs: SettingsSceneButton) -> Bool {
        return lhs.id == rhs.id
    }

    var buttonId: UUID
    var id: UUID = .init()
    var enabled: Bool = true

    init(buttonId: UUID) {
        self.buttonId = buttonId
    }

    func clone() -> SettingsSceneButton {
        let new = SettingsSceneButton(buttonId: buttonId)
        new.enabled = enabled
        return new
    }
}

enum SettingsSceneCameraPosition: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"
    case rtmp = "RTMP"
    case external = "External"

    static func fromString(value: String) -> SettingsSceneCameraPosition {
        switch value {
        case String(localized: "Back"):
            return .back
        case String(localized: "Front"):
            return .front
        case String(localized: "RTMP"):
            return .rtmp
        case String(localized: "External"):
            return .external
        default:
            return .back
        }
    }

    func toString() -> String {
        switch self {
        case .back:
            return String(localized: "Back")
        case .front:
            return String(localized: "Front")
        case .rtmp:
            return String(localized: "RTMP")
        case .external:
            return String(localized: "External")
        }
    }
}

var cameraPositions = SettingsSceneCameraPosition.allCases.filter { position in
    position != .rtmp && position != .external
}.map { $0.toString() }

enum SettingsSceneCameraLayout: String, Codable, CaseIterable {
    case single = "Single"
    case pip = "Picture in Picture"

    static func fromString(value: String) -> SettingsSceneCameraLayout {
        switch value {
        case String(localized: "Single"):
            return .single
        case String(localized: "Picture in Picture"):
            return .pip
        default:
            return .single
        }
    }

    func toString() -> String {
        switch self {
        case .single:
            return String(localized: "Single")
        case .pip:
            return String(localized: "Picture in Picture")
        }
    }
}

var cameraLayouts = SettingsSceneCameraLayout.allCases.map { $0.toString() }

class SettingsSceneCameraLayoutPip: Codable {
    var x: Double = 65.0
    var y: Double = 0.0
    var width: Double = 35.0
    var height: Double = 35.0

    func clone() -> SettingsSceneCameraLayoutPip {
        let new = SettingsSceneCameraLayoutPip()
        new.x = x
        new.y = y
        new.width = width
        new.height = height
        return new
    }
}

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = true
    var cameraLayout: SettingsSceneCameraLayout? = .single
    var cameraType: SettingsSceneCameraPosition = .back
    var cameraPosition: SettingsSceneCameraPosition? = .back
    var rtmpCameraId: UUID? = .init()
    var externalCameraId: String? = ""
    var externalCameraName: String? = ""
    var cameraLayoutPip: SettingsSceneCameraLayoutPip? = .init()
    var widgets: [SettingsSceneWidget] = []
    var buttons: [SettingsSceneButton] = []

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsScene, rhs: SettingsScene) -> Bool {
        return lhs.id == rhs.id
    }

    func addButton(id: UUID) {
        buttons.append(SettingsSceneButton(buttonId: id))
    }

    func clone() -> SettingsScene {
        let new = SettingsScene(name: name)
        new.enabled = enabled
        new.cameraLayout = cameraLayout
        new.cameraType = cameraType
        new.cameraPosition = cameraPosition
        new.rtmpCameraId = rtmpCameraId
        new.cameraLayoutPip = cameraLayoutPip!.clone()
        for widget in widgets {
            new.widgets.append(widget.clone())
        }
        for button in buttons {
            new.buttons.append(button.clone())
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
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case widget = "Widget"
    case mic = "Mic"
    case chat = "Chat"
    case pauseChat = "Pause chat"
    case blackScreen = "Black screen"
    case obsScene = "OBS scene"
    case obsStartStopStream = "OBS start/stop stream"
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

    static func fromString(value: String) -> SettingsButtonType {
        switch value {
        case String(localized: "Torch"):
            return .torch
        case String(localized: "Mute"):
            return .mute
        case String(localized: "Bitrate"):
            return .bitrate
        case String(localized: "Widget"):
            return .widget
        case String(localized: "Mic"):
            return .mic
        case String(localized: "Chat"):
            return .chat
        case String(localized: "Pause chat"):
            return .pauseChat
        case String(localized: "Black screen"):
            return .blackScreen
        case String(localized: "OBS scene"):
            return .obsScene
        case String(localized: "OBS start/stop stream"):
            return .obsStartStopStream
        case String(localized: "Record"):
            return .record
        case String(localized: "Recordings"):
            return .recordings
        case String(localized: "Image"):
            return .image
        case String(localized: "Movie"):
            return .movie
        case String(localized: "Gray scale"):
            return .grayScale
        case String(localized: "Sepia"):
            return .sepia
        case String(localized: "Random"):
            return .random
        case String(localized: "Triple"):
            return .triple
        case String(localized: "Pixellate"):
            return .pixellate
        case String(localized: "Stream"):
            return .stream
        case String(localized: "Grid"):
            return .grid
        case String(localized: "OBS"):
            return .obs
        case String(localized: "Remote"):
            return .remote
        case String(localized: "Draw"):
            return .draw
        case String(localized: "Local overlays"):
            return .localOverlays
        default:
            return .torch
        }
    }

    func toString() -> String {
        switch self {
        case .torch:
            return String(localized: "Torch")
        case .mute:
            return String(localized: "Mute")
        case .bitrate:
            return String(localized: "Bitrate")
        case .widget:
            return String(localized: "Widget")
        case .mic:
            return String(localized: "Mic")
        case .chat:
            return String(localized: "Chat")
        case .pauseChat:
            return String(localized: "Pause chat")
        case .blackScreen:
            return String(localized: "Black screen")
        case .obsScene:
            return String(localized: "OBS scene")
        case .obsStartStopStream:
            return String(localized: "OBS start/stop stream")
        case .record:
            return String(localized: "Record")
        case .recordings:
            return String(localized: "Recordings")
        case .image:
            return String(localized: "Image")
        case .movie:
            return String(localized: "Movie")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .random:
            return String(localized: "Random")
        case .triple:
            return String(localized: "Triple")
        case .pixellate:
            return String(localized: "Pixellate")
        case .stream:
            return String(localized: "Stream")
        case .grid:
            return String(localized: "Grid")
        case .obs:
            return String(localized: "OBS")
        case .remote:
            return String(localized: "Remote")
        case .draw:
            return String(localized: "Draw")
        case .localOverlays:
            return String(localized: "Local overlays")
        }
    }
}

let buttonTypes = ["Widget"]

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
    var widget: SettingsButtonWidget = .init(widgetId: UUID())
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

enum SettingsColorAppleLogLutType: Codable {
    case bundled
    case disk
}

class SettingsColorAppleLogLut: Codable, Identifiable {
    var id: UUID = .init()
    var type: SettingsColorAppleLogLutType = .bundled
    var name: String = ""

    init(type: SettingsColorAppleLogLutType, name: String) {
        self.type = type
        self.name = name
    }
}

enum SettingsColorSpace: String, Codable, CaseIterable {
    case srgb = "Standard RGB"
    case p3D65 = "P3 D65"
    case hlgBt2020 = "HLG BT2020"
    case appleLog = "Apple Log"
}

let colorSpaces = SettingsColorSpace.allCases.map { $0.rawValue }

class SettingsColor: Codable {
    var space: SettingsColorSpace = .srgb
    var lutEnabled: Bool = false
    var lut: UUID = .init()
    var bundledLuts = [
        SettingsColorAppleLogLut(type: .bundled, name: "Neutral"),
        SettingsColorAppleLogLut(type: .bundled, name: "Apple Log To Rec 709"),
        SettingsColorAppleLogLut(type: .bundled, name: "Moblin Meme"),
    ]
    var diskLuts: [SettingsColorAppleLogLut]? = []
}

class SettingsShow: Codable {
    var chat: Bool = true
    var viewers: Bool = true
    var uptime: Bool = true
    var stream: Bool = true
    var speed: Bool = true
    var audioLevel: Bool = true
    var zoom: Bool = true
    var zoomPresets: Bool = true
    var microphone: Bool = true
    var audioBar: Bool = true
    var cameras: Bool? = true
    var obsStatus: Bool? = true
    var rtmpSpeed: Bool? = true
    var gameController: Bool? = true
    var location: Bool? = true
    var remoteControl: Bool? = true
    var browserWidgets: Bool? = true
}

class SettingsZoomPreset: Codable, Identifiable {
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
}

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
}

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"
}

let logLevels = SettingsLogLevel.allCases.map { $0.rawValue }

class SettingsDebugAudioOutputToInputChannelsMap: Codable {
    var channel0: Int = 0
    var channel1: Int = 1
}

class SettingsDebug: Codable {
    var logLevel: SettingsLogLevel = .error
    var srtOverlay: Bool = false
    var srtOverheadBandwidth: Int32? = 25
    var letItSnow: Bool? = false
    var sceneMic: Bool? = false
    var recordingsFolder: Bool? = false
    var cameraSwitchRemoveBlackish: Float? = 0.3
    var maximumBandwidthFollowInput: Bool? = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap? = .init()
    var bluetoothOutputOnly: Bool? = false
    var maximumLogLines: Int? = 500
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
    case pauseChat = "Pause chat"
    case scene = "Scene"

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
        case String(localized: "Pause chat"):
            return .pauseChat
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
        case .pauseChat:
            return String(localized: "Pause chat")
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
        button.function = .pauseChat
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
        button.function = .pauseChat
        buttons.append(button)
    }
}

class SettingsRemoteControlClient: Codable {
    var enabled: Bool = false
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

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    // periphery:ignore
    var variables: [SettingsVariable]? = []
    var buttons: [SettingsButton] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    var tapToFocus: Bool = false
    var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var backCameraId: String? = ""
    var frontCameraId: String? = ""
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var batteryPercentage: Bool? = true
    var mic: SettingsMic? = .bottom
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
    var mirrorFrontCameraOnStream: Bool? = false
    var streamButtonBackgroundColor: RgbColor? = defaultStreamButtonBackgroundColor
    var streamButtonForegroundColor: RgbColor? = defaultStreamButtonForegroundColor

    static func fromString(settings: String) throws -> Database {
        let database = try JSONDecoder().decode(
            Database.self,
            from: settings.data(using: .utf8)!
        )
        for button in database.buttons {
            button.isOn = false
        }
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
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}

private func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.cameraPosition = .back
    database.scenes.append(scene)

    scene = SettingsScene(name: String(localized: "Front"))
    scene.cameraPosition = .front
    database.scenes.append(scene)
}

private func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

private func addDefaultBackZoomPresets(database: Database) {
    if let device = getBestBackCameraDevice() {
        let hasUltraWideCamera = hasUltraWideCamera()
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

    button = SettingsButton(name: String(localized: "Pause chat"))
    button.id = UUID()
    button.type = .pauseChat
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
    button.enabled = false
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

    button = SettingsButton(name: String(localized: "Grid"))
    button.id = UUID()
    button.type = .grid
    button.imageType = "System name"
    button.systemImageNameOn = "grid"
    button.systemImageNameOff = "grid"
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
}

private func addScenesToGameController(database: Database) {
    var button = database.gameControllers![0].buttons[0]
    button.function = .scene
    button.sceneId = database.scenes[0].id
    button = database.gameControllers![0].buttons[1]
    button.function = .scene
    button.sceneId = database.scenes[1].id
}

private func createDefault() -> Database {
    let database = Database()
    database.backCameraId = getBestBackCameraId()
    database.frontCameraId = getBestFrontCameraId()
    addDefaultScenes(database: database)
    addDefaultZoomPresets(database: database)
    addDefaultBitratePresets(database: database)
    addMissingGlobalButtons(database: database)
    addScenesToGameController(database: database)
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
        for stream in realDatabase.streams where stream.youTubeApiKey == nil {
            stream.youTubeApiKey = ""
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
            realDatabase.mic = .bottom
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
        for scene in realDatabase.scenes where scene.cameraLayout == nil {
            scene.cameraLayout = .single
            store()
        }
        for scene in realDatabase.scenes where scene.cameraLayoutPip == nil {
            scene.cameraLayoutPip = .init()
            store()
        }
        for stream in realDatabase.streams where stream.maxKeyFrameInterval == nil {
            stream.maxKeyFrameInterval = 2
            store()
        }
        if realDatabase.backCameraId == nil {
            realDatabase.backCameraId = getBestBackCameraId()
            store()
        }
        if realDatabase.frontCameraId == nil {
            realDatabase.frontCameraId = ""
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
            realDatabase.show.cameras = true
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
        var bloomButtons: [SettingsButton] = []
        for button in realDatabase.buttons where button.type == .widget {
            if bloomWidgets.contains(where: { widget in
                widget.id == button.widget.widgetId
            }) {
                bloomButtons.append(button)
            }
        }
        if !bloomButtons.isEmpty {
            realDatabase.buttons = realDatabase.buttons.filter { button in
                !bloomButtons.contains(button)
            }
            for scene in realDatabase.scenes {
                scene.buttons = scene.buttons.filter { button in
                    !bloomButtons.contains { bloomButton in
                        bloomButton.id == button.buttonId
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
        for button in realDatabase.buttons where button.enabled == nil {
            button.enabled = true
            store()
        }
        var nonWidgetButtons: [SettingsButton] = []
        for button in realDatabase.buttons where button.type != .widget {
            nonWidgetButtons.append(button)
        }
        if !nonWidgetButtons.isEmpty {
            realDatabase.buttons = realDatabase.buttons.filter { button in
                button.type == .widget
            }
            for scene in realDatabase.scenes {
                scene.buttons = scene.buttons.filter { button in
                    !nonWidgetButtons.contains { nonWidgetButton in
                        nonWidgetButton.id == button.buttonId
                    }
                }
            }
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
        if realDatabase.debug!.sceneMic == nil {
            realDatabase.debug!.sceneMic = false
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
        for button in realDatabase.globalButtons! where button.type == .obsStartStopStream {
            if button.systemImageNameOn != "wifi.router" {
                button.systemImageNameOn = "wifi.router"
                store()
            }
            if button.systemImageNameOff != "wifi.router" {
                button.systemImageNameOff = "wifi.router"
                store()
            }
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
        let numberOfButtons = realDatabase.globalButtons!.count
        realDatabase.globalButtons = realDatabase.globalButtons!.filter { button in
            button.type != .obsScene && button.type != .obsStartStopStream
        }
        if realDatabase.globalButtons!.count != numberOfButtons {
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
        for button in realDatabase.buttons where button.backgroundColor == nil {
            button.backgroundColor = defaultQuickButtonColor
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
        if realDatabase.mirrorFrontCameraOnStream == nil {
            realDatabase.mirrorFrontCameraOnStream = false
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
        if realDatabase.streamButtonBackgroundColor == nil {
            realDatabase.streamButtonBackgroundColor = defaultStreamButtonBackgroundColor
            store()
        }
        if realDatabase.streamButtonForegroundColor == nil {
            realDatabase.streamButtonForegroundColor = defaultStreamButtonForegroundColor
            store()
        }
    }
}
