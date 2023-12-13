import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"

enum SettingsStreamCodec: String, Codable, CaseIterable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"
}

let codecs = SettingsStreamCodec.allCases.map { $0.rawValue }

enum SettingsStreamResolution: String, Codable, CaseIterable {
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"
}

let resolutions = SettingsStreamResolution.allCases.map { $0.rawValue }

let fpss = ["60", "30", "15", "5"]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = 2000
    var mpegtsPacketsPerPacket: Int = 7

    func clone() -> SettingsStreamSrt {
        let srt = SettingsStreamSrt()
        srt.latency = latency
        srt.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        return srt
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

let captureSessionPresets = SettingsCaptureSessionPreset.allCases.map { $0.rawValue }

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
    var kickChatroomId: String = ""
    var youTubeApiKey: String? = ""
    var youTubeVideoId: String? = ""
    var afreecaTvChannelName: String? = ""
    var afreecaTvStreamId: String? = ""
    var obsWebSocketUrl: String? = ""
    var obsWebSocketPassword: String? = ""
    var resolution: SettingsStreamResolution = .r1920x1080
    var fps: Int = 30
    var bitrate: UInt32 = 3_000_000
    var codec: SettingsStreamCodec = .h265hevc
    var adaptiveBitrate: Bool = false
    var srt: SettingsStreamSrt = .init()
    var captureSessionPresetEnabled: Bool = false
    var captureSessionPreset: SettingsCaptureSessionPreset = .medium
    var maxKeyFrameInterval: Int32? = 2

    init(name: String) {
        self.name = name
    }

    func clone() -> SettingsStream {
        let scene = SettingsStream(name: name)
        scene.url = url
        scene.twitchChannelName = twitchChannelName
        scene.twitchChannelId = twitchChannelId
        scene.kickChatroomId = kickChatroomId
        scene.youTubeApiKey = youTubeApiKey
        scene.youTubeVideoId = youTubeVideoId
        scene.afreecaTvChannelName = afreecaTvChannelName
        scene.afreecaTvStreamId = afreecaTvStreamId
        scene.obsWebSocketUrl = obsWebSocketUrl
        scene.obsWebSocketPassword = obsWebSocketPassword
        scene.resolution = resolution
        scene.fps = fps
        scene.bitrate = bitrate
        scene.codec = codec
        scene.adaptiveBitrate = adaptiveBitrate
        scene.srt = srt.clone()
        scene.captureSessionPresetEnabled = captureSessionPresetEnabled
        scene.captureSessionPreset = captureSessionPreset
        scene.maxKeyFrameInterval = maxKeyFrameInterval
        return scene
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

    func isRtmps() -> Bool {
        return getScheme() == "rtmps"
    }

    func isSrtla() -> Bool {
        return getScheme() == "srtla"
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
        let widget = SettingsSceneWidget(widgetId: widgetId)
        widget.enabled = enabled
        widget.x = x
        widget.y = y
        widget.width = width
        widget.height = height
        return widget
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
        let button = SettingsSceneButton(buttonId: buttonId)
        button.enabled = enabled
        return button
    }
}

enum SettingsSceneCameraPosition: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"

    static func fromString(value: String) -> SettingsSceneCameraPosition {
        switch value {
        case String(localized: "Back"):
            return .back
        case String(localized: "Front"):
            return .front
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
        }
    }
}

var cameraPositions = SettingsSceneCameraPosition.allCases.map { $0.toString() }

enum SettingsCameraType: String, Codable, CaseIterable {
    case triple = "Triple"
    case dual = "Dual"
    case dualWide = "Dual Wide"
    case wide = "Wide"
    case ultraWide = "Ultra Wide"
    case telephoto = "Telephoto"
}

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
        let layout = SettingsSceneCameraLayoutPip()
        layout.x = x
        layout.y = y
        layout.width = width
        layout.height = height
        return layout
    }
}

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = true
    var cameraLayout: SettingsSceneCameraLayout? = .single
    var cameraType: SettingsSceneCameraPosition = .back
    var cameraPosition: SettingsSceneCameraPosition? = .back
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
        let scene = SettingsScene(name: name)
        scene.enabled = enabled
        scene.cameraLayout = cameraLayout
        scene.cameraType = cameraType
        scene.cameraPosition = cameraPosition
        scene.cameraLayoutPip = cameraLayoutPip!.clone()
        for widget in widgets {
            scene.widgets.append(widget.clone())
        }
        for button in buttons {
            scene.buttons.append(button.clone())
        }
        return scene
    }
}

