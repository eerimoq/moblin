import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
    case settings
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
    var id: Int
    var timestamp: String
    var user: String
    var userColor: WatchProtocolColor
    var segments: [String]
}

// periphery:ignore
struct WatchProtocolColor: Codable {
    var red: Int
    var green: Int
    var blue: Int
}

class WatchSettingsChat: Codable {
    var fontSize: Float = 17.0
}

class WatchSettings: Codable {
    var chat: WatchSettingsChat = .init()
}
