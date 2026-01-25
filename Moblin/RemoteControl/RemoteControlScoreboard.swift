import Foundation

struct RemoteControlScoreboardControl: Codable {
    // periphery: ignore
    var type: String
    // periphery: ignore
    var label: String
    // periphery: ignore
    var options: [String]?
    // periphery: ignore
    var periodReset: Bool?
}

struct RemoteControlScoreboardTeam: Codable {
    var name: String
    var bgColor: String
    var textColor: String = "#ffffff"
    var possession: Bool
    var primaryScore: String = "0"
    var secondaryScore: String = ""
    var secondaryScoreLabel: String? = ""
    var secondaryScore1: String?
    var secondaryScore2: String?
    var secondaryScore3: String?
    var secondaryScore4: String?
    var secondaryScore5: String?
    var stat1: String = ""
    var stat1Label: String = ""
    var stat2: String = ""
    var stat2Label: String = ""
    var stat3: String = ""
    var stat3Label: String = ""
    var stat4: String = ""
    var stat4Label: String = ""
}

struct RemoteControlScoreboardGlobalStats: Codable {
    var title: String
    var timer: String
    var timerDirection: String
    // periphery: ignore
    var duration: Int?
    var period: String
    var periodLabel: String
    var subPeriod: String
    // periphery: ignore
    var primaryScoreResetOnPeriod: Bool?
    // periphery: ignore
    var secondaryScoreResetOnPeriod: Bool?
    // periphery: ignore
    var changePossessionOnScore: Bool?
    var scoringMode: String?
    // periphery: ignore
    var minSetScore: Int?
    // periphery: ignore
    var maxSetScore: Int?
    var showTitle: Bool?
    var titleTop: Bool?
    var showStats: Bool?
    var showSecondaryRow: Bool?
}

struct RemoteControlScoreboardMatchConfig: Codable {
    var sportId: String
    var layout: String
    var team1: RemoteControlScoreboardTeam
    var team2: RemoteControlScoreboardTeam
    var global: RemoteControlScoreboardGlobalStats
    // periphery: ignore
    var controls: [String: RemoteControlScoreboardControl]
}

enum RemoteControlScoreboardMessage: Codable {
    case updates(config: RemoteControlScoreboardMatchConfig)
    case stats(battery: String, bitrate: String)
    case sport(id: String)
    case action(action: String, value: String?)
    case sports(names: [String])
    case requestSync
}
