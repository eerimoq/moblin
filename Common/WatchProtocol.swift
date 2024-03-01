import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
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