class SettingsWidgetText: Codable {
    var formatString: String = "{time}"
}

class SettingsWidgetImage: Codable {
    var url: String = "https://"
}

class SettingsWidgetVideo: Codable {
    var url: String = "https://"
}

class SettingsWidgetChat: Codable {}

class SettingsWidgetRecording: Codable {}

class SettingsWidgetBrowser: Codable {
    var url: String = "https://google.com"
    var width: Int = 500
    var height: Int = 500
    var customCss: String =
        "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }"
}

enum SettingsWidgetVideoEffectType: String, Codable, CaseIterable {
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case bloom = "Bloom"
    case random = "Random"
    case triple = "Triple"
    case noiseReduction = "Noise reduction"

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
        }
    }
}

let videoEffects = SettingsWidgetVideoEffectType.allCases.filter { effect in
    effect != .bloom
}.map { $0.toString() }

class SettingsWidgetVideoEffect: Codable {
    var type: SettingsWidgetVideoEffectType = .movie
    var noiseReductionNoiseLevel: Float = 0.01
    var noiseReductionSharpness: Float = 1.5
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case videoEffect = "Video effect"
    case image = "Image"
    case browser = "Browser"
    case time = "Time"

    static func fromString(value: String) -> SettingsWidgetType {
        switch value {
        case String(localized: "Video effect"):
            return .videoEffect
        case String(localized: "Image"):
            return .image
        case String(localized: "Browser"):
            return .browser
        case String(localized: "Time"):
            return .time
        default:
            return .videoEffect
        }
    }

    func toString() -> String {
        switch self {
        case .videoEffect:
            return String(localized: "Video effect")
        case .image:
            return String(localized: "Image")
        case .browser:
            return String(localized: "Browser")
        case .time:
            return String(localized: "Time")
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases.map { $0.toString() }

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .videoEffect
    var text: SettingsWidgetText = .init()
    var image: SettingsWidgetImage = .init()
    var video: SettingsWidgetVideo = .init()
    var chat: SettingsWidgetChat = .init()
    var recording: SettingsWidgetRecording = .init()
    var browser: SettingsWidgetBrowser = .init()
    var videoEffect: SettingsWidgetVideoEffect = .init()

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsWidget, rhs: SettingsWidget) -> Bool {
        return lhs.id == rhs.id
    }
}

class SettingsVariableText: Codable {
    var value: String = "15.0"
}

class SettingsVariableHttp: Codable {
    var url: String = "https://"
}

class SettingsVariableTwitchPubSub: Codable {
    var pattern: String = ""
}

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
        }
    }
}

let buttonTypes = SettingsButtonType.allCases.map { $0.toString() }

class SettingsButtonWidget: Codable, Identifiable {
    var widgetId: UUID
    var id: UUID = .init()

    init(widgetId: UUID) {
        self.widgetId = widgetId
    }
}

class SettingsButton: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsButtonType = .torch
    var imageType: String = "System name"
    var systemImageNameOn: String = "mic.slash"
    var systemImageNameOff: String = "mic"
    var widget: SettingsButtonWidget = .init(widgetId: UUID())
    var isOn: Bool = false

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsButton, rhs: SettingsButton) -> Bool {
        return lhs.id == rhs.id
    }
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
    var bitrate: UInt32 = 3_000_000

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
    var alignedMessages: Bool = false
    var boldUsername: Bool = false
    var boldMessage: Bool = false
    var animatedEmotes: Bool = false
    var timestampColor: RgbColor = .init(red: 180, green: 180, blue: 180)
    var timestampColorEnabled: Bool = true
    var height: Double? = 1.0
    var width: Double? = 1.0
    var maximumAge: Int? = 30
    var maximumAgeEnabled: Bool? = false
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

