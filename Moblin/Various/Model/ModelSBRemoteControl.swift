import Foundation
import Network
import SwiftUI

extension Model {
    func setupSBRemoteControlServer() {
        sbRemoteControlServer.onMessageReceived = { [weak self] message in
            guard let self = self else {
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
        let foundSports = getAvailableSports()
        logger.info("sb-remote: Startup check found sports: \(foundSports)")
    }

    private func handleAction(action: String, value: String?) {
        guard let widget = database.widgets.first(where: { $0.type == .scoreboard }) else {
            return
        }
        let sb = widget.scoreboard
        if action == "toggle-clock" {
            sb.generic.isClockStopped.toggle()
        } else if action == "set-duration", let valStr = value, let mins = Int(valStr) {
            sb.generic.clockMaximum = mins
            if sb.generic.clockDirection == .down {
                sb.generic.clockMinutes = mins
                sb.generic.clockSeconds = 0
            }
            sb.generic.isClockStopped = true
        } else if action == "set-clock-manual", let timeStr = value {
            let parts = timeStr.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                sb.generic.clockMinutes = m
                sb.generic.clockSeconds = s
                sb.generic.isClockStopped = true
            }
        }
        sceneUpdated()
        broadcastCurrentState()
    }

    func handleExternalScoreboardUpdate(config: SBMatchConfig) {
        externalScoreboard = config
        for widget in database.widgets where widget.type == .scoreboard {
            let sb = widget.scoreboard
            sb.config = config
            if sb.sportId != config.matchId {
                sb.sportId = config.matchId
            }
            switch config.layout {
            case "sideBySide":
                sb.layout = .sideBySide
            case "stackhistory":
                sb.layout = .stackhistory
            case "stackedInline":
                sb.layout = .stackedInline
            default:
                sb.layout = .stacked
            }
            if let showTitle = config.global.showTitle {
                sb.showStackedHeader = showTitle
                sb.showSbsTitle = showTitle
            }
            if let titleTop = config.global.titleTop {
                sb.titleAbove = titleTop
            }
            if let showStats = config.global.showStats {
                sb.showGlobalStatsBlock = showStats
            }
            if let show2nd = config.global.showSecondaryRow {
                sb.showSecondaryRows = show2nd
            }
            sb.generic.home = config.team1.name
            sb.generic.away = config.team2.name
            sb.generic.title = config.global.title
            sb.generic.period = config.global.period
            if let h = Int(config.team1.primaryScore) {
                sb.generic.score.home = h
            }
            if let a = Int(config.team2.primaryScore) {
                sb.generic.score.away = a
            }
            sb.team1BgColor = RgbColor.fromHex(string: config.team1.bgColor) ?? sb.team1BgColor
            sb.team1TextColor = RgbColor.fromHex(string: config.team1.textColor) ?? sb.team1TextColor
            sb.team2BgColor = RgbColor.fromHex(string: config.team2.bgColor) ?? sb.team2BgColor
            sb.team2TextColor = RgbColor.fromHex(string: config.team2.textColor) ?? sb.team2TextColor
            sb.loadColors()
            let parts = config.global.timer.split(separator: ":")
            if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                sb.generic.clockMinutes = m
                sb.generic.clockSeconds = s
            }
            sb.generic.clockDirection = (config.global.timerDirection == "down") ? .down : .up
            if let effect = scoreboardEffects[widget.id] {
                DispatchQueue.main.async {
                    effect.update(scoreboard: sb)
                }
            }
        }
        sceneUpdated()
        broadcastCurrentState()
    }

