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
    case zoom
    case zoomPresets
    case zoomPreset
    case scenes
    case scene
    case startWorkout
    case stopWorkout

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
    case setZoom
    case setZoomPreset
    case setScene
    case updateWorkoutStats

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
enum WatchProtocolChatHighlightKind: Codable {
    case redemption
    case other
}

// periphery:ignore
struct WatchProtocolChatHighlight: Codable {
    let kind: WatchProtocolChatHighlightKind
    let color: WatchProtocolColor
    let image: String
    let title: String
}

// periphery:ignore
struct WatchProtocolChatMessage: Codable {
    // Starts at 1 and incremented for each new message
    var id: Int
    var timestamp: String
    var user: String
    var userColor: WatchProtocolColor
    var userBadges: [URL]
    var segments: [WatchProtocolChatSegment]
    var highlight: WatchProtocolChatHighlight?
}

// periphery:ignore
struct WatchProtocolColor: Codable {
    var red: Int
    var green: Int
    var blue: Int
}

// periphery:ignore
struct WatchProtocolScene: Codable, Identifiable {
    var id: UUID
    var name: String
}

// periphery:ignore
struct WatchProtocolZoomPreset: Codable, Identifiable {
    var id: UUID
    var name: String
}

enum WatchProtocolWorkoutType: Codable {
    case walking
    case running
    case cycling
}

// periphery:ignore
struct WatchProtocolStartWorkout: Codable {
    var type: WatchProtocolWorkoutType
}

struct WatchProtocolWorkoutStats: Codable {
    var heartRate: Int?
    var activeEnergyBurned: Int?
    var distance: Int?
    var stepCount: Int?
    var power: Int?
}

extension WatchProtocolColor {
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