class SettingsDebug: Codable {
    var logLevel: SettingsLogLevel = .error
    var srtOverlay: Bool = false
    var srtOverheadBandwidth: Int32? = 25
}

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var buttons: [SettingsButton] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    var tapToFocus: Bool = false
    var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var maximumScreenFpsEnabled: Bool = false
    var maximumScreenFps: Int = 15
    var backCameraType: SettingsCameraType? = .dual
    var frontCameraType: SettingsCameraType? = .wide
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var batteryPercentage: Bool? = false
    var mic: SettingsMic? = .bottom
    var debug: SettingsDebug? = .init()

    static func fromString(settings: String) throws -> Database {
        let database = try JSONDecoder().decode(
            Database.self,
            from: settings.data(using: .utf8)!
        )
        for button in database.buttons {
            button.isOn = false
        }
        if database.streams.isEmpty {
            addDefaultStreams(database: database)
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
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}

func addDefaultWidgets(database: Database) {
    // 0
    var widget = SettingsWidget(name: String(localized: "Movie"))
    widget.type = .videoEffect
    widget.videoEffect.type = .movie
    database.widgets.append(widget)

    // 1
    widget = SettingsWidget(name: String(localized: "Gray scale"))
    widget.type = .videoEffect
    widget.videoEffect.type = .grayScale
    database.widgets.append(widget)

    // 2
    widget = SettingsWidget(name: String(localized: "Sepia"))
    widget.type = .videoEffect
    widget.videoEffect.type = .sepia
    database.widgets.append(widget)

    // 3
    widget = SettingsWidget(name: String(localized: "Random"))
    widget.type = .videoEffect
    widget.videoEffect.type = .random
    database.widgets.append(widget)
}

func createSceneWidgetVideoEffectMovie(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[0].id)
}

func createSceneWidgetVideoEffectGrayScale(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[1].id)
}

func createSceneWidgetVideoEffectSepia(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[2].id)
}

func createSceneWidgetVideoEffectRandom(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[3].id)
}

func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.cameraPosition = .back
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectGrayScale(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectSepia(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectRandom(database: database))
    scene.addButton(id: database.buttons[0].id)
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[7].id)
    scene.addButton(id: database.buttons[8].id)
    scene.addButton(id: database.buttons[9].id)
    scene.addButton(id: database.buttons[10].id)
    scene.addButton(id: database.buttons[11].id)
    scene.addButton(id: database.buttons[12].id)
    scene.addButton(id: database.buttons[3].id)
    scene.addButton(id: database.buttons[4].id)
    scene.addButton(id: database.buttons[5].id)
    scene.addButton(id: database.buttons[6].id)
    database.scenes.append(scene)

    scene = SettingsScene(name: String(localized: "Front"))
    scene.cameraPosition = .front
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[7].id)
    scene.addButton(id: database.buttons[8].id)
    scene.addButton(id: database.buttons[9].id)
    scene.addButton(id: database.buttons[10].id)
    scene.addButton(id: database.buttons[11].id)
    scene.addButton(id: database.buttons[12].id)
    scene.addButton(id: database.buttons[3].id)
    database.scenes.append(scene)
}

func addDefaultStreams(database: Database) {
    let stream = SettingsStream(name: "Main")
    stream.enabled = true
    stream.url = defaultStreamUrl
    database.streams.append(stream)
}

func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

