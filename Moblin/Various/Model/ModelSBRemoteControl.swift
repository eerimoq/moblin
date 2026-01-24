import Foundation
import Network

private let basketballConfig = SBMatchConfig(
    sportId: "basketball",
    layout: "sideBySide",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: true,
        stat1: "5",
        stat1Label: "TO",
        stat2: "0",
        stat2Label: "FOUL",
        stat3: "NO BONUS",
        stat3Label: ""
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false,
        stat1: "5",
        stat1Label: "TO",
        stat2: "0",
        stat2Label: "FOUL",
        stat3: "NO BONUS",
        stat3Label: ""
    ),
    global: SBGlobalStats(
        title: "Varsity Basketball",
        timer: "10:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "QTR",
        subPeriod: "",
        primaryScoreResetOnPeriod: false,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Pt", periodReset: false),
        "stat1": .init(
            type: "select",
            label: "TO",
            options: ["0", "1", "2", "3", "4", "5"],
            periodReset: true
        ),
        "stat2": .init(type: "cycle",
                       label: "FOUL",
                       options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
                       periodReset: true),
        "stat3": .init(type: "cycle", label: "", options: ["NO BONUS", "BONUS", "DOUBLE"], periodReset: true),
        "possession": .init(type: "toggleTeam", label: "POSS", periodReset: false),
    ]
)

private let genericConfig = SBMatchConfig(
    sportId: "generic",
    layout: "stacked",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false
    ),
    global: SBGlobalStats(
        title: "",
        timer: "",
        timerDirection: "down",
        period: "",
        periodLabel: "",
        subPeriod: "",
        primaryScoreResetOnPeriod: false,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false,
        showTitle: false,
        showStats: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Pt", periodReset: false),
    ]
)

private let genericSetsConfig = SBMatchConfig(
    sportId: "generic sets",
    layout: "stacked",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false,
        secondaryScore: "0"
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false,
        secondaryScore: "0"
    ),
    global: SBGlobalStats(
        title: "GENERIC MATCH",
        timer: "00:00",
        timerDirection: "up",
        period: "1",
        periodLabel: "SET",
        subPeriod: "",
        primaryScoreResetOnPeriod: true,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false,
        showTitle: false,
        titleTop: true,
        showStats: false,
        showSecondaryRow: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Pt", periodReset: true),
        "secondaryScore": .init(type: "counter", label: "Set", periodReset: false),
        "possession": .init(type: "toggleTeam", label: "POSS", periodReset: false),
    ]
)

private let hockeyConfig = SBMatchConfig(
    sportId: "hockey",
    layout: "sideBySide",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false,
        secondaryScore: "0",
        secondaryScoreLabel: "SOG",
        stat1: "NO PP",
        stat1Label: "",
        stat2: "NO EN",
        stat2Label: "",
        stat3: "NO DP",
        stat3Label: ""
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        textColor: "#ffffff",
        possession: false,
        secondaryScore: "0",
        secondaryScoreLabel: "SOG",
        stat1: "NO PP",
        stat1Label: "",
        stat2: "NO EN",
        stat2Label: "",
        stat3: "NO DP",
        stat3Label: ""
    ),
    global: SBGlobalStats(
        title: "Varsity Hockey",
        timer: "15:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "PER",
        subPeriod: "",
        primaryScoreResetOnPeriod: false,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Goal", periodReset: false),
        "secondaryScore": .init(type: "counter", label: "SOG", periodReset: false),
        "stat1": .init(type: "cycle", label: "", options: ["NO PP", "PP"], periodReset: true),
        "stat2": .init(type: "cycle", label: "", options: ["NO EN", "EN"], periodReset: true),
        "stat3": .init(type: "cycle", label: "", options: ["NO DP", "DP"], periodReset: true),
    ]
)

private let soccerConfig = SBMatchConfig(
    sportId: "soccer",
    layout: "stacked",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        textColor: "#ffffff",
        possession: false
    ),
    global: SBGlobalStats(
        title: "VARSITY SOCCER",
        timer: "30:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "HALF",
        subPeriod: "",
        primaryScoreResetOnPeriod: false,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Goal", periodReset: false),
    ]
)

