import Foundation
import HealthKit
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
    case viewerCount
    case padelScoreboard
    case genericScoreboard
    case removeScoreboard
    case scoreboardPlayers

    static func pack(type: WatchMessageToWatch, data: Any) -> [String: Any] {
        [
            "type": type.rawValue,
            "data": data,
        ]
    }

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

    static func pack(type: WatchMessageFromWatch, data: Any) -> [String: Any] {
        [
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

struct WatchProtocolChatSegment: Codable {
    var text: String?
    var url: String?
}

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

    init(statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            if let heartRate = statistics.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: HKUnit.minute()))
            {
                self.heartRate = Int(heartRate)
            }
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            if let activeEnergyBurned = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                self.activeEnergyBurned = Int(activeEnergyBurned)
            }
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
             HKQuantityType.quantityType(forIdentifier: .distanceCycling):
            if let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                self.distance = Int(distance)
            }
        case HKQuantityType.quantityType(forIdentifier: .stepCount):
            if let stepCount = statistics.sumQuantity()?.doubleValue(for: .count()) {
                self.stepCount = Int(stepCount)
            }
        case HKQuantityType.quantityType(forIdentifier: .runningPower):
            if let power = statistics.mostRecentQuantity()?.doubleValue(for: .watt()) {
                self.power = Int(power)
            }
        default:
            break
        }
    }
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
        Double(color) / 255
    }

    func color() -> Color {
        Color(
            red: colorScale(red),
            green: colorScale(green),
            blue: colorScale(blue)
        )
    }
}
