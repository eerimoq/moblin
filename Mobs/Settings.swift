import SwiftUI

class SettingsStream: Codable, Identifiable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = false
    var rtmpUrl: String = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    var srtUrl: String = "srt://platform.com:5000"
    var srtla: Bool = false
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var proto: String = "RTMP"
    var resolution: String = "1920x1080"
    var fps: Int = 30

    init(name: String) {
        self.name = name
    }
}

class SettingsSceneWidget: Codable, Identifiable, Equatable {
    static func == (lhs: SettingsSceneWidget, rhs: SettingsSceneWidget) -> Bool {
        return lhs.id == rhs.id
    }
    
    var widgetId: UUID
    var id: UUID = UUID()
    var x: Int = 0
    var y: Int = 0
    var w: Int = 10
    var h: Int = 10
    
    init(widgetId: UUID) {
        self.widgetId = widgetId
    }
}

class SettingsScene: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = true
    var widgets: [SettingsSceneWidget] = []

    init(name: String) {
        self.name = name
    }
    
    static func == (lhs: SettingsScene, rhs: SettingsScene) -> Bool {
        return lhs.id == rhs.id
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

class SettingsWidgetCamera: Codable {
    var direction: String = "Back"
}

class SettingsWidgetChat: Codable {
}

class SettingsWidgetRecording: Codable {
}

class SettingsWidgetWebview: Codable {
    var url: String = "https://"
}

class SettingsWidgetVideoEffect: Codable {
    var type: String = "Movie"
}

let widgetTypes = ["Camera", /*"Text", */ "Image", "Video effect"/*, "Video", "Chat", "Recording", "Webview"*/]

class SettingsWidget: Codable, Identifiable, Equatable {
    var name: String
    var id: UUID = UUID()
    var type: String = widgetTypes[0]
    var text: SettingsWidgetText = SettingsWidgetText()
    var image: SettingsWidgetImage = SettingsWidgetImage()
    var video: SettingsWidgetVideo = SettingsWidgetVideo()
    var camera: SettingsWidgetCamera = SettingsWidgetCamera()
    var chat: SettingsWidgetChat = SettingsWidgetChat()
    var recording: SettingsWidgetRecording = SettingsWidgetRecording()
    var webview: SettingsWidgetWebview = SettingsWidgetWebview()
    var videoEffect: SettingsWidgetVideoEffect = SettingsWidgetVideoEffect()

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

let variableTypes = ["Text", "HTTP", "Twitch PubSub", "Websocket"]

class SettingsVariable: Codable, Identifiable {
    var name: String
    var id: UUID = UUID()
    var type: String = "Text"
    var text: SettingsVariableText = SettingsVariableText()
    var http: SettingsVariableHttp = SettingsVariableHttp()
    var twitchPubSub: SettingsVariableTwitchPubSub = SettingsVariableTwitchPubSub()
    var websocket: SettingsVariableTextWebsocket = SettingsVariableTextWebsocket()

    init(name: String) {
        self.name = name
    }
}

var buttonTypes = ["Torch", "Mute", "Widget"]

class SettingsButtonWidget: Codable, Identifiable {
    var widgetId: UUID
    var id: UUID = UUID()
    
    init(widgetId: UUID) {
        self.widgetId = widgetId
    }
}

class SettingsButton: Codable, Identifiable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = false
    var type: String = "Torch"
    var imageType: String = "System name"
    var systemImageNameOn: String = "mic.slash"
    var systemImageNameOff: String = "mic"
    var widget: SettingsButtonWidget = SettingsButtonWidget(widgetId: UUID())
    var scenes: [UUID] = []
    
    init(name: String) {
        self.name = name
    }
    
    func addScene(id: UUID) {
        if !scenes.contains(id) {
            scenes.append(id)
        }
    }
    
    func removeScene(id: UUID) {
        if let index = scenes.firstIndex(of: id) {
            scenes.remove(at: index)
        }
    }
}

class Show: Codable {
    var chat: Bool = true
    var viewers: Bool = true
    var uptime: Bool = true
    var stream: Bool = true
    var speed: Bool = true
    var fps: Bool = true
}

class Database: Codable {
    var streams: [SettingsStream] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var buttons: [SettingsButton] = []
    var show: Show = Show()
}

func addDefaultWidgets(database: Database) {
    var widget = SettingsWidget(name: "Back camera")
    widget.type = "Camera"
    widget.camera.direction = "Back"
    database.widgets.append(widget)
    
    widget = SettingsWidget(name: "Front camera")
    widget.type = "Camera"
    widget.camera.direction = "Front"
    database.widgets.append(widget)
    
    widget = SettingsWidget(name: "Movie")
    widget.type = "Video effect"
    widget.videoEffect.type = "Movie"
    database.widgets.append(widget)
}

func createSceneWidgetBackCamera(database: Database) -> SettingsSceneWidget {
    let widget = SettingsSceneWidget(widgetId: database.widgets[0].id)
    widget.x = 0
    widget.y = 0
    widget.h = 100
    widget.w = 100
    return widget
}

func createSceneWidgetFrontCamera(database: Database) -> SettingsSceneWidget {
    let widget = SettingsSceneWidget(widgetId: database.widgets[1].id)
    widget.x = 67
    widget.y = 0
    widget.h = 33
    widget.w = 33
    return widget
}

func createSceneWidgetFrontCameraFull(database: Database) -> SettingsSceneWidget {
    let widget = SettingsSceneWidget(widgetId: database.widgets[1].id)
    widget.x = 0
    widget.y = 0
    widget.h = 100
    widget.w = 100
    return widget
}

func createSceneWidgetVideoEffectMovie(database: Database) -> SettingsSceneWidget {
    let widget = SettingsSceneWidget(widgetId: database.widgets[2].id)
    widget.x = 0
    widget.y = 0
    widget.h = 100
    widget.w = 100
    return widget
}

func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: "Back")
    scene.widgets.append(createSceneWidgetBackCamera(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    database.scenes.append(scene)
    
    scene = SettingsScene(name: "Front")
    scene.widgets.append(createSceneWidgetFrontCameraFull(database: database))
    scene.widgets.append(createSceneWidgetVideoEffectMovie(database: database))
    database.scenes.append(scene)
}

func addDefaultStreams(database: Database) {
    let stream = SettingsStream(name: "Twitch")
    stream.id = UUID()
    stream.enabled = true
    stream.rtmpUrl = "rtmp://arn03.contribute.live-video.net/app/your_stream_key"
    stream.srtUrl = "srt://192.168.202.169:5000"
    stream.twitchChannelName = "jinnytty"
    stream.twitchChannelId = "159498717"
    database.streams.append(stream)
}

func addDefaultButtons(database: Database) {
    var button = SettingsButton(name: "Torch")
    button.id = UUID()
    button.enabled = true
    button.type = "Torch"
    button.imageType = "System name"
    button.systemImageNameOn = "lightbulb.fill"
    button.systemImageNameOff = "lightbulb"
    button.scenes.append(database.scenes[0].id)
    database.buttons.append(button)
    
    button = SettingsButton(name: "Mute")
    button.id = UUID()
    button.enabled = true
    button.type = "Mute"
    button.imageType = "System name"
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    button.scenes.append(database.scenes[0].id)
    button.scenes.append(database.scenes[1].id)
    database.buttons.append(button)

    button = SettingsButton(name: "Movie")
    button.id = UUID()
    button.enabled = true
    button.type = "Widget"
    button.imageType = "System name"
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    button.widget.widgetId = database.widgets[2].id
    button.scenes.append(database.scenes[0].id)
    button.scenes.append(database.scenes[1].id)
    database.buttons.append(button)
    
    /*button = SettingsButton(name: "Grayscale")
    button.id = UUID()
    button.enabled = true
    button.type = "Widget"
    button.imageType = "System name"
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    database.buttons.append(button)*/
}

func createDefault() -> Database {
    let database = Database()
    addDefaultWidgets(database: database)
    addDefaultScenes(database: database)
    addDefaultStreams(database: database)
    addDefaultButtons(database: database)
    return database
}

final class Settings {
    var database = Database()
    @AppStorage("settings") var storage = ""

    func load() {
        do {
            database = try JSONDecoder().decode(Database.self, from: storage.data(using: .utf8)!)
        } catch {
            logger.info("settings: Failed to load. Using default.")
            database = createDefault()
        }
    }

    func store() {
        do {
            storage = String(decoding: try JSONEncoder().encode(database), as: UTF8.self)
        } catch {
            logger.error("settings: Failed to store.")
        }
    }
    
    func reset() {
        database = createDefault()
        store()
    }
}