private let tennisConfig = SBMatchConfig(
    sportId: "tennis",
    layout: "stackhistory",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: true
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        textColor: "#ffffff",
        possession: false
    ),
    global: SBGlobalStats(
        title: "TENNIS",
        timer: "00:00",
        timerDirection: "up",
        period: "1",
        periodLabel: "SET",
        subPeriod: "",
        primaryScoreResetOnPeriod: true,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false,
        scoringMode: "tennis",
        minSetScore: 3,
        maxSetScore: 15,
        showStats: false
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Pt", periodReset: false),
        "currentSetScore": .init(type: "counter", label: "Game", periodReset: true),
        "possession": .init(type: "toggleTeam", label: "SERVE", periodReset: false),
    ]
)

private let volleyballConfig = SBMatchConfig(
    sportId: "volleyball",
    layout: "stacked",
    team1: SBTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: true,
        secondaryScore: "0",
        stat1: "0",
        stat1Label: "TO"
    ),
    team2: SBTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false,
        secondaryScore: "0",
        stat1: "0",
        stat1Label: "TO"
    ),
    global: SBGlobalStats(
        title: "Varsity Volleyball",
        timer: "00:00",
        timerDirection: "up",
        period: "1",
        periodLabel: "SET",
        subPeriod: " ",
        primaryScoreResetOnPeriod: true,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: true,
        minSetScore: 15,
        maxSetScore: 40
    ),
    controls: [
        "primaryScore": .init(type: "counter", label: "Pt", periodReset: true),
        "secondaryScore": .init(type: "counter", label: "Set", periodReset: false),
        "stat1": .init(type: "select", label: "TO", options: ["0", "1", "2", "3"], periodReset: true),
        "possession": .init(type: "toggleTeam", label: "SERVE", periodReset: false),
    ]
)

private let configs: [String: SBMatchConfig] = [
    "basketball": basketballConfig,
    "generic": genericConfig,
    "generic sets": genericSetsConfig,
    "hockey": hockeyConfig,
    "soccer": soccerConfig,
    "tennis": tennisConfig,
    "volleyball": volleyballConfig,
]

extension Model {
    func setupSBRemoteControlServer() {
        sbRemoteControlServer.onMessageReceived = { [weak self] message in
            guard let self else {
                return
            }
            if message.type == "update-match", let config = message.updates {
                self.handleExternalScoreboardUpdate(config: config)
            } else if message.type == "switch-sport", let sportId = message.sport {
                self.handleSportSwitch(sportId: sportId)
            } else if message.type == "action", let action = message.action {
                self.handleAction(action: action, value: message.value)
            } else if message.type == "request-sync" {
                self.broadcastCurrentState()
            }
        }
        sbRemoteControlServer.onClientConnected = { [weak self] connection in
            self?.syncCurrentStateToRemote(connection: connection)
        }
        sbRemoteControlServer.start()
    }

