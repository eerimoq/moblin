import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
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
