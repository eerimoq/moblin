import SwiftUI

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

let fpss = [60, 30, 15, 5]

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
}

class SettingsStream: Codable, Identifiable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    var url: String = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var kickChatroomId: String = ""
    var resolution: SettingsStreamResolution = .r1280x720
    var fps: Int = 30
    var bitrate: UInt32 = 3_000_000
    var codec: SettingsStreamCodec = .h264avc
    var adaptiveBitrate: Bool? = false

    init(name: String) {
        self.name = name
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

enum SettingsSceneCameraType: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"
}

var cameraTypes = SettingsSceneCameraType.allCases.map { $0.rawValue }

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var enabled: Bool = true
    var cameraType: SettingsSceneCameraType? = .back
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
    var formatString: String = "{time}"
}

class SettingsWidgetImage: Codable {
    var url: String = "https://"
}

class SettingsWidgetVideo: Codable {
    var url: String = "https://"
}

enum SettingsWidgetCameraType: String, Codable, CaseIterable {
    case main = "Main"
    case back = "Back"
    case front = "Front"
}

class SettingsWidgetCamera: Codable {
    var type: SettingsWidgetCameraType = .main
}

class SettingsWidgetChat: Codable {}

class SettingsWidgetRecording: Codable {}

class SettingsWidgetWebPage: Codable {
    var url: String = "https://google.com"
}

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
    // Deprecated
    case seipa = "Seipa"
}

let videoEffects = SettingsWidgetVideoEffectType.allCases.filter { effect in
    effect != .seipa
}.map { $0.rawValue }

class SettingsWidgetVideoEffect: Codable {
    var type: SettingsWidgetVideoEffectType = .movie
    var noiseReductionNoiseLevel: Float? = 0.01
    var noiseReductionSharpness: Float? = 1.5
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case camera = "Camera"
    case videoEffect = "Video effect"
    case image = "Image"
    case webPage = "Web page"
    case browser = "Browser"
    case time = "Time"
}

let widgetTypes = SettingsWidgetType.allCases.filter { widgetType in
    widgetType != .camera && widgetType != .webPage
}.map { $0.rawValue }

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = .init()
    var type: SettingsWidgetType = .videoEffect
    var text: SettingsWidgetText = .init()
    var image: SettingsWidgetImage = .init()
    var video: SettingsWidgetVideo = .init()
    var camera: SettingsWidgetCamera = .init()
    var chat: SettingsWidgetChat = .init()
    var recording: SettingsWidgetRecording = .init()
    var webPage: SettingsWidgetWebPage? = .init()
    var browser: SettingsWidgetBrowser? = .init()
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
    case microphone = "Microphone"
    case mic = "Mic"
}

let buttonTypes = SettingsButtonType.allCases.filter { button in
    button != .microphone
}.map { $0.rawValue }

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
    var zoom: Bool? = true
    var zoomPresets: Bool? = true
    var microphone: Bool? = true
}

class SettingsZoomPreset: Codable, Identifiable {
    var id: UUID
    var name: String = ""
    var level: Float = 1.0

    init(id: UUID, name: String, level: Float) {
        self.id = id
        self.name = name
        self.level = level
    }
}

class SettingsZoomSwitchTo: Codable {
    var level: Float = 1.0
    var enabled: Bool = false
}

class SettingsZoom: Codable {
    var back: [SettingsZoomPreset] = []
    var front: [SettingsZoomPreset] = []
    var switchToBack: SettingsZoomSwitchTo? = .init()
    var switchToFront: SettingsZoomSwitchTo? = .init()
}

class SettingsBitratePreset: Codable, Identifiable {
    var id: UUID
    var bitrate: UInt32 = 3_000_000

    init(id: UUID, bitrate: UInt32) {
        self.id = id
        self.bitrate = bitrate
    }
}

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var buttons: [SettingsButton] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom? = .init()
    var tapToFocus: Bool? = false
    var bitratePresets: [SettingsBitratePreset]? = []
    var iconImage: String? = plainIcon.image
    var maximumScreenFpsEnabled: Bool? = false
    var maximumScreenFps: Int? = 60

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
        if database.zoom == nil {
            database.zoom = SettingsZoom()
        }
        if database.zoom!.back.isEmpty {
            addDefaultBackZoomPresets(database: database)
        }
        if database.zoom!.front.isEmpty {
            addDefaultFrontZoomPresets(database: database)
        }
        if database.bitratePresets == nil {
            addDefaultBitratePresets(database: database)
        }
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}