    private func handleAction(action: String, value: String?) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let scoreboard = widget.scoreboard
        if action == "toggle-clock" {
            scoreboard.generic.isClockStopped.toggle()
        } else if action == "set-duration", let valStr = value, let mins = Int(valStr) {
            scoreboard.generic.clockMaximum = mins
            if scoreboard.generic.clockDirection == .down {
                scoreboard.generic.clockMinutes = mins
                scoreboard.generic.clockSeconds = 0
            }
            scoreboard.generic.isClockStopped = true
        } else if action == "set-clock-manual", let timeStr = value {
            let parts = timeStr.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                scoreboard.generic.clockMinutes = m
                scoreboard.generic.clockSeconds = s
                scoreboard.generic.isClockStopped = true
            }
        }
        sceneUpdated()
        broadcastCurrentState()
    }

    func handleExternalScoreboardUpdate(config: SBMatchConfig) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            scoreboard.config = config
            if scoreboard.sportId != config.sportId {
                scoreboard.sportId = config.sportId
            }
            switch config.layout {
            case "sideBySide":
                scoreboard.layout = .sideBySide
            case "stackhistory":
                scoreboard.layout = .stackhistory
            case "stackedInline":
                scoreboard.layout = .stackedInline
            default:
                scoreboard.layout = .stacked
            }
            if let showTitle = config.global.showTitle {
                scoreboard.showStackedHeader = showTitle
                scoreboard.showSbsTitle = showTitle
            }
            if let titleTop = config.global.titleTop {
                scoreboard.titleAbove = titleTop
            }
            if let showStats = config.global.showStats {
                scoreboard.showGlobalStatsBlock = showStats
            }
            if let show2nd = config.global.showSecondaryRow {
                scoreboard.showSecondaryRows = show2nd
            }
            scoreboard.generic.home = config.team1.name
            scoreboard.generic.away = config.team2.name
            scoreboard.generic.title = config.global.title
            scoreboard.generic.period = config.global.period
            if let h = Int(config.team1.primaryScore) {
                scoreboard.generic.score.home = h
            }
            if let a = Int(config.team2.primaryScore) {
                scoreboard.generic.score.away = a
            }
            scoreboard.team1BgColor = RgbColor.fromHex(string: config.team1.bgColor) ?? scoreboard
                .team1BgColor
            scoreboard.team1TextColor = RgbColor.fromHex(string: config.team1.textColor) ?? scoreboard
                .team1TextColor
            scoreboard.team2BgColor = RgbColor.fromHex(string: config.team2.bgColor) ?? scoreboard
                .team2BgColor
            scoreboard.team2TextColor = RgbColor.fromHex(string: config.team2.textColor) ?? scoreboard
                .team2TextColor
            scoreboard.loadColors()
            let parts = config.global.timer.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                scoreboard.generic.clockMinutes = m
                scoreboard.generic.clockSeconds = s
            }
            scoreboard.generic.clockDirection = (config.global.timerDirection == "down") ? .down : .up
            if let effect = scoreboardEffects[widget.id] {
                DispatchQueue.main.async {
                    effect.update(scoreboard: scoreboard)
                }
            }
        }
        sceneUpdated()
        broadcastCurrentState()
    }

    private func handleSportSwitch(sportId: String) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            scoreboard.sportId = sportId
            if let newConfig = configs[sportId] {
                scoreboard.config = newConfig
                switch newConfig.layout {
                case "sideBySide":
                    scoreboard.layout = .sideBySide
                    scoreboard.showSecondaryRows = true
                    scoreboard.showGlobalStatsBlock = true
                case "stackhistory":
                    scoreboard.layout = .stackhistory
                    scoreboard.showSecondaryRows = false
                    scoreboard.showGlobalStatsBlock = false
                default:
                    scoreboard.layout = .stacked
                    scoreboard.showSecondaryRows = false
                    scoreboard.showGlobalStatsBlock = false
                }
                scoreboard.showStackedHeader = false
                scoreboard.showSbsTitle = false
                scoreboard.showStackedFooter = false
                scoreboard.generic.score.home = Int(newConfig.team1.primaryScore) ?? 0
                scoreboard.generic.score.away = Int(newConfig.team2.primaryScore) ?? 0
                scoreboard.generic.period = newConfig.global.period
                let parts = newConfig.global.timer.split(separator: ":")
                if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                    scoreboard.generic.clockMinutes = m
                    scoreboard.generic.clockSeconds = s
                    scoreboard.generic.clockMaximum = m + (s > 0 ? 1 : 0)
                } else {
                    scoreboard.generic.clockMinutes = 0
                    scoreboard.generic.clockSeconds = 0
                }
                scoreboard.generic.clockDirection = (newConfig.global.timerDirection == "down") ? .down : .up
                scoreboard.generic.isClockStopped = true
                scoreboard.team1BgColor = RgbColor.fromHex(string: newConfig.team1.bgColor) ?? scoreboard
                    .team1BgColor
                scoreboard.team1TextColor = RgbColor.fromHex(string: newConfig.team1.textColor) ?? scoreboard
                    .team1TextColor
                scoreboard.team2BgColor = RgbColor.fromHex(string: newConfig.team2.bgColor) ?? scoreboard
                    .team2BgColor
                scoreboard.team2TextColor = RgbColor.fromHex(string: newConfig.team2.textColor) ?? scoreboard
                    .team2TextColor
                scoreboard.loadColors()
            }
        }
        sceneUpdated()
        broadcastCurrentState()
    }

    func syncCurrentStateToRemote(connection: NWConnection) {
        let sportsMsg = SBMessage(type: "available-sports", sports: getAvailableSports())
        if let d = try? JSONEncoder().encode(sportsMsg), let s = String(data: d, encoding: .utf8) {
            sbRemoteControlServer.sendMessageString(connection: connection, message: s)
        }
        let msg = SBMessage(type: "update-match", updates: getCurrentConfig())
        if let d = try? JSONEncoder().encode(msg), let s = String(data: d, encoding: .utf8) {
            sbRemoteControlServer.sendMessageString(connection: connection, message: s)
        }
    }

    func broadcastCurrentState() {
        let msg = SBMessage(type: "update-match", updates: getCurrentConfig())
        if let d = try? JSONEncoder().encode(msg), let s = String(data: d, encoding: .utf8) {
            sbRemoteControlServer.broadcastMessageString(s)
        }
    }

    func getCurrentConfigForEffect() -> SBMatchConfig {
        return getCurrentConfig()
    }

    private func getCurrentConfig() -> SBMatchConfig {
        let scoreboard = database.widgets.first(where: { $0.type == .scoreboard })?.scoreboard
        let sportId = scoreboard?.sportId ?? "volleyball"
        var liveConfig: SBMatchConfig
        if let current = scoreboard?.config, current.sportId == sportId {
            liveConfig = current
        } else if let loaded = configs[sportId] {
            liveConfig = loaded
            scoreboard?.config = loaded
        } else {
            return SBMatchConfig(
                sportId: "error",
                layout: "stacked",
                team1: SBTeam(
                    name: "FILE MISSING",
                    bgColor: "#000000",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0"
                ),
                team2: SBTeam(
                    name: "ERROR",
                    bgColor: "#000000",
                    textColor: "#ffffff",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0"
                ),
                global: SBGlobalStats(
                    title: "ERROR",
                    timer: "00:00",
                    timerDirection: "up",
                    period: "1",
                    periodLabel: "SET",
                    subPeriod: "",
                    primaryScoreResetOnPeriod: false,
                    secondaryScoreResetOnPeriod: false
                ),
                controls: [:]
            )
        }
        if let scoreboard {
            switch scoreboard.layout {
            case .sideBySide:
                liveConfig.layout = "sideBySide"
            case .stackhistory:
                liveConfig.layout = "stackhistory"
            case .stackedInline:
                liveConfig.layout = "stackedInline"
            default:
                liveConfig.layout = "stacked"
            }
            liveConfig.global.showTitle = scoreboard.showStackedHeader || scoreboard.showSbsTitle
            liveConfig.global.titleTop = scoreboard.titleAbove
            liveConfig.global.showStats = scoreboard.showGlobalStatsBlock
            liveConfig.global.showSecondaryRow = scoreboard.showSecondaryRows
            liveConfig.team1.name = scoreboard.generic.home
            liveConfig.team2.name = scoreboard.generic.away
            liveConfig.global.title = scoreboard.generic.title
            if !scoreboard.generic.period.isEmpty {
                liveConfig.global.period = scoreboard.generic.period
            }
            if liveConfig.global.scoringMode != "tennis" {
                liveConfig.team1.primaryScore = String(scoreboard.generic.score.home)
                liveConfig.team2.primaryScore = String(scoreboard.generic.score.away)
            }
            liveConfig.global.timer = scoreboard.generic.clock()
            liveConfig.global.timerDirection = (scoreboard.generic.clockDirection == .down) ? "down" : "up"
            liveConfig.global.duration = scoreboard.generic.clockMaximum
            liveConfig.team1.bgColor = scoreboard.team1BgColor.toHex()
            liveConfig.team1.textColor = scoreboard.team1TextColor.toHex()
            liveConfig.team2.bgColor = scoreboard.team2BgColor.toHex()
            liveConfig.team2.textColor = scoreboard.team2TextColor.toHex()
        }
        return liveConfig
    }

    func getAvailableSports() -> [String] {
        let sports = configs.keys
        let topPriority = ["generic", "generic sets"]
        let rest = sports.filter { !topPriority.contains($0) }.sorted()
        let finalSports = topPriority.filter { sports.contains($0) } + rest
        return finalSports.isEmpty ? ["volleyball", "basketball"] : finalSports
    }

    func broadcastStreamStats() {
        let stats = SBStreamStats(battery: "\(Int(battery.level * 100))%",
                                  bitrate: bitrate.speedMbpsOneDecimal)
        let message = SBMessage(type: "stream-stats", stats: stats)
        if let d = try? JSONEncoder().encode(message), let s = String(data: d, encoding: .utf8) {
            sbRemoteControlServer.broadcastMessageString(s)
        }
    }
}
