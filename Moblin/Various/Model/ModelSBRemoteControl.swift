import Foundation
import Network

extension Model {
    func setupSBRemoteControlServer() {
        sbRemoteControlServer.onMessageReceived = { [weak self] message in
            // Route based on message type
            if message.type == "update-match", let config = message.updates {
                self?.handleExternalScoreboardUpdate(config: config)
            } else if message.type == "request-sync" {
                self?.broadcastCurrentState()
            }
        }
        
        sbRemoteControlServer.onClientConnected = { [weak self] connection in
            self?.syncCurrentStateToRemote(connection: connection)
        }
        
        sbRemoteControlServer.start()
    }

    func handleExternalScoreboardUpdate(config: SBMatchConfig) {
        self.externalScoreboard = config
        
        for widget in database.widgets where widget.type == .scoreboard {
            let sb = widget.scoreboard
            sb.generic.home = config.team1.name
            sb.generic.away = config.team2.name
            sb.generic.score.home = config.team1.setScore
            sb.generic.score.away = config.team2.setScore
            sb.generic.title = "Match: \(config.team1.matchScore) - \(config.team2.matchScore)"

            if let effect = scoreboardEffects[widget.id] {
                DispatchQueue.main.async {
                    effect.update(scoreboard: sb, players: self.database.scoreboardPlayers)
                }
            }
        }
        
        broadcastCurrentState()
        //self.sendScoreboardToWatch()
    }

    func syncCurrentStateToRemote(connection: NWConnection) {
        let message = SBMessage(type: "update-match", updates: getCurrentConfig())
        if let data = try? JSONEncoder().encode(message), let jsonString = String(data: data, encoding: .utf8) {
            sbRemoteControlServer.sendMessageString(connection: connection, message: jsonString)
        }
    }

    private func broadcastCurrentState() {
        let message = SBMessage(type: "update-match", updates: getCurrentConfig())
        if let data = try? JSONEncoder().encode(message), let jsonString = String(data: data, encoding: .utf8) {
            sbRemoteControlServer.broadcastMessageString(jsonString)
        }
    }

    private func getCurrentConfig() -> SBMatchConfig {
        if let current = self.externalScoreboard {
            return current
        } else {
            let widget = database.widgets.first(where: { $0.type == .scoreboard })
            return SBMatchConfig(
                matchId: "moblin",
                layout: "stacked",
                team1: SBTeam(name: widget?.scoreboard.generic.home ?? "TEAM 1",
                              bgColor: "#1e40af", textColor: "#ffffff",
                              setScore: widget?.scoreboard.generic.score.home ?? 0,
                              matchScore: 0, serving: true),
                team2: SBTeam(name: widget?.scoreboard.generic.away ?? "TEAM 2",
                              bgColor: "#dc2626", textColor: "#ffffff",
                              setScore: widget?.scoreboard.generic.score.away ?? 0,
                              matchScore: 0, serving: false)
            )
        }
    }
    
    func broadcastStreamStats() {
        let stats = SBStreamStats(
            battery: "\(Int(battery.level * 100))%",
            system: systemMonitor.format(), // e.g. "12% 450 MB"
            bitrate: bitrate.speedMbpsOneDecimal,
            bonding: bonding.statistics,
            rtts: bonding.rtts,
            uptime: streamUptime.uptime
        )
        
        let message = SBMessage(type: "stream-stats", stats: stats)
        if let data = try? JSONEncoder().encode(message),
           let jsonString = String(data: data, encoding: .utf8) {
            sbRemoteControlServer.broadcastMessageString(jsonString)
        }
    }
}
