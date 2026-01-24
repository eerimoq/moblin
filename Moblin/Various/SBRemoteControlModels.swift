import Foundation

struct SBControl: Codable {
    var type: String
    var label: String
    var options: [String]?
    var periodReset: Bool?
}

struct SBTeam: Codable {
    var name: String
    var bgColor: String
    var textColor: String
    var possession: Bool
    var primaryScore: String
    var secondaryScore: String
    var secondaryScoreLabel: String?
    var secondaryScore1: String?
    var secondaryScore2: String?
    var secondaryScore3: String?
    var secondaryScore4: String?
    var secondaryScore5: String?
    var stat1: String
    var stat1Label: String
    var stat2: String
    var stat2Label: String
    var stat3: String
    var stat3Label: String
    var stat4: String
    var stat4Label: String
}

struct SBGlobalStats: Codable {
    var title: String
    var timer: String
    var timerDirection: String
    var duration: Int? // New: Max clock time in minutes
    var period: String
    var periodLabel: String
    var subPeriod: String
    var primaryScoreResetOnPeriod: Bool?
    var secondaryScoreResetOnPeriod: Bool?
    var changePossessionOnScore: Bool?
    var scoringMode: String?
    var minSetScore: Int?
    var maxSetScore: Int?
    
    // Visual Toggles
    var showTitle: Bool?
    var titleTop: Bool?
    var showStats: Bool?
    var showSecondaryRow: Bool?
}

struct SBMatchConfig: Codable {
    var matchId: String
    var layout: String
    var team1: SBTeam
    var team2: SBTeam
    var global: SBGlobalStats
    var controls: [String: SBControl]
}

struct SBMessage: Codable {
    var type: String
    var updates: SBMatchConfig?
    var stats: SBStreamStats?
    var sport: String?
    var action: String?
    var value: String?
    var sports: [String]?
}

struct SBStreamStats: Codable {
    var battery: String
    var system: String
    var bitrate: String
    var bonding: String
    var rtts: String
    var uptime: String
}
