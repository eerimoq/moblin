import Foundation
import Network

private let basketballConfig = RemoteControlScoreboardMatchConfig(
    sportId: "basketball",
    layout: "sideBySide",
    team1: RemoteControlScoreboardTeam(
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
    team2: RemoteControlScoreboardTeam(
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
    global: RemoteControlScoreboardGlobalStats(
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

private let genericConfig = RemoteControlScoreboardMatchConfig(
    sportId: "generic",
    layout: "stacked",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
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

private let genericSetsConfig = RemoteControlScoreboardMatchConfig(
    sportId: "generic sets",
    layout: "stacked",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false,
        secondaryScore: "0"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false,
        secondaryScore: "0"
    ),
    global: RemoteControlScoreboardGlobalStats(
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

private let hockeyConfig = RemoteControlScoreboardMatchConfig(
    sportId: "hockey",
    layout: "sideBySide",
    team1: RemoteControlScoreboardTeam(
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
    team2: RemoteControlScoreboardTeam(
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
    global: RemoteControlScoreboardGlobalStats(
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

private let footballConfig = RemoteControlScoreboardMatchConfig(
    sportId: "football",
    layout: "stacked",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: false
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: "#dc2626",
        textColor: "#ffffff",
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "VARSITY FOOTBALL",
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

private let tennisConfig = RemoteControlScoreboardMatchConfig(
    sportId: "tennis",
    layout: "stackHistory",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: true
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: "#dc2626",
        textColor: "#ffffff",
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
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

private let volleyballConfig = RemoteControlScoreboardMatchConfig(
    sportId: "volleyball",
    layout: "stacked",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: "#1e40af",
        possession: true,
        secondaryScore: "0",
        stat1: "0",
        stat1Label: "TO"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: "#dc2626",
        possession: false,
        secondaryScore: "0",
        stat1: "0",
        stat1Label: "TO"
    ),
    global: RemoteControlScoreboardGlobalStats(
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

private let configs: [String: RemoteControlScoreboardMatchConfig] = [
    "basketball": basketballConfig,
    "generic": genericConfig,
    "generic sets": genericSetsConfig,
    "hockey": hockeyConfig,
    "football": footballConfig,
    "tennis": tennisConfig,
    "volleyball": volleyballConfig,
]

extension Model {
    func getCurrentConfig() -> RemoteControlScoreboardMatchConfig {
        let scoreboard = database.widgets.first(where: { $0.type == .scoreboard })?.scoreboard
        let sportId: String
        switch scoreboard?.sport {
        case .basketball:
            sportId = "basketball"
        case .generic2:
            sportId = "generic"
        case .genericSets:
            sportId = "generic sets"
        case .hockey:
            sportId = "hockey"
        case .football:
            sportId = "football"
        case .tennis:
            sportId = "tennis"
        case .volleyball:
            sportId = "volleyball"
        default:
            sportId = "generic"
        }
        var liveConfig: RemoteControlScoreboardMatchConfig
        if let current = scoreboard?.modular.config, current.sportId == sportId {
            liveConfig = current
        } else if let loaded = configs[sportId] {
            liveConfig = loaded
            scoreboard?.modular.config = loaded
        } else {
            return RemoteControlScoreboardMatchConfig(
                sportId: "error",
                layout: "stacked",
                team1: RemoteControlScoreboardTeam(
                    name: "FILE MISSING",
                    bgColor: "#000000",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0"
                ),
                team2: RemoteControlScoreboardTeam(
                    name: "ERROR",
                    bgColor: "#000000",
                    textColor: "#ffffff",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0"
                ),
                global: RemoteControlScoreboardGlobalStats(
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
            switch scoreboard.modular.layout {
            case .sideBySide:
                liveConfig.layout = "sideBySide"
            case .stackHistory:
                liveConfig.layout = "stackHistory"
            case .stackedInline:
                liveConfig.layout = "stackedInline"
            default:
                liveConfig.layout = "stacked"
            }
            liveConfig.global.showTitle = scoreboard.modular.showTitle
            liveConfig.global.titleTop = scoreboard.modular.titleAbove
            liveConfig.global.showStats = scoreboard.modular.showGlobalStatsBlock
            liveConfig.global.showSecondaryRow = scoreboard.modular.showSecondaryRows
            liveConfig.team1.name = scoreboard.modular.home
            liveConfig.team2.name = scoreboard.modular.away
            liveConfig.global.title = scoreboard.modular.title
            if !scoreboard.modular.period.isEmpty {
                liveConfig.global.period = scoreboard.modular.period
            }
            if liveConfig.global.scoringMode != "tennis" {
                liveConfig.team1.primaryScore = String(scoreboard.modular.score.home)
                liveConfig.team2.primaryScore = String(scoreboard.modular.score.away)
            }
            liveConfig.global.timer = scoreboard.modular.clock()
            liveConfig.global.timerDirection = (scoreboard.modular.clockDirection == .down) ? "down" : "up"
            liveConfig.global.duration = scoreboard.modular.clockMaximum
            liveConfig.team1.bgColor = scoreboard.modular.homeBgColor.toHex()
            liveConfig.team1.textColor = scoreboard.modular.homeTextColor.toHex()
            liveConfig.team2.bgColor = scoreboard.modular.awayBgColor.toHex()
            liveConfig.team2.textColor = scoreboard.modular.awayTextColor.toHex()
        }
        return liveConfig
    }

    func getScoreboardSports() -> [String] {
        let sports = configs.keys
        let topPriority = ["generic", "generic sets"]
        let rest = sports.filter { !topPriority.contains($0) }.sorted()
        let finalSports = topPriority.filter { sports.contains($0) } + rest
        return finalSports.isEmpty ? ["volleyball", "basketball"] : finalSports
    }

    func updateScoreboardEffect(widget: SettingsWidget) {
        DispatchQueue.main.async {
            self.getScoreboardEffect(id: widget.id)?
                .update(scoreboard: widget.scoreboard,
                        config: self.getCurrentConfig(),
                        players: self.database.scoreboardPlayers)
        }
    }

    func handleScoreboardToggleClock() {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        widget.scoreboard.modular.isClockStopped.toggle()
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleScoreboardSetDuration(minutes: Int) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let modular = widget.scoreboard.modular
        modular.clockMaximum = minutes
        if modular.clockDirection == .down {
            modular.clockMinutes = minutes
            modular.clockSeconds = 0
        }
        modular.isClockStopped = true
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleScoreboardSetClockManual(time: String) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let scoreboard = widget.scoreboard
        let parts = time.split(separator: ":")
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
            let modular = scoreboard.modular
            modular.clockMinutes = m
            modular.clockSeconds = s
            modular.isClockStopped = true
        }
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleExternalScoreboardUpdate(config: RemoteControlScoreboardMatchConfig) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            let modular = scoreboard.modular
            modular.config = config
            switch config.sportId {
            case "basketball":
                scoreboard.sport = .basketball
            case "generic":
                scoreboard.sport = .generic2
            case "generic sets":
                scoreboard.sport = .genericSets
            case "hockey":
                scoreboard.sport = .hockey
            case "football":
                scoreboard.sport = .football
            case "tennis":
                scoreboard.sport = .tennis
            case "volleyball":
                scoreboard.sport = .volleyball
            default:
                break
            }
            switch config.layout {
            case "sideBySide":
                modular.layout = .sideBySide
            case "stackHistory":
                modular.layout = .stackHistory
            case "stackedInline":
                modular.layout = .stackedInline
            default:
                modular.layout = .stacked
            }
            if let showTitle = config.global.showTitle {
                modular.showTitle = showTitle
            }
            if let titleTop = config.global.titleTop {
                modular.titleAbove = titleTop
            }
            if let showStats = config.global.showStats {
                modular.showGlobalStatsBlock = showStats
            }
            if let show2nd = config.global.showSecondaryRow {
                modular.showSecondaryRows = show2nd
            }
            modular.home = config.team1.name
            modular.away = config.team2.name
            modular.title = config.global.title
            modular.period = config.global.period
            if let score = Int(config.team1.primaryScore) {
                modular.score.home = score
            }
            if let score = Int(config.team2.primaryScore) {
                modular.score.away = score
            }
            modular.homeBgColor = RgbColor.fromHex(string: config.team1.bgColor) ?? modular.homeBgColor
            modular.homeTextColor = RgbColor.fromHex(string: config.team1.textColor) ?? modular.homeTextColor
            modular.awayBgColor = RgbColor.fromHex(string: config.team2.bgColor) ?? modular.awayBgColor
            modular.awayTextColor = RgbColor.fromHex(string: config.team2.textColor) ?? modular.awayTextColor
            modular.loadColors()
            let parts = config.global.timer.split(separator: ":")
            if parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]) {
                modular.clockMinutes = minutes
                modular.clockSeconds = seconds
            }
            modular.clockDirection = (config.global.timerDirection == "down") ? .down : .up
            updateScoreboardEffect(widget: widget)
        }
        remoteControlScoreboardUpdate()
    }

    func handleSportSwitch(sportId: String) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            switch sportId {
            case "basketball":
                scoreboard.sport = .basketball
            case "generic":
                scoreboard.sport = .generic2
            case "generic sets":
                scoreboard.sport = .genericSets
            case "hockey":
                scoreboard.sport = .hockey
            case "football":
                scoreboard.sport = .football
            case "tennis":
                scoreboard.sport = .tennis
            case "volleyball":
                scoreboard.sport = .volleyball
            default:
                break
            }
            if let config = configs[sportId] {
                let modular = scoreboard.modular
                modular.config = config
                switch config.layout {
                case "sideBySide":
                    modular.layout = .sideBySide
                    modular.showSecondaryRows = true
                    modular.showGlobalStatsBlock = true
                case "stackHistory":
                    modular.layout = .stackHistory
                    modular.showSecondaryRows = false
                    modular.showGlobalStatsBlock = false
                default:
                    modular.layout = .stacked
                    modular.showSecondaryRows = false
                    modular.showGlobalStatsBlock = false
                }
                modular.showTitle = false
                modular.showTitle = false
                modular.score.home = Int(config.team1.primaryScore) ?? 0
                modular.score.away = Int(config.team2.primaryScore) ?? 0
                modular.period = config.global.period
                let parts = config.global.timer.split(separator: ":")
                if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                    modular.clockMinutes = m
                    modular.clockSeconds = s
                    modular.clockMaximum = m + (s > 0 ? 1 : 0)
                } else {
                    modular.clockMinutes = 0
                    modular.clockSeconds = 0
                }
                modular.clockDirection = (config.global.timerDirection == "down") ? .down : .up
                modular.isClockStopped = true
                modular.homeBgColor = RgbColor.fromHex(string: config.team1.bgColor) ?? modular.homeBgColor
                modular.homeTextColor = RgbColor.fromHex(string: config.team1.textColor) ?? modular
                    .homeTextColor
                modular.awayBgColor = RgbColor.fromHex(string: config.team2.bgColor) ?? modular.awayBgColor
                modular.awayTextColor = RgbColor.fromHex(string: config.team2.textColor) ?? modular
                    .awayTextColor
                modular.loadColors()
                updateScoreboardEffect(widget: widget)
                remoteControlScoreboardUpdate()
            }
        }
    }
}