func addDefaultWidgets(database: Database) {
    var widget = SettingsWidget(name: "Movie")
    widget.type = .videoEffect
    widget.videoEffect.type = .movie
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Gray scale")
    widget.type = .videoEffect
    widget.videoEffect.type = .grayScale
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Sepia")
    widget.type = .videoEffect
    widget.videoEffect.type = .sepia
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Bloom")
    widget.type = .videoEffect
    widget.videoEffect.type = .bloom
    database.widgets.append(widget)

    widget = SettingsWidget(name: "Random")
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
    return SettingsSceneWidget(widgetId: database.widgets[4].id)
}

func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: "Back")
    scene.cameraType = .back
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectGrayScale(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectSepia(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectRandom(database: database))
    scene.addButton(id: database.buttons[0].id)
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[8].id)
    scene.addButton(id: database.buttons[3].id)
    scene.addButton(id: database.buttons[4].id)
    scene.addButton(id: database.buttons[5].id)
    scene.addButton(id: database.buttons[7].id)
    database.scenes.append(scene)

    scene = SettingsScene(name: "Front")
    scene.cameraType = .front
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    scene.addButton(id: database.buttons[1].id)
    scene.addButton(id: database.buttons[2].id)
    scene.addButton(id: database.buttons[8].id)
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

func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

func addDefaultBackZoomPresets(database: Database) {
    database.zoom!.back = [
        SettingsZoomPreset(id: UUID(), name: "0.5x", level: 1.0),
        SettingsZoomPreset(id: UUID(), name: "1x", level: 2.0),
        SettingsZoomPreset(id: UUID(), name: "2x", level: 4.0),
        SettingsZoomPreset(id: UUID(), name: "4x", level: 8.0),
        SettingsZoomPreset(id: UUID(), name: "8x", level: 16.0),
    ]
}

func addDefaultFrontZoomPresets(database: Database) {
    database.zoom!.front = [
        SettingsZoomPreset(id: UUID(), name: "1x", level: 1.0),
        SettingsZoomPreset(id: UUID(), name: "2x", level: 2.0),
        SettingsZoomPreset(id: UUID(), name: "4x", level: 4.0),
        SettingsZoomPreset(id: UUID(), name: "8x", level: 8.0),
    ]
}

func addDefaultBitratePresets(database: Database) {
    database.bitratePresets = [
        SettingsBitratePreset(id: UUID(), bitrate: 15_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 10_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 500_000),
        SettingsBitratePreset(id: UUID(), bitrate: 250_000),
    ]
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
    button.widget.widgetId = database.widgets[0].id
    database.buttons.append(button)

    button = SettingsButton(name: "Gray scale")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    button.widget.widgetId = database.widgets[1].id
    database.buttons.append(button)

    button = SettingsButton(name: "Sepia")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "moonphase.waxing.crescent"
    button.systemImageNameOff = "moonphase.waning.crescent"
    button.widget.widgetId = database.widgets[2].id
    database.buttons.append(button)

    button = SettingsButton(name: "Bloom")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "drop.fill"
    button.systemImageNameOff = "drop"
    button.widget.widgetId = database.widgets[3].id
    database.buttons.append(button)

    button = SettingsButton(name: "Random")
    button.id = UUID()
    button.type = .widget
    button.imageType = "System name"
    button.systemImageNameOn = "dice.fill"
    button.systemImageNameOff = "dice"
    button.widget.widgetId = database.widgets[4].id
    database.buttons.append(button)

    button = SettingsButton(name: "Mic")
    button.id = UUID()
    button.type = .microphone
    button.imageType = "System name"
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    database.buttons.append(button)
}

