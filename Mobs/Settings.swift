import SwiftUI

var codecs = ["H.265/HEVC", "H.264/AVC"]

enum SettingsStreamCodec: String, Codable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"
}

var resolutions = ["1920x1080", "1280x720", "854x480", "640x360", "426x240"]

enum SettingsStreamResolution: String, Codable {
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"
}

var fpss = [60, 30, 15, 5]

let bitrates: [UInt32] = [
    40_000_000,
    25_000_000,
    15_000_000,
    10_000_000,
    7_500_000,
    5_000_000,
    3_000_000,
    2_000_000,
    1_500_000,
    1_000_000,
    750_000,
    500_000,
    350_000,
    250_000,
]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
}

class SettingsStream: Codable, Identifiable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    var url: String? = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    var rtmpUrl: String = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    var srtUrl: String = "srt://platform.com:5000"
    var srtla: Bool = false
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var kickChannelId: String? = ""
    var kickChatroomId: String? = ""
    var resolution: SettingsStreamResolution = .r1280x720
    var fps: Int = 30
    var bitrate: UInt32 = 3_000_000
    var codec: SettingsStreamCodec = .h264avc

    init(name: String) {
        self.name = name
    }

    func getProtocol() -> SettingsStreamProtocol {
        switch URL(string: url!)!.scheme {
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
        switch URL(string: url!)!.scheme {
        case "rtmps":
            return true
        default:
            return false
        }
    }

    func isSrtla() -> Bool {
        switch URL(string: url!)!.scheme {
        case "srtla":
            return true
        default:
            return false
        }
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
}

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = true
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
}

class SettingsWidgetText: Codable {
    var formatString: String = "Sub goal: {subs} / 10"
}

class SettingsWidgetImage: Codable {
    var url: String = "https://"
}

class SettingsWidgetVideo: Codable {
    var url: String = "https://"
}

var cameraTypes = ["Main", "Front"]

enum SettingsWidgetCameraType: String, Codable {
    case main = "Main"
    case front = "Front"
}

class SettingsWidgetCamera: Codable {
    var type: SettingsWidgetCameraType = .main
}

class SettingsWidgetChat: Codable {}

class SettingsWidgetRecording: Codable {}

class SettingsWidgetWebview: Codable {
    var url: String = "https://"
}

var videoEffects = ["Movie", "Gray scale", "Seipa", "Bloom"]

enum SettingsWidgetVideoEffectType: String, Codable {
    case movie = "Movie"
    case grayScale = "Gray scale"
    case seipa = "Seipa"
    case bloom = "Bloom"
}

class SettingsWidgetVideoEffect: Codable {
    var type: SettingsWidgetVideoEffectType = .movie
}

let widgetTypes = ["Camera", "Image", "Video effect"]

enum SettingsWidgetType: String, Codable {
    case camera = "Camera"
    case image = "Image"
    case videoEffect = "Video effect"
}

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .camera
    var text: SettingsWidgetText = .init()
    var image: SettingsWidgetImage = .init()
    var video: SettingsWidgetVideo = .init()
    var camera: SettingsWidgetCamera = .init()
    var chat: SettingsWidgetChat = .init()
    var recording: SettingsWidgetRecording = .init()
    var webview: SettingsWidgetWebview = .init()
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

var buttonTypes = ["Torch", "Mute", "Bitrate", "Widget"]

enum SettingsButtonType: String, Codable {
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case widget = "Widget"
}

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
    var audioLevel: Bool? = true
}

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var buttons: [SettingsButton] = []
    var show: SettingsShow = .init()
}

func addDefaultWidgets(database: Database) {
    var widget = SettingsWidget(name: "Main camera")
    widget.type = .camera
    widget.camera.type = .main
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Front camera")
    widget.type = .camera
    widget.camera.type = .front
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Movie")
    widget.type = .videoEffect
    widget.videoEffect.type = .movie
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Gray scale")
    widget.type = .videoEffect
    widget.videoEffect.type = .grayScale
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Seipa")
    widget.type = .videoEffect
    widget.videoEffect.type = .seipa
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Bloom")
    widget.type = .videoEffect
    widget.videoEffect.type = .bloom
    database.widgets.append(widget)
}

func createSceneWidgetMainCamera(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[0].id)
}

func createSceneWidgetFrontCameraFull(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[1].id)
}

func createSceneWidgetVideoEffectMovie(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[2].id)
}

func createSceneWidgetVideoEffectGrayScale(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[3].id)
}

func createSceneWidgetVideoEffectSeipa(database: Database) -> SettingsSceneWidget {
    return SettingsSceneWidget(widgetId: database.widgets[4].id)
}

func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: "Main")
    scene.widgets.append(createSceneWidgetMainCamera(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectGrayScale(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectSeipa(database: database))
    scene.addButton(id: database.buttons[0].id)
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[3].id)
    scene.addButton(id: database.buttons[4].id)
    scene.addButton(id: database.buttons[5].id)
    database.scenes.append(scene)

    scene = SettingsScene(name: "Front")
    scene.widgets.append(createSceneWidgetFrontCameraFull(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[3].id)
    database.scenes.append(scene)
}

func addDefaultStreams(database: Database) {
    let stream = SettingsStream(name: "Twitch")
    stream.enabled = true
    stream.url = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    stream.twitchChannelName = ""
    stream.twitchChannelId = ""
    stream.kickChatroomId = ""
    database.streams.append(stream)
}

func addDefaultButtons(database: Database) {
    var button = SettingsButton(name: "Torch")
    button.id = UUID()
    button.type = .torch
    button.imageType = "System name"
    button.systemImageNameOn = "lightbulb.fill"
    button.systemImageNameOff = "lightbulb"
    database.buttons.append(button)

    button = SettingsButton(name: "Mute")
    button.id = UUID()
    button.type = .mute
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    database.buttons.append(button)

    button = SettingsButton(name: "Bitrate")
    button.id = UUID()
    button.type = .bitrate
    button.imageType = "System name"
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    database.buttons.append(button)

    button = SettingsButton(name: "Movie")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    button.widget.widgetId = database.widgets[2].id
    database.buttons.append(button)

    button = SettingsButton(name: "Gray scale")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    button.widget.widgetId = database.widgets[3].id
    database.buttons.append(button)

    button = SettingsButton(name: "Seipa")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent"
    button.systemImageNameOff = "moonphase.waning.crescent"
    button.widget.widgetId = database.widgets[4].id
    database.buttons.append(button)

    button = SettingsButton(name: "Bloom")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "drop.fill"
    button.systemImageNameOff = "drop"
    button.widget.widgetId = database.widgets[5].id
    database.buttons.append(button)
}

func createDefault() -> Database {
    let database = Database()
    addDefaultWidgets(database: database)
    addDefaultButtons(database: database)
    addDefaultScenes(database: database)
    addDefaultStreams(database: database)
    return database
}

final class Settings {
    var database = Database()
    @AppStorage("settings") var storage = ""

    func load() {
        do {
            database = try JSONDecoder().decode(
                Database.self,
                from: storage.data(using: .utf8)!
            )
            for button in database.buttons {
                button.isOn = false
            }
            if database.streams.isEmpty {
                addDefaultStreams(database: database)
            }
            if database.show.audioLevel == nil {
                database.show.audioLevel = true
            }
        } catch {
            logger.info("settings: Failed to load. Using default.")
            database = createDefault()
        }
    }

    func store() {
        do {
            storage = try String(decoding: JSONEncoder().encode(database), as: UTF8.self)
        } catch {
            logger.error("settings: Failed to store.")
        }
    }

    func reset() {
        database = createDefault()
        store()
    }
}
