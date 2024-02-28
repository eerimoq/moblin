import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
    var user: String
    var userColor: String
    var segments: [String]
}
