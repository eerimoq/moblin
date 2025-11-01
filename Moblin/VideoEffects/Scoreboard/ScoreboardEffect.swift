import AVFoundation
import SwiftUI
import UIKit
import Vision

private struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    let home: Int
    let away: Int

    func isHomeWin() -> Bool {
        return isSetWin(first: home, second: away)
    }

    func isAwayWin() -> Bool {
        return isSetWin(first: away, second: home)
    }
}

private struct PadelScoreboardPlayer: Identifiable {
    let id: UUID = .init()
    let name: String
}

private struct PadelScoreboardTeam {
    let players: [PadelScoreboardPlayer]
}

private struct PadelScoreboard {
    let home: PadelScoreboardTeam
    let away: PadelScoreboardTeam
    let score: [PadelScoreboardScore]
}

private struct TeamScoreView: View {
    var score: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(String(score))
            Spacer(minLength: 0)
        }
    }
}

private struct PoweredByMoblinView: View {
    var body: some View {
        HStack {
            Text("Powered by Moblin")
                .fontDesign(.monospaced)
                .font(.system(size: 15))
                .bold()
            Spacer()
        }
        .padding([.leading, .trailing], 3)
        .padding([.bottom], 3)
        .background(scoreboardDarkBlueColor)
    }
}

private func createPadelPlayer(players: [SettingsWidgetScoreboardPlayer], id: UUID) -> PadelScoreboardPlayer {
    return PadelScoreboardPlayer(name: findScoreboardPlayer(players: players, id: id))
}

private func findScoreboardPlayer(players: [SettingsWidgetScoreboardPlayer], id: UUID) -> String {
    return players.first(where: { $0.id == id })?.name ?? "🇸🇪 Moblin"
}

private func padelScoreboardSettingsToEffect(_ scoreboard: SettingsWidgetPadelScoreboard,
                                             _ players: [SettingsWidgetScoreboardPlayer]) -> PadelScoreboard
{
    var homePlayers = [createPadelPlayer(players: players, id: scoreboard.homePlayer1)]
    var awayPlayers = [createPadelPlayer(players: players, id: scoreboard.awayPlayer1)]
    if scoreboard.type == .doubles {
        homePlayers.append(createPadelPlayer(players: players, id: scoreboard.homePlayer2))
        awayPlayers.append(createPadelPlayer(players: players, id: scoreboard.awayPlayer2))
    }
    let home = PadelScoreboardTeam(players: homePlayers)
    let away = PadelScoreboardTeam(players: awayPlayers)
    let score = scoreboard.score.map { PadelScoreboardScore(home: $0.home, away: $0.away) }
    return PadelScoreboard(home: home, away: away, score: score)
}

final class ScoreboardEffect: VideoEffect {
    private var scoreboardImage: CIImage?

    override func getName() -> String {
        return "scoreboard"
    }

    @MainActor
    func update(scoreboard: SettingsWidgetScoreboard, players: [SettingsWidgetScoreboardPlayer]) {
        switch scoreboard.type {
        case .padel:
            updatePadel(padel: scoreboard.padel, players: players)
        case .generic:
            updateGeneric(generic: scoreboard.generic)
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard var scoreboardImage else {
            return image
        }
        let scale = image.extent.size.maximum() / 1920
        scoreboardImage = scoreboardImage.scaled(x: scale, y: scale)
        return scoreboardImage
            .translated(x: 10 * scale, y: image.extent.height - scoreboardImage.extent.height - 10 * scale)
            .composited(over: image)
    }

    private func setScoreboardImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.scoreboardImage = image
        }
    }

    @MainActor
    private func updatePadel(padel: SettingsWidgetPadelScoreboard, players: [SettingsWidgetScoreboardPlayer]) {
        let scoreboard = padelScoreboardSettingsToEffect(padel, players)
        let scoreBoard = VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        ForEach(scoreboard.home.players) { player in
                            Text(player.name.uppercased())
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        ForEach(scoreboard.away.players) { player in
                            Text(player.name.uppercased())
                        }
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: 25))
                ForEach(scoreboard.score) { score in
                    VStack {
                        TeamScoreView(score: score.home)
                            .bold(score.isHomeWin())
                        TeamScoreView(score: score.away)
                            .bold(score.isAwayWin())
                    }
                    .frame(width: 28)
                    .font(.system(size: 45))
                }
                Spacer()
            }
            .padding([.leading, .trailing], 3)
            .padding([.top], 3)
            .background(scoreboardBlueColor)
            PoweredByMoblinView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundColor(.white)
        let renderer = ImageRenderer(content: scoreBoard)
        guard let image = renderer.uiImage else {
            return
        }
        setScoreboardImage(image: CIImage(image: image))
    }

    @MainActor
    private func updateGeneric(generic: SettingsWidgetGenericScoreboard) {
        let scoreBoard = VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(generic.title)
                Spacer()
                Text(generic.clock())
                    .monospacedDigit()
                    .font(.system(size: 25))
            }
            .padding(5)
            .background(scoreboardDarkBlueColor)
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        Text(generic.home.uppercased())
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        Text(generic.away.uppercased())
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: 25))
                Spacer()
                VStack {
                    TeamScoreView(score: generic.score.home)
                    TeamScoreView(score: generic.score.away)
                }
                .frame(width: 28)
                .font(.system(size: 45))
            }
            .padding([.leading, .trailing], 5)
            .background(scoreboardBlueColor)
            PoweredByMoblinView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundColor(.white)
        let renderer = ImageRenderer(content: scoreBoard)
        guard let image = renderer.uiImage else {
            return
        }
        setScoreboardImage(image: CIImage(image: image))
    }
}
