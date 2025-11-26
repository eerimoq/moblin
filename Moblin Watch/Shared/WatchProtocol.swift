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
    case viewerCount
    case padelScoreboard
    case genericScoreboard
    case removeScoreboard
    case scoreboardPlayers

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
    case updatePadelScoreboard
    case updateGenericScoreboard
    case createStreamMarker
    case instantReplay
    case saveReplay

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
    case reply
    case redemption
    case other
}

struct WatchProtocolChatHighlight: Codable {
    let kind: WatchProtocolChatHighlightKind
    let barColor: WatchProtocolColor
    let image: String
    let title: String
}

struct WatchProtocolChatMessage: Codable {
    // Starts at 1 and incremented for each new message
    var id: Int
    var timestamp: String
    var displayName: String
    var userColor: WatchProtocolColor
    var userBadges: [URL]
    var segments: [WatchProtocolChatSegment]
    var highlight: WatchProtocolChatHighlight?
}

struct WatchProtocolColor: Codable {
    var red: Int
    var green: Int
    var blue: Int
}

struct WatchProtocolScene: Codable, Identifiable {
    var id: UUID
    var name: String
}

struct WatchProtocolZoomPreset: Codable, Identifiable {
    var id: UUID
    var name: String
}

enum WatchProtocolWorkoutType: Codable {
    case walking
    case running
    case cycling
}

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

struct WatchProtocolPadelScoreboardScore: Codable {
    var home: Int
    var away: Int
}

struct WatchProtocolPadelScoreboard: Codable {
    var id: UUID
    var home: [UUID]
    var away: [UUID]
    var score: [WatchProtocolPadelScoreboardScore]
}

struct WatchProtocolGenericScoreboard: Codable {
    var id: UUID
    var homeTeam: String
    var awayTeam: String
    var homeScore: Int
    var awayScore: Int
    var clockMinutes: Int
    var clockSeconds: Int
    var clockMaximum: Int
    var isClockStopped: Bool
    var title: String
}

struct WatchProtocolPadelScoreboardAction: Codable {
    let id: UUID
    let action: WatchProtocolPadelScoreboardActionType
}

struct WatchProtocolPadelScoreboardActionPlayers: Codable {
    var home: [UUID]
    var away: [UUID]
}

enum WatchProtocolPadelScoreboardActionType: Codable {
    case reset
    case undo
    case incrementHome
    case incrementAway
    case players(WatchProtocolPadelScoreboardActionPlayers)
}

struct WatchProtocolGenericScoreboardAction: Codable {
    let id: UUID
    let action: WatchProtocolGenericScoreboardActionType
}

enum WatchProtocolGenericScoreboardActionType: Codable {
    case reset
    case undo
    case incrementHome
    case incrementAway
    case setTitle(title: String)
    case setClock(minutes: Int, seconds: Int)
    case setClockState(stopped: Bool)
}

struct WatchProtocolScoreboardPlayer: Codable {
    var id: UUID
    var name: String
}

struct WatchProtocolInstantReplay: Codable {
    let duration: Int
}

extension WatchProtocolColor {
    private func colorScale(_ color: Int) -> Double {
        return Double(color) / 255
    }

    func color() -> Color {
        return Color(
            red: colorScale(red),
            green: colorScale(green),
            blue: colorScale(blue)
        )
    }
}
