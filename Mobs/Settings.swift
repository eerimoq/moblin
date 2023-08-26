import SwiftUI

struct SettingsConnection: Codable {
    var name: String
    var rtmpUrl: String
    var twitchChannelName: String
    var twitchChannelId: String
}

struct SettingsSceneWidget: Codable {
    var name: String
    var x: Int
    var y: Int
    var w: Int
    var h: Int
}

struct SettingsScene: Codable {
    var name: String
    var widgets: [SettingsSceneWidget]
}

struct SettingsWidgetText: Codable {
    var formatString: String
}

struct SettingsWidgetImage: Codable {
    var url: String
}

struct SettingsWidgetVideo: Codable {
    var url: String
}

struct SettingsWidgetCamera: Codable {
    var direction: String
}

struct SettingsWidgetChat: Codable {
}

struct SettingsWidgetRecording: Codable {
}

struct SettingsWidgetWebview: Codable {
    var url: String
}

enum SettingsWidgetType: Codable {
    case text(SettingsWidgetText)
    case image(SettingsWidgetImage)
    case video(SettingsWidgetVideo)
    case camera(SettingsWidgetCamera)
    case chat(SettingsWidgetChat)
    case recording(SettingsWidgetRecording)
    case webview(SettingsWidgetWebview)
}

struct SettingsWidget: Codable {
    var name: String
    var type: SettingsWidgetType
}

struct SettingsVariableText: Codable {
    var value: String
}

struct SettingsVariableHttp: Codable {
    var url: String
}

struct SettingsVariableTwitchPubSub: Codable {
    var pattern: String
}

struct SettingsVariableTextWebsocket: Codable {
    var url: String
    var pattern: String
}

enum SettingsVariableType: Codable {
    case text(SettingsVariableText)
    case http(SettingsVariableHttp)
    case twitchPubSub(SettingsVariableTwitchPubSub)
    case websocket(SettingsVariableTextWebsocket)
}

struct SettingsVariable: Codable {
    var name: String
    var type: SettingsVariableType
}

struct Database: Codable {
    var connections: [SettingsConnection] = []
    var scenes: [SettingsScene] = []
    var widgets: [SettingsWidget] = []
    var variables: [SettingsVariable] = []
    var chat: Bool = false
    var viewers: Bool = false
    var uptime: Bool = false
}

class Settings: ObservableObject {
    @Published var database = Database()
    @AppStorage("settings") var storage = ""

    func load() {
        do {
            print(storage)
            self.database = try JSONDecoder().decode(Database.self, from: storage.data(using: .utf8)!)
        } catch {
            print("Failed to load settings.")
        }
    }

    func store() {
        do {
            self.storage = String(decoding: try JSONEncoder().encode(self.database), as: UTF8.self)
        } catch {
            print("Failed to store settings.")
        }
    }
}
