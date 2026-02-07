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
        timer: "0:00",
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
        timer: "0:00",
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
        timer: "0:00",
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
    @MainActor
    func handleUpdatePadelScoreboard(action: WatchProtocolPadelScoreboardAction) {
        guard let scoreboard = findWidget(id: action.id)?.scoreboard else {
            return
        }
        switch action.action {
        case .reset:
            handleUpdatePadelScoreboardReset(scoreboard: scoreboard.padel)
        case .undo:
            handleUpdatePadelScoreboardUndo(scoreboard: scoreboard.padel)
        case .incrementHome:
            handleUpdatePadelScoreboardIncrementHome(scoreboard: scoreboard.padel)
        case .incrementAway:
            handleUpdatePadelScoreboardIncrementAway(scoreboard: scoreboard.padel)
        case let .players(players):
            handleUpdatePadelScoreboardChangePlayers(scoreboard: scoreboard.padel,
                                                     players: players)
        }
        guard let scoreboardEffect = scoreboardEffects[action.id] else {
            return
        }
        scoreboardEffect.update(scoreboard: scoreboard,
                                config: getModularScoreboardConfig(scoreboard: scoreboard),
                                players: database.scoreboardPlayers)
        sendUpdatePadelScoreboardToWatch(id: action.id, padel: scoreboard.padel)
    }

    @MainActor
    func handleUpdateGenericScoreboard(action: WatchProtocolGenericScoreboardAction) {
        guard let scoreboard = findWidget(id: action.id)?.scoreboard else {
            return
        }
        switch action.action {
        case .reset:
            handleUpdateGenericScoreboardReset(scoreboard: scoreboard.generic)
        case .undo:
            handleUpdateGenericScoreboardUndo(scoreboard: scoreboard.generic)
        case .incrementHome:
            handleUpdateGenericScoreboardIncrementHome(scoreboard: scoreboard.generic)
        case .incrementAway:
            handleUpdateGenericScoreboardIncrementAway(scoreboard: scoreboard.generic)
        case let .setTitle(title):
            handleUpdateGenericScoreboardSetTitle(
                scoreboard: scoreboard.generic,
                title: title
            )
        case let .setClock(minutes, seconds):
            handleUpdateGenericScoreboardSetClock(scoreboard: scoreboard.generic,
                                                  minutes: minutes,
                                                  seconds: seconds)
        case let .setClockState(stopped: stopped):
            handleUpdateGenericScoreboardSetClockState(scoreboard: scoreboard.generic,
                                                       stopped: stopped)
        }
        guard let scoreboardEffect = scoreboardEffects[action.id] else {
            return
        }
        scoreboardEffect.update(scoreboard: scoreboard,
                                config: getModularScoreboardConfig(scoreboard: scoreboard),
                                players: database.scoreboardPlayers)
        sendUpdateGenericScoreboardToWatch(id: action.id, generic: scoreboard.generic)
    }

    func getEnabledScoreboardWidgetsInSelectedScene() -> [SettingsWidget] {
        if let scene = getSelectedScene() {
            return getSceneWidgets(scene: scene, onlyEnabled: true)
                .filter { $0.widget.type == .scoreboard }
                .map { $0.widget }
        } else {
            return []
        }
    }

    func updateScoreboardEffects() {
        for widget in getEnabledScoreboardWidgetsInSelectedScene() {
            guard let effect = scoreboardEffects[widget.id] else {
                continue
            }
            let scoreboard = widget.scoreboard
            switch scoreboard.sport {
            case .padel:
                break
            case .generic:
                guard !scoreboard.generic.clock.isStopped else {
                    continue
                }
                scoreboard.generic.clock.tick()
                DispatchQueue.main.async {
                    effect.update(
                        scoreboard: scoreboard,
                        config: self.getModularScoreboardConfig(scoreboard: scoreboard),
                        players: self.database.scoreboardPlayers
                    )
                }
                sendUpdateGenericScoreboardToWatch(id: widget.id, generic: scoreboard.generic)
            default:
                guard !scoreboard.modular.clock.isStopped else {
                    continue
                }
                widget.scoreboard.modular.clock.tick()
                DispatchQueue.main.async {
                    effect.update(
                        scoreboard: scoreboard,
                        config: self.getModularScoreboardConfig(scoreboard: scoreboard),
                        players: self.database.scoreboardPlayers
                    )
                }
                remoteControlScoreboardUpdate(scoreboard: scoreboard)
            }
        }
    }

    func getModularScoreboardConfig(scoreboard: SettingsWidgetScoreboard?)
        -> RemoteControlScoreboardMatchConfig
    {
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
                    timer: "0:00",
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
                        config: self.getModularScoreboardConfig(scoreboard: widget.scoreboard),
                        players: self.database.scoreboardPlayers)
        }
    }

    func handleScoreboardToggleClock() {
        guard let widget = getEnabledScoreboardWidgetsInSelectedScene().first else {
            return
        }
        widget.scoreboard.modular.clock.isStopped.toggle()
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate(scoreboard: widget.scoreboard)
    }

    func handleScoreboardSetDuration(minutes: Int) {
        guard let widget = getEnabledScoreboardWidgetsInSelectedScene().first else {
            return
        }
        let clock = widget.scoreboard.modular.clock
        clock.maximum = minutes
        clock.reset()
        clock.isStopped = true
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate(scoreboard: widget.scoreboard)
    }

    func handleScoreboardSetClockManual(time: String) {
        guard let widget = getEnabledScoreboardWidgetsInSelectedScene().first else {
            return
        }
        let (minutes, seconds) = clockAsMinutesAndSeconds(clock: time)
        let clock = widget.scoreboard.modular.clock
        clock.minutes = minutes
        clock.seconds = seconds
        clock.isStopped = true
        updateScoreboardEffect(widget: widget)
        remoteControlScoreboardUpdate(scoreboard: widget.scoreboard)
    }

    func handleExternalScoreboardUpdate(config: RemoteControlScoreboardMatchConfig) {
        guard let widget = getEnabledScoreboardWidgetsInSelectedScene().first else {
            return
        }
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
        remoteControlScoreboardUpdate(scoreboard: scoreboard)
    }

    func handleSportSwitch(sportId: String) {
        guard let widget = getEnabledScoreboardWidgetsInSelectedScene().first else {
            return
        }
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
            remoteControlScoreboardUpdate(scoreboard: scoreboard)
        }
    }

    private func handleUpdatePadelScoreboardReset(scoreboard: SettingsWidgetPadelScoreboard) {
        scoreboard.score = [.init()]
        scoreboard.scoreChanges.removeAll()
    }

    private func handleUpdatePadelScoreboardUndo(scoreboard: SettingsWidgetPadelScoreboard) {
        guard let team = scoreboard.scoreChanges.popLast() else {
            return
        }
        guard let score = scoreboard.score.last else {
            return
        }
        if score.home == 0, score.away == 0, scoreboard.score.count > 1 {
            scoreboard.score.removeLast()
        }
        let index = scoreboard.score.count - 1
        switch team {
        case .home:
            if scoreboard.score[index].home > 0 {
                scoreboard.score[index].home -= 1
            }
        case .away:
            if scoreboard.score[index].away > 0 {
                scoreboard.score[index].away -= 1
            }
        }
    }

    private func handleUpdatePadelScoreboardIncrementHome(scoreboard: SettingsWidgetPadelScoreboard) {
        if !isCurrentSetCompleted(scoreboard: scoreboard) {
            guard !isMatchCompleted(scoreboard: scoreboard) else {
                return
            }
            scoreboard.score[scoreboard.score.count - 1].home += 1
            scoreboard.scoreChanges.append(.home)
        } else {
            padelScoreboardUpdateSetCompleted(scoreboard: scoreboard)
        }
    }

    private func handleUpdatePadelScoreboardIncrementAway(scoreboard: SettingsWidgetPadelScoreboard) {
        if !isCurrentSetCompleted(scoreboard: scoreboard) {
            guard !isMatchCompleted(scoreboard: scoreboard) else {
                return
            }
            scoreboard.score[scoreboard.score.count - 1].away += 1
            scoreboard.scoreChanges.append(.away)
        } else {
            padelScoreboardUpdateSetCompleted(scoreboard: scoreboard)
        }
    }

    private func handleUpdatePadelScoreboardChangePlayers(scoreboard: SettingsWidgetPadelScoreboard,
                                                          players: WatchProtocolPadelScoreboardActionPlayers)
    {
        if players.home.count > 0 {
            scoreboard.homePlayer1 = players.home[0]
            if players.home.count > 1 {
                scoreboard.homePlayer2 = players.home[1]
            }
        }
        if players.away.count > 0 {
            scoreboard.awayPlayer1 = players.away[0]
            if players.away.count > 1 {
                scoreboard.awayPlayer2 = players.away[1]
            }
        }
    }

    private func handleUpdateGenericScoreboardReset(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.home = 0
        scoreboard.score.away = 0
        scoreboard.scoreChanges.removeAll()
    }

    private func handleUpdateGenericScoreboardUndo(scoreboard: SettingsWidgetGenericScoreboard) {
        guard let team = scoreboard.scoreChanges.popLast() else {
            return
        }
        switch team {
        case .home:
            if scoreboard.score.home > 0 {
                scoreboard.score.home -= 1
            }
        case .away:
            if scoreboard.score.away > 0 {
                scoreboard.score.away -= 1
            }
        }
    }

    private func handleUpdateGenericScoreboardIncrementHome(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.home += 1
        scoreboard.scoreChanges.append(.home)
    }

    private func handleUpdateGenericScoreboardIncrementAway(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.away += 1
        scoreboard.scoreChanges.append(.away)
    }

    private func handleUpdateGenericScoreboardSetTitle(scoreboard: SettingsWidgetGenericScoreboard,
                                                       title: String)
    {
        scoreboard.title = title
    }

    private func handleUpdateGenericScoreboardSetClock(scoreboard: SettingsWidgetGenericScoreboard,
                                                       minutes: Int,
                                                       seconds: Int)
    {
        scoreboard.clock.minutes = minutes.clamped(to: 0 ... scoreboard.clock.maximum)
        if scoreboard.clock.minutes == scoreboard.clock.maximum {
            scoreboard.clock.seconds = 0
        } else {
            scoreboard.clock.seconds = seconds.clamped(to: 0 ... 59)
        }
    }

    private func handleUpdateGenericScoreboardSetClockState(scoreboard: SettingsWidgetGenericScoreboard,
                                                            stopped: Bool)
    {
        scoreboard.clock.isStopped = stopped
    }

    private func padelScoreboardUpdateSetCompleted(scoreboard: SettingsWidgetPadelScoreboard) {
        guard let score = scoreboard.score.last else {
            return
        }
        guard isSetCompleted(score: score) else {
            return
        }
        guard !isMatchCompleted(scoreboard: scoreboard) else {
            return
        }
        scoreboard.score.append(.init())
    }

    private func isCurrentSetCompleted(scoreboard: SettingsWidgetPadelScoreboard) -> Bool {
        guard let score = scoreboard.score.last else {
            return false
        }
        return isSetCompleted(score: score)
    }

    private func isSetCompleted(score: SettingsWidgetScoreboardScore) -> Bool {
        let maxScore = max(score.home, score.away)
        let minScore = min(score.home, score.away)
        if maxScore == 6 && minScore <= 4 {
            return true
        }
        if maxScore == 7 {
            return true
        }
        return false
    }

    private func isMatchCompleted(scoreboard: SettingsWidgetPadelScoreboard) -> Bool {
        if scoreboard.score.count < 5 {
            return false
        }
        guard let score = scoreboard.score.last else {
            return false
        }
        return isSetCompleted(score: score)
    }
}
