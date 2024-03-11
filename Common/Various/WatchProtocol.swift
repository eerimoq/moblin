import Foundation

enum WatchMessage: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
    case settings
}

enum WatchMessageFromWatch: String {
    case getImage
}

// periphery:ignore
struct WatchProtocolChatSegment: Codable {
    var text: String?
    var url: String?
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
    // Starts at 1 and incremented for each new message
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