    private func handleSportSwitch(sportId: String) {
        for widget in database.widgets where widget.type == .scoreboard {
            let sb = widget.scoreboard
            sb.sportId = sportId
            if let newConfig = loadConfigFromFile(sportId: sportId) {
                sb.config = newConfig
                switch newConfig.layout {
                case "sideBySide":
                    sb.layout = .sideBySide
                    sb.showSecondaryRows = true
                    sb.showGlobalStatsBlock = true
                case "stackhistory":
                    sb.layout = .stackhistory
                    sb.showSecondaryRows = false
                    sb.showGlobalStatsBlock = false
                default:
                    sb.layout = .stacked
                    sb.showSecondaryRows = false
                    sb.showGlobalStatsBlock = false
                }
                sb.showStackedHeader = false
                sb.showSbsTitle = false
                sb.showStackedFooter = false
                sb.generic.score.home = Int(newConfig.team1.primaryScore) ?? 0
                sb.generic.score.away = Int(newConfig.team2.primaryScore) ?? 0
                sb.generic.period = newConfig.global.period
                let parts = newConfig.global.timer.split(separator: ":")
                if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                    sb.generic.clockMinutes = m
                    sb.generic.clockSeconds = s
                    sb.generic.clockMaximum = m + (s > 0 ? 1 : 0)
                } else {
                    sb.generic.clockMinutes = 0
                    sb.generic.clockSeconds = 0
                }
                sb.generic.clockDirection = (newConfig.global.timerDirection == "down") ? .down : .up
                sb.generic.isClockStopped = true
                sb.team1BgColor = RgbColor.fromHex(string: newConfig.team1.bgColor) ?? sb.team1BgColor
                sb.team1TextColor = RgbColor.fromHex(string: newConfig.team1.textColor) ?? sb.team1TextColor
                sb.team2BgColor = RgbColor.fromHex(string: newConfig.team2.bgColor) ?? sb.team2BgColor
                sb.team2TextColor = RgbColor.fromHex(string: newConfig.team2.textColor) ?? sb.team2TextColor
                sb.loadColors()
            }
        }
        externalScoreboard = nil
        sceneUpdated()
        broadcastCurrentState()
        logger.info("sb-remote: Switched to \(sportId)")
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
        let widget = database.widgets.first(where: { $0.type == .scoreboard })
        let sb = widget?.scoreboard
        let activeId = sb?.sportId ?? "volleyball"
        var liveConfig: SBMatchConfig
        if let current = sb?.config, current.matchId == activeId {
            liveConfig = current
        } else if let loaded = loadConfigFromFile(sportId: activeId) {
            liveConfig = loaded
            sb?.config = loaded
        } else {
            return SBMatchConfig(
                matchId: "error",
                layout: "stacked",
                team1: SBTeam(
                    name: "FILE MISSING",
                    bgColor: "#000",
                    textColor: "#fff",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0",
                    stat1: "",
                    stat1Label: "",
                    stat2: "",
                    stat2Label: "",
                    stat3: "",
                    stat3Label: "",
                    stat4: "",
                    stat4Label: ""
                ),
                team2: SBTeam(
                    name: "ERROR",
                    bgColor: "#000",
                    textColor: "#fff",
                    possession: false,
                    primaryScore: "0",
                    secondaryScore: "0",
                    stat1: "",
                    stat1Label: "",
                    stat2: "",
                    stat2Label: "",
                    stat3: "",
                    stat3Label: "",
                    stat4: "",
                    stat4Label: ""
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
        if let sb = sb {
            switch sb.layout {
            case .sideBySide:
                liveConfig.layout = "sideBySide"
            case .stackhistory:
                liveConfig.layout = "stackhistory"
            case .stackedInline:
                liveConfig.layout = "stackedInline"
            default:
                liveConfig.layout = "stacked"
            }
            liveConfig.global.showTitle = sb.showStackedHeader || sb.showSbsTitle
            liveConfig.global.titleTop = sb.titleAbove
            liveConfig.global.showStats = sb.showGlobalStatsBlock
            liveConfig.global.showSecondaryRow = sb.showSecondaryRows
            liveConfig.team1.name = sb.generic.home
            liveConfig.team2.name = sb.generic.away
            liveConfig.global.title = sb.generic.title
            if !sb.generic.period.isEmpty {
                liveConfig.global.period = sb.generic.period
            }
            if liveConfig.global.scoringMode != "tennis" {
                liveConfig.team1.primaryScore = String(sb.generic.score.home)
                liveConfig.team2.primaryScore = String(sb.generic.score.away)
            }
            liveConfig.global.timer = sb.generic.clock()
            liveConfig.global.timerDirection = (sb.generic.clockDirection == .down) ? "down" : "up"
            liveConfig.global.duration = sb.generic.clockMaximum // SYNC BACK
            liveConfig.team1.bgColor = sb.team1BgColor.toHex()
            liveConfig.team1.textColor = sb.team1TextColor.toHex()
            liveConfig.team2.bgColor = sb.team2BgColor.toHex()
            liveConfig.team2.textColor = sb.team2TextColor.toHex()
        }
        return liveConfig
    }

    private func loadConfigFromFile(sportId: String) -> SBMatchConfig? {
        if let path = Bundle.main.path(forResource: sportId, ofType: "json", inDirectory: "Web") ??
            Bundle.main.path(forResource: sportId, ofType: "json")
        {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let config = try? JSONDecoder().decode(SBMatchConfig.self, from: data)
            {
                return config
            }
        }
        return nil
    }

    func getAvailableSports() -> [String] {
        var sports: Set<String> = []
        let fileManager = FileManager.default
        let resourcePath = Bundle.main.resourcePath ?? ""
        let webPath = (resourcePath as NSString).appendingPathComponent("Web")
        if let files = try? fileManager.contentsOfDirectory(atPath: webPath) {
            for file in files where file.hasSuffix(".json") {
                sports.insert(file.replacingOccurrences(of: ".json", with: ""))
            }
        }
        if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
            let jsonFiles = files.filter { $0.hasSuffix(".json") }
            for file in jsonFiles {
                let name = file.replacingOccurrences(of: ".json", with: "")
                if [
                    "volleyball",
                    "basketball",
                    "hockey",
                    "soccer",
                    "football",
                    "tennis",
                    "generic",
                    "generic_sets",
                ].contains(name) || !sports.isEmpty {
                    sports.insert(name)
                } else if sports.isEmpty, !name.starts(with: "."), !name.contains("Config") {
                    sports.insert(name)
                }
            }
        }
        let topPriority = ["generic", "generic_sets"]
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