func addDefaultBackZoomPresets(database: Database) {
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

func addDefaultFrontZoomPresets(database: Database) {
    database.zoom.front = [
        SettingsZoomPreset(id: UUID(), name: "1x", level: 1.0, x: 1.0),
        SettingsZoomPreset(id: UUID(), name: "2x", level: 2.0, x: 2.0),
        SettingsZoomPreset(id: UUID(), name: "4x", level: 4.0, x: 4.0),
        SettingsZoomPreset(id: UUID(), name: "8x", level: 8.0, x: 8.0),
    ]
}

func addDefaultBitratePresets(database: Database) {
    database.bitratePresets = [
        SettingsBitratePreset(id: UUID(), bitrate: 7_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
    ]
}

func addDefaultButtons(database: Database) {
    // 0
    var button = SettingsButton(name: String(localized: "Torch"))
    button.id = UUID()
    button.type = .torch
    button.imageType = "System name"
    button.systemImageNameOn = "lightbulb.fill"
    button.systemImageNameOff = "lightbulb"
    database.buttons.append(button)

    // 1
    button = SettingsButton(name: String(localized: "Mute"))
    button.id = UUID()
    button.type = .mute
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    database.buttons.append(button)

    // 2
    button = SettingsButton(name: String(localized: "Bitrate"))
    button.id = UUID()
    button.type = .bitrate
    button.imageType = "System name"
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    database.buttons.append(button)

    // 3
    button = SettingsButton(name: String(localized: "Movie"))
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    button.widget.widgetId = database.widgets[0].id
    database.buttons.append(button)

    // 4
    button = SettingsButton(name: String(localized: "Gray scale"))
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    button.widget.widgetId = database.widgets[1].id
    database.buttons.append(button)

    // 5
    button = SettingsButton(name: String(localized: "Sepia"))
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent"
    button.systemImageNameOff = "moonphase.waning.crescent"
    button.widget.widgetId = database.widgets[2].id
    database.buttons.append(button)

    // 6
    button = SettingsButton(name: String(localized: "Random"))
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "dice.fill"
    button.systemImageNameOff = "dice"
    button.widget.widgetId = database.widgets[3].id
    database.buttons.append(button)

    // 7
    button = SettingsButton(name: String(localized: "Mic"))
    button.id = UUID()
    button.type = .mic
    button.imageType = "System name"
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    database.buttons.append(button)

    // 8
    button = SettingsButton(name: String(localized: "Chat"))
    button.id = UUID()
    button.type = .chat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    database.buttons.append(button)

    // 9
    button = SettingsButton(name: String(localized: "Pause chat"))
    button.id = UUID()
    button.type = .pauseChat
    button.imageType = "System name"
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    database.buttons.append(button)

    // 10
    button = SettingsButton(name: String(localized: "Black screen"))
    button.id = UUID()
    button.type = .blackScreen
    button.imageType = "System name"
    button.systemImageNameOn = "sunset"
    button.systemImageNameOff = "sunset"
    database.buttons.append(button)

    // 11
    button = SettingsButton(name: String(localized: "OBS scene"))
    button.id = UUID()
    button.type = .obsScene
    button.imageType = "System name"
    button.systemImageNameOn = "photo"
    button.systemImageNameOff = "photo"
    database.buttons.append(button)

    // 12
    button = SettingsButton(name: String(localized: "OBS start/stop stream"))
    button.id = UUID()
    button.type = .obsStartStopStream
    button.imageType = "System name"
    button.systemImageNameOn = "dot.radiowaves.left.and.right"
    button.systemImageNameOff = "dot.radiowaves.left.and.right"
    database.buttons.append(button)
}

func createDefault() -> Database {
    let database = Database()
    database.backCameraType = getBestBackCameraType()
    addDefaultWidgets(database: database)
    addDefaultButtons(database: database)
    addDefaultScenes(database: database)
    addDefaultStreams(database: database)
    addDefaultZoomPresets(database: database)
    addDefaultBitratePresets(database: database)
    return database
}

final class Settings {
    private var realDatabase = Database()
    var database: Database {
        realDatabase
    }

    @AppStorage("settings") var storage = ""

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage)
        } catch {
            logger.info("settings: Failed to load with error \(error). Using default.")
            realDatabase = createDefault()
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
            realDatabase.batteryPercentage = false
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
        if realDatabase.backCameraType == nil {
            realDatabase.backCameraType = getBestBackCameraType()
            store()
        }
        if realDatabase.frontCameraType == nil {
            realDatabase.frontCameraType = .wide
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
    }
}
