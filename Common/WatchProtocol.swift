import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
    case settings
}

struct WatchProtocolChatSegment: Codable {
    var text: String?
    var url: String?
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
    var id: Int
    var timestamp: String
    var user: String
    var userColor: WatchProtocolColor
    var segments: [WatchProtocolChatSegment]
}

// periphery:ignore
struct WatchProtocolColor: Codable {
    var red: Int
    var green: Int
    var blue: Int
}

class WatchSettingsChat: Codable {
    var fontSize: Float = 17.0
    var timestampEnabled: Bool? = true
}

class WatchSettings: Codable {
    var chat: WatchSettingsChat = .init()
}
