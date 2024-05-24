import Foundation
import SwiftUI

enum WatchMessageToWatch: String {
    case chatMessage
    case speedAndTotal
    case recordingLength
    case audioLevel
    case preview
    case settings
    case isLive
    case isRecording
    case isMuted
    case thermalState

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
    case setIsMuted
    case keepAlive
    case skipCurrentChatTextToSpeechMessage

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

extension WatchProtocolColor {
    static func fromHex(value: String) -> WatchProtocolColor? {
        if let colorNumber = Int(value.suffix(6), radix: 16) {
            return WatchProtocolColor(
                red: (colorNumber >> 16) & 0xFF,
                green: (colorNumber >> 8) & 0xFF,
                blue: colorNumber & 0xFF
            )
        } else {
            return nil
        }
    }

    // periphery:ignore
    private func colorScale(_ color: Int) -> Double {
        return Double(color) / 255
    }

    // periphery:ignore
    func color() -> Color {
        return Color(
            red: colorScale(red),
            green: colorScale(green),
            blue: colorScale(blue)
        )
    }
}
