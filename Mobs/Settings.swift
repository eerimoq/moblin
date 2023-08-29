import SwiftUI

class SettingsConnection: Codable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = false
    var rtmpUrl: String = "rtmp://"
    var twitchChannelName: String = ""
    var twitchChannelId: String = ""

    init(name: String) {
        self.name = name
    }
}

class SettingsSceneWidget: Codable {
    var id: UUID
    var x: Int = 0
    var y: Int = 0
    var w: Int = 10
    var h: Int = 10
    
    init(id: UUID) {
        self.id = id
    }
}

class SettingsScene: Codable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = true
    var widgets: [SettingsSceneWidget] = []

    init(name: String) {
        self.name = name
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

let widgetTypes = ["Text", "Image", "Video", "Camera", "Chat", "Recording", "Webview"]

class SettingsWidget: Codable {
    var name: String
    var id: UUID = UUID()
    var type: String = "Text"
    var text: SettingsWidgetText = SettingsWidgetText()
    var image: SettingsWidgetImage = SettingsWidgetImage()
    var video: SettingsWidgetVideo = SettingsWidgetVideo()
    var camera: SettingsWidgetCamera = SettingsWidgetCamera()
    var chat: SettingsWidgetChat = SettingsWidgetChat()
    var recording: SettingsWidgetRecording = SettingsWidgetRecording()
    var webview: SettingsWidgetWebview = SettingsWidgetWebview()

    init(name: String) {
        self.name = name
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

class SettingsVariable: Codable {
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

class Database: Codable {
    var connections: [SettingsConnection] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var chat: Bool = false
    var viewers: Bool = false
    var uptime: Bool = false
    var connection: Bool = false
}

func addDefaultWidgets(database: Database) {
    let widget = SettingsWidget(name: "Back camera")
    widget.type = "Camera"
    database.widgets.append(widget)
}

func addDefaultScenes(database: Database) {
    let scene = SettingsScene(name: "Default")
    let widget = SettingsSceneWidget(id: database.widgets[0].id)
    widget.x = 0
    widget.y = 0
    widget.h = 100
    widget.w = 100
    scene.widgets.append(widget)
    database.scenes.append(scene)
}

func addDefaultConnections(database: Database) {
    let connection = SettingsConnection(name: "Default")
    connection.id = UUID()
    connection.rtmpUrl = "rtmp://192.168.202.169:1935/live/1234"
    connection.twitchChannelName = "jinnytty"
    connection.twitchChannelId = "59965916"
    database.connections.append(connection)
}

func createDefault() -> Database {
    let database = Database()
    addDefaultWidgets(database: database)
    addDefaultScenes(database: database)
    addDefaultConnections(database: database)
    return database
}

final class Settings {
    var database = Database()
    @AppStorage("settings") var storage = ""

    func load() {
        do {
            database = try JSONDecoder().decode(Database.self, from: storage.data(using: .utf8)!)
        } catch {
            print("Failed to load settings. Using default.")
            database = createDefault()
        }
    }

    func store() {
        do {
            storage = String(decoding: try JSONEncoder().encode(database), as: UTF8.self)
        } catch {
            print("Failed to store settings.")
        }
    }
}
