import SwiftUI

let teamRowHeight: CGFloat = 32

class Padel: ObservableObject {
    @Published var scoreboard: PadelScoreboard = .init(
        id: .init(),
        home: .init(players: []),
        away: .init(players: []),
        score: []
    )
    @Published var players: [PadelScoreboardPlayersPlayer] = []
    @Published var incrementTintColor: Color?
}

struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    var home: Int
    var away: Int

    func isHomeWin() -> Bool {
        return isSetWin(first: home, second: away)
    }

    func isAwayWin() -> Bool {
        return isSetWin(first: away, second: home)
    }
}

struct PadelScoreboardPlayer: Identifiable {
    var id: UUID
}

struct PadelScoreboardPlayersPlayer: Identifiable {
    let id: UUID
    let name: String
}

struct PadelScoreboardTeam {
    var players: [PadelScoreboardPlayer]
}

struct PadelScoreboard {
    var id: UUID
    var home: PadelScoreboardTeam
    var away: PadelScoreboardTeam
    var score: [PadelScoreboardScore]
}

private struct TeamPlayersView: View {
    let model: Model
    @Binding var players: [PadelScoreboardPlayer]

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            ForEach(players) { player in
                Text(model.findScoreboardPlayer(id: player.id).prefix(5).uppercased())
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 15))
        .frame(height: teamRowHeight)
    }
}

private struct TeamScoreView: View {
    var score: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(String(score))
            Spacer(minLength: 0)
        }
        .font(.system(size: 30))
        .frame(height: teamRowHeight)
    }
}

private struct ScoreboardScoreboardView: View {
    let model: Model
    @Binding var scoreboard: PadelScoreboard

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                TeamPlayersView(model: model, players: $scoreboard.home.players)
                TeamPlayersView(model: model, players: $scoreboard.away.players)
            }
            .padding([.bottom], 2)
            ForEach(scoreboard.score) { score in
                VStack {
                    TeamScoreView(score: score.home)
                        .bold(score.isHomeWin())
                    TeamScoreView(score: score.away)
                        .bold(score.isAwayWin())
                }
                .frame(width: 17)
                .padding([.bottom], 2)
            }
            Spacer()
        }
        .padding([.leading, .trailing], 2)
        .padding([.top], 2)
        .background(scoreboardBlueColor)
        .foregroundStyle(.white)
    }
}

private struct PlayerPickerView: View {
    let model: Model
    @ObservedObject var padel: Padel
    @Binding var player: PadelScoreboardPlayer
    @State var isPresentingPlayerPicker = false

    var body: some View {
        Button {
            isPresentingPlayerPicker = true
        } label: {
            Text(model.findScoreboardPlayer(id: player.id))
        }
        .sheet(isPresented: $isPresentingPlayerPicker) {
            List {
                Picker("", selection: $player.id) {
                    ForEach(padel.players) { player in
                        Text(player.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .onChange(of: player.id) { _, _ in
                isPresentingPlayerPicker = false
                model.padelScoreboardUpdatePlayers()
            }
        }
    }
}

private struct TeamPickerView: View {
    let model: Model
    let padel: Padel
    let side: String
    @Binding var team: PadelScoreboardTeam

    var body: some View {
        VStack {
            Text(side)
            PlayerPickerView(model: model, padel: padel, player: $team.players[0])
            if team.players.count > 1 {
                PlayerPickerView(model: model, padel: padel, player: $team.players[1])
            }
            Spacer()
        }
    }
}

private struct ScoreboardUndoButtonView: View {
    let model: Model

    var body: some View {
        Button {
            model.padelScoreboardUndoScore()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
    }
}

private struct ScoreboardIncrementHomeButtonView: View {
    let model: Model
    @ObservedObject var padel: Padel

    var body: some View {
        Button {
            model.padelScoreboardIncrementHomeScore()
        } label: {
            Image(systemName: "plus")
        }
        .tint(padel.incrementTintColor)
    }
}

private struct ScoreboardIncrementAwayButtonView: View {
    let model: Model
    @ObservedObject var padel: Padel

    var body: some View {
        Button {
            model.padelScoreboardIncrementAwayScore()
        } label: {
            Image(systemName: "plus")
        }
        .tint(padel.incrementTintColor)
    }
}

private struct ScoreboardResetScoreButtonView: View {
    let model: Model
    @State var isPresentingResetConfirimation = false

    var body: some View {
        Button {
            isPresentingResetConfirimation = true
        } label: {
            Image(systemName: "trash")
        }
        .confirmationDialog("", isPresented: $isPresentingResetConfirimation) {
            Button("Reset score") {
                model.padelScoreBoardResetScore()
            }
            Button("Cancel") {}
        }
        .tint(.red)
    }
}

struct PadelScoreboardView: View {
    let model: Model
    @ObservedObject var padel: Padel

    var body: some View {
        TabView {
            VStack(spacing: 5) {
                ScoreboardScoreboardView(model: model, scoreboard: $padel.scoreboard)
                HStack {
                    ScoreboardUndoButtonView(model: model)
                    ScoreboardIncrementHomeButtonView(model: model, padel: padel)
                }
                HStack {
                    ScoreboardResetScoreButtonView(model: model)
                    ScoreboardIncrementAwayButtonView(model: model, padel: padel)
                }
                Spacer()
            }
            TeamPickerView(model: model, padel: padel, side: String(localized: "Home"), team: $padel.scoreboard.home)
            TeamPickerView(model: model, padel: padel, side: String(localized: "Away"), team: $padel.scoreboard.away)
        }
        .tabViewStyle(.verticalPage)
    }
}
