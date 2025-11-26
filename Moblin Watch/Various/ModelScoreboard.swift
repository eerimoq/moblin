import Collections
import Foundation
import HealthKit
import SwiftUI
import WatchConnectivity

extension Model {
    func handlePadelScoreboard(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        let scoreboard = try JSONDecoder().decode(WatchProtocolPadelScoreboard.self, from: data)
        scoreboardId = scoreboard.id
        padel.scoreboard.id = scoreboard.id
        padel.scoreboard.home = .init(players: scoreboard.home.map { .init(id: $0) })
        padel.scoreboard.away = .init(players: scoreboard.away.map { .init(id: $0) })
        padel.scoreboard.score = scoreboard.score.map { .init(home: $0.home, away: $0.away) }
        if isCurrentSetCompleted(scoreboard: scoreboard) {
            padel.incrementTintColor = .green
        } else {
            padel.incrementTintColor = nil
        }
        scoreboardType = .padel
    }

    func handleGenericScoreboard(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        let scoreboard = try JSONDecoder().decode(WatchProtocolGenericScoreboard.self, from: data)
        scoreboardId = scoreboard.id
        generic.id = scoreboard.id
        generic.homeTeam = scoreboard.homeTeam
        generic.awayTeam = scoreboard.awayTeam
        generic.homeScore = scoreboard.homeScore
        generic.awayScore = scoreboard.awayScore
        generic.clockMinutes = scoreboard.clockMinutes
        generic.clockSeconds = scoreboard.clockSeconds
        generic.clockMaximum = scoreboard.clockMaximum
        generic.isClockStopped = scoreboard.isClockStopped
        generic.title = scoreboard.title
        scoreboardType = .generic
    }

    func handleScoreboardPlayers(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        let players = try JSONDecoder().decode([WatchProtocolScoreboardPlayer].self, from: data)
        padel.players = players.map { .init(id: $0.id, name: $0.name) }
    }

    func findScoreboardPlayer(id: UUID) -> String {
        return padel.players.first(where: { $0.id == id })?.name ?? "🇸🇪 Moblin"
    }

    func padelScoreboardIncrementHomeScore() {
        sendUpdatePadelScoreboard(action: .incrementHome)
    }

    func padelScoreboardIncrementAwayScore() {
        sendUpdatePadelScoreboard(action: .incrementAway)
    }

    func padelScoreboardUndoScore() {
        sendUpdatePadelScoreboard(action: .undo)
    }

    func padelScoreBoardResetScore() {
        sendUpdatePadelScoreboard(action: .reset)
    }

    func padelScoreboardUpdatePlayers() {
        let home = padel.scoreboard.home.players.map { $0.id }
        let away = padel.scoreboard.away.players.map { $0.id }
        let players = WatchProtocolPadelScoreboardActionPlayers(home: home, away: away)
        sendUpdatePadelScoreboard(action: .players(players))
    }

    func genericScoreboardIncrementHomeScore() {
        sendUpdateGenericScoreboard(action: .incrementHome)
    }

    func genericScoreboardIncrementAwayScore() {
        sendUpdateGenericScoreboard(action: .incrementAway)
    }

    func genericScoreboardUndoScore() {
        sendUpdateGenericScoreboard(action: .undo)
    }

    func genericScoreboardResetScore() {
        sendUpdateGenericScoreboard(action: .reset)
    }

    func genericScoreboardSetClock(minutes: Int, seconds: Int) {
        sendUpdateGenericScoreboard(action: .setClock(minutes: minutes, seconds: seconds))
    }

    func genericScoreboardSetTitle(title: String) {
        sendUpdateGenericScoreboard(action: .setTitle(title: title))
    }

    func genericScoreboardSetClockState(stopped: Bool) {
        sendUpdateGenericScoreboard(action: .setClockState(stopped: stopped))
    }

    func handleRemoveScoreboard(_ data: Any) throws {
        guard let idString = data as? String, let id = UUID(uuidString: idString) else {
            return
        }
        guard scoreboardId == id else {
            return
        }
        scoreboardType = nil
    }

    private func sendUpdatePadelScoreboard(action: WatchProtocolPadelScoreboardActionType) {
        let data = WatchProtocolPadelScoreboardAction(id: padel.scoreboard.id, action: action)
        guard let data = try? JSONEncoder().encode(data) else {
            return
        }
        let message = WatchMessageFromWatch.pack(type: .updatePadelScoreboard, data: data)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    private func sendUpdateGenericScoreboard(action: WatchProtocolGenericScoreboardActionType) {
        let data = WatchProtocolGenericScoreboardAction(id: generic.id, action: action)
        guard let data = try? JSONEncoder().encode(data) else {
            return
        }
        let message = WatchMessageFromWatch.pack(type: .updateGenericScoreboard, data: data)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    private func isCurrentSetCompleted(scoreboard: WatchProtocolPadelScoreboard) -> Bool {
        guard let score = scoreboard.score.last else {
            return false
        }
        return isSetCompleted(score: score)
    }

    private func isSetCompleted(score: WatchProtocolPadelScoreboardScore) -> Bool {
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
}
