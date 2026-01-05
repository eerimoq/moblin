import Foundation

struct SBTeam: Codable {
    var name: String
    var bgColor: String
    var textColor: String
    var setScore: Int
    var matchScore: Int
    var serving: Bool
}

struct SBMatchConfig: Codable {
    var matchId: String
    var layout: String
    var team1: SBTeam
    var team2: SBTeam
}

// --- NEW STATS MODEL ---
struct SBStreamStats: Codable {
    var battery: String
    var system: String
    var bitrate: String
    var bonding: String
    var rtts: String
    var uptime: String
}

struct SBMessage: Codable {
    var type: String
    var updates: SBMatchConfig?
    var stats: SBStreamStats?
}
