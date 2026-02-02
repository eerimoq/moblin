import Foundation
import Network

private let homeBackgroundColor = "#1e40af"
private let awayBackgroundColor = "#dc2626"

private let basketballConfig = RemoteControlScoreboardMatchConfig(
    sportId: "basketball",
    layout: "sideBySide",
    team1: RemoteControlScoreboardTeam(
        name: "Home",
        bgColor: homeBackgroundColor,
        possession: true,
        stat1: "5",
        stat1Label: "TO",
        stat2: "0",
        stat2Label: "FOUL",
        stat3: "NO BONUS"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        possession: false,
        stat1: "5",
        stat1Label: "TO",
        stat2: "0",
        stat2Label: "FOUL",
        stat3: "NO BONUS"
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "Varsity Basketball",
        timer: "10:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "QTR",
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
        bgColor: homeBackgroundColor,
        possession: false
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "",
        timer: "",
        timerDirection: "down",
        period: "",
        periodLabel: "",
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
        bgColor: homeBackgroundColor,
        possession: false,
        secondaryScore: "0"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        possession: false,
        secondaryScore: "0"
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "GENERIC MATCH",
        timer: "00:00",
        timerDirection: "up",
        period: "1",
        periodLabel: "SET",
        primaryScoreResetOnPeriod: true,
        secondaryScoreResetOnPeriod: false,
        changePossessionOnScore: false,
        showTitle: false,
        showStats: false,
        showMoreStats: false
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
        bgColor: homeBackgroundColor,
        possession: false,
        secondaryScore: "0",
        secondaryScoreLabel: "SOG",
        stat1: "NO PP",
        stat2: "NO EN",
        stat3: "NO DP"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        textColor: "#ffffff",
        possession: false,
        secondaryScore: "0",
        secondaryScoreLabel: "SOG",
        stat1: "NO PP",
        stat2: "NO EN",
        stat3: "NO DP"
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "Varsity Hockey",
        timer: "15:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "PER",
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
        bgColor: homeBackgroundColor,
        possession: false
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        textColor: "#ffffff",
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "VARSITY FOOTBALL",
        timer: "30:00",
        timerDirection: "down",
        period: "1",
        periodLabel: "HALF",
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
        bgColor: homeBackgroundColor,
        possession: true
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
        textColor: "#ffffff",
        possession: false
    ),
    global: RemoteControlScoreboardGlobalStats(
        title: "TENNIS",
        timer: "00:00",
        timerDirection: "up",
        period: "1",
        periodLabel: "SET",
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
        bgColor: homeBackgroundColor,
        possession: true,
        secondaryScore: "0",
        stat1: "0",
        stat1Label: "TO"
    ),
    team2: RemoteControlScoreboardTeam(
        name: "Away",
        bgColor: awayBackgroundColor,
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
        var config: RemoteControlScoreboardMatchConfig
        if let current = scoreboard?.modular.config, current.sportId == sportId {
            config = current
        } else if let loaded = configs[sportId] {
            config = loaded
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
                    primaryScoreResetOnPeriod: false,
                    secondaryScoreResetOnPeriod: false
                ),
                controls: [:]
            )
        }
        if let modular = scoreboard?.modular {
            switch modular.layout {
            case .sideBySide:
                config.layout = "sideBySide"
            case .stackHistory:
                config.layout = "stackHistory"
            case .stackedInline:
                config.layout = "stackedInline"
            default:
                config.layout = "stacked"
            }
            config.global.showTitle = modular.showTitle
            config.global.showStats = modular.showGlobalStatsBlock
            config.global.showMoreStats = modular.showMoreStats
            config.global.title = modular.title
            config.global.timer = modular.clock.format()
            switch modular.clock.direction {
            case .up:
                config.global.timerDirection = "up"
            case .down:
                config.global.timerDirection = "down"
            }
            config.global.duration = modular.clock.maximum
            if !modular.period.isEmpty {
                config.global.period = modular.period
            }
            config.global.infoBoxText = modular.infoBoxText
            config.team1.name = modular.home.name
            config.team2.name = modular.away.name
            config.team1.textColor = modular.home.textColor.toHex()
            config.team2.textColor = modular.away.textColor.toHex()
            config.team1.bgColor = modular.home.backgroundColor.toHex()
            config.team2.bgColor = modular.away.backgroundColor.toHex()
            if config.global.scoringMode != "tennis" {
                config.team1.primaryScore = String(modular.score.home)
                config.team2.primaryScore = String(modular.score.away)
            }
        }
        return config
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
        widget.scoreboard.modular.clock.isStopped.toggle()
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleScoreboardSetDuration(minutes: Int) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let clock = widget.scoreboard.modular.clock
        clock.maximum = minutes
        clock.reset()
        clock.isStopped = true
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleScoreboardSetClockManual(time: String) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let (minutes, seconds) = clockAsMinutesAndSeconds(clock: time)
        let clock = widget.scoreboard.modular.clock
        clock.minutes = minutes
        clock.seconds = seconds
        clock.isStopped = true
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate()
    }

    func handleExternalScoreboardUpdate(config: RemoteControlScoreboardMatchConfig) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            let modular = scoreboard.modular
            modular.config = config
            scoreboard.setModularSport(sportId: config.sportId)
            modular.setLayout(name: config.layout)
            if let showTitle = config.global.showTitle {
                modular.showTitle = showTitle
            }
            if let showStats = config.global.showStats {
                modular.showGlobalStatsBlock = showStats
            }
            if let show2nd = config.global.showMoreStats {
                modular.showMoreStats = show2nd
            }
            modular.home.name = config.team1.name
            modular.away.name = config.team2.name
            modular.title = config.global.title
            modular.period = config.global.period
            modular.infoBoxText = config.global.infoBoxText
            if let score = Int(config.team1.primaryScore) {
                modular.score.home = score
            }
            if let score = Int(config.team2.primaryScore) {
                modular.score.away = score
            }
            modular.home.setHexColors(config.team1.textColor, config.team1.bgColor)
            modular.away.setHexColors(config.team2.textColor, config.team2.bgColor)
            let (minutes, seconds) = config.global.minutesAndSeconds()
            modular.clock.minutes = minutes
            modular.clock.seconds = seconds
            modular.clock.direction = (config.global.timerDirection == "down") ? .down : .up
            updateScoreboardEffect(widget: widget)
        }
        remoteControlScoreboardUpdate()
    }

    func handleSportSwitch(sportId: String) {
        for widget in database.widgets where widget.type == .scoreboard {
            let scoreboard = widget.scoreboard
            scoreboard.setModularSport(sportId: sportId)
            if let config = configs[sportId] {
                let modular = scoreboard.modular
                modular.config = config
                modular.setLayout(name: config.layout)
                modular.score.home = Int(config.team1.primaryScore) ?? 0
                modular.score.away = Int(config.team2.primaryScore) ?? 0
                modular.period = config.global.period
                let (minutes, seconds) = config.global.minutesAndSeconds()
                modular.clock.minutes = minutes
                modular.clock.seconds = seconds
                modular.clock.maximum = minutes + (seconds > 0 ? 1 : 0)
                modular.clock.direction = (config.global.timerDirection == "down") ? .down : .up
                modular.clock.isStopped = true
                modular.home.setHexColors(config.team1.textColor, config.team1.bgColor)
                modular.away.setHexColors(config.team2.textColor, config.team2.bgColor)
                updateScoreboardEffect(widget: widget)
                remoteControlScoreboardUpdate()
            }
        }
    }
}
