import Foundation

enum WatchMessageToWatch: String {
    case chatMessage
    case speedAndTotal
    case audioLevel
    case preview
    case settings
    case isLive
    case isRecording

    static func pack(type: WatchMessageToWatch, data: Any) -> [String: Any] {
        return [
            "type": type.rawValue,
            "data": data,
        ]
    }

    // periphery:ignore
    static func unpack(_ message: [String: Any]) -> (WatchMessageToWatch, Any)? {
        guard let type = message["type"] as? String else {
            return nil
        }
        guard let type = WatchMessageToWatch(rawValue: type) else {
            return nil
        }
        guard let data = message["data"] else {
            return nil
        }
        return (type, data)
    }
}

enum WatchMessageFromWatch: String {
    case getImage
    case setIsLive
    case setIsRecording
    case keepAlive

    // periphery:ignore
    static func pack(type: WatchMessageFromWatch, data: Any) -> [String: Any] {
        return [
            "type": type.rawValue,
            "data": data,
        ]
    }

    static func unpack(_ message: [String: Any]) -> (WatchMessageFromWatch, Any)? {
        guard let type = message["type"] as? String else {
            return nil
        }
        guard let type = WatchMessageFromWatch(rawValue: type) else {
            return nil
        }
        guard let data = message["data"] else {
            return nil
        }
        return (type, data)
    }
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
