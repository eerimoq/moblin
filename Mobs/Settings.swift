import SwiftUI

struct SettingsConnection: Codable {
    var name: String
    var id: UUID
    var rtmpUrl: String
    var twitchChannelName: String
    var twitchChannelId: String
}

struct SettingsSceneWidget: Codable {
    var id: UUID
    var x: Int = 0
    var y: Int = 0
    var w: Int = 10
    var h: Int = 10
}

struct SettingsScene: Codable {
    var name: String
    var id: UUID = UUID()
    var enabled: Bool = true
    var widgets: [SettingsSceneWidget] = []
}

struct SettingsWidgetText: Codable {
    var formatString: String = "Sub goal: {subs} / 10"
}

struct SettingsWidgetImage: Codable {
    var url: String = "https://"
}

struct SettingsWidgetVideo: Codable {
    var url: String = "https://"
}

struct SettingsWidgetCamera: Codable {
    var direction: String = "Back"
}

struct SettingsWidgetChat: Codable {
}

struct SettingsWidgetRecording: Codable {
}

struct SettingsWidgetWebview: Codable {
    var url: String = "https://"
}

struct SettingsWidget: Codable {
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
}

struct SettingsVariableText: Codable {
    var value: String = ""
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
    var id: UUID = UUID()
    var type: SettingsVariableType = .text(SettingsVariableText())
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