func createDefault() -> Database {
    let database = Database()
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
            return "Empty clipboard"
        }
        guard let settings = settings.data(using: .utf8) else {
            return "Non-string clipboard"
        }
        guard let settings = Data(base64Encoded: settings) else {
            return "Not base64 encoded"
        }
        guard let settings = String(data: settings, encoding: .utf8) else {
            return "Non-string in base64"
        }
        do {
            try tryLoadAndMigrate(settings: settings)
        } catch {
            return "Malformed settings"
        }
        store()
        return nil
    }

    func exportToClipboard() -> String? {
        guard let settings = storage.data(using: .utf8) else {
            return "Failed to read settings"
        }
        UIPasteboard.general.string = settings.base64EncodedString()
        return nil
    }

    private func migrateFromOlderVersions() {
        if realDatabase.show.audioLevel == nil {
            realDatabase.show.audioLevel = true
            store()
        }
        if realDatabase.show.microphone == nil {
            realDatabase.show.microphone = true
            store()
        }
        if realDatabase.show.zoom == nil {
            realDatabase.show.zoom = true
            store()
        }
        if realDatabase.show.zoomPresets == nil {
            realDatabase.show.zoomPresets = realDatabase.show.zoom
            store()
        }
        for widget in realDatabase.widgets {
            if widget.type != .videoEffect {
                continue
            }
            if widget.videoEffect.type != .seipa {
                continue
            }
            widget.videoEffect.type = .sepia
            store()
        }
        for widget in realDatabase.widgets {
            if widget.videoEffect.noiseReductionNoiseLevel == nil {
                widget.videoEffect.noiseReductionNoiseLevel = 0.01
                store()
            }
            if widget.videoEffect.noiseReductionSharpness == nil {
                widget.videoEffect.noiseReductionSharpness = 1.5
                store()
            }
        }
        for widget in realDatabase.widgets {
            if widget.type != .camera {
                continue
            }
            if widget.camera.type == .main {
                widget.camera.type = .back
                store()
            }
        }
        for scene in realDatabase.scenes where scene.cameraType == nil {
            var sceneWidgetIndexesToRemove: IndexSet = .init()
            for (index, widget) in scene.widgets.enumerated() {
                for realWidget in database.widgets
                    where widget.widgetId == realWidget.id
                {
                    if realWidget.type == .camera {
                        switch realWidget.camera.type {
                        case .back:
                            scene.cameraType = .back
                        case .main:
                            scene.cameraType = .back
                        case .front:
                            scene.cameraType = .front
                        }
                        sceneWidgetIndexesToRemove.insert(index)
                    }
                }
            }
            if scene.cameraType == nil {
                scene.cameraType = .back
            }
            scene.widgets.remove(atOffsets: sceneWidgetIndexesToRemove)
            store()
        }
        let widgets = database.widgets.filter { widget in
            widget.type != .camera
        }
        if database.widgets.count != widgets.count {
            database.widgets = widgets
            store()
        }
        for widget in realDatabase.widgets {
            if widget.webPage != nil {
                continue
            }
            widget.webPage = .init()
            store()
        }
        for widget in realDatabase.widgets {
            if widget.browser != nil {
                continue
            }
            widget.browser = .init()
            store()
        }
        for widget in realDatabase.widgets {
            if widget.type != .webPage {
                continue
            }
            widget.type = .browser
            widget.browser!.url = widget.webPage!.url
            store()
        }
        for button in realDatabase.buttons {
            if button.type != .microphone {
                continue
            }
            button.type = .mic
            store()
        }
        if database.tapToFocus == nil {
            database.tapToFocus = false
            store()
        }
        for stream in database.streams where stream.adaptiveBitrate == nil {
            stream.adaptiveBitrate = false
            store()
        }
        if database.iconImage == nil {
            database.iconImage = plainIcon.image
            store()
        }
        if database.zoom!.switchToBack == nil {
            database.zoom!.switchToBack = .init()
            store()
        }
        if database.zoom!.switchToFront == nil {
            database.zoom!.switchToFront = .init()
            store()
        }
        if database.maximumScreenFpsEnabled == nil {
            database.maximumScreenFpsEnabled = false
            store()
        }
        if database.maximumScreenFps == nil {
            database.maximumScreenFps = 60
            store()
        }
    }
}
