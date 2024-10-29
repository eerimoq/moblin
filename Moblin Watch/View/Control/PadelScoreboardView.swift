import SwiftUI

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
    @EnvironmentObject var model: Model
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
    }
}

private struct ScoreboardView: View {
    @Binding var scoreboard: PadelScoreboard

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                TeamPlayersView(players: $scoreboard.home.players)
                TeamPlayersView(players: $scoreboard.away.players)
            }
            ForEach(scoreboard.score) { score in
                VStack {
                    TeamScoreView(score: score.home)
                        .bold(score.isHomeWin())
                    TeamScoreView(score: score.away)
                        .bold(score.isAwayWin())
                }
                .frame(width: 17)
            }
            Spacer()
        }
        .padding([.leading, .trailing], 2)
        .padding([.top], 2)
        .background(scoreboardBlueColor)
        .foregroundColor(.white)
    }
}

private struct PlayerPickerView: View {
    @EnvironmentObject var model: Model
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
                    ForEach(model.scoreboardPlayers) { player in
                        Text(player.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .onChange(of: player.id) { _, _ in
                isPresentingPlayerPicker = false
                model.updatePadelScoreboard()
            }
        }
    }
}

private struct TeamPickerView: View {
    let side: String
    @Binding var team: PadelScoreboardTeam

    var body: some View {
        Text(side)
        PlayerPickerView(player: $team.players[0])
        if team.players.count > 1 {
            PlayerPickerView(player: $team.players[1])
        }
    }
}

private struct PadelScoreboardUndoButtonView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.padelScoreboardUndoScore()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
    }
}

private struct PadelScoreboardIncrementHomeButtonView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.padelScoreboardIncrementHomeScore()
        } label: {
            Image(systemName: "plus")
        }
        .tint(model.padelScoreboardIncrementTintColor)
    }
}

private struct PadelScoreboardIncrementAwayButtonView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.padelScoreboardIncrementAwayScore()
        } label: {
            Image(systemName: "plus")
        }
        .tint(model.padelScoreboardIncrementTintColor)
    }
}

private struct PadelScoreboardResetScoreButtonView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingResetConfirimation = false

    var body: some View {
        Button {
            isPresentingResetConfirimation = true
        } label: {
            Image(systemName: "trash")
        }
        .confirmationDialog("", isPresented: $isPresentingResetConfirimation) {
            Button("Reset score") {
                model.resetPadelScoreBoard()
            }
            Button("Cancel") {}
        }
        .tint(.red)
    }
}

struct PadelScoreboardView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ScoreboardView(scoreboard: $model.padelScoreboard)
                HStack {
                    PadelScoreboardUndoButtonView()
                    PadelScoreboardIncrementHomeButtonView()
                }
                HStack {
                    PadelScoreboardResetScoreButtonView()
                    PadelScoreboardIncrementAwayButtonView()
                }
                TeamPickerView(side: String(localized: "Home"), team: $model.padelScoreboard.home)
                TeamPickerView(side: String(localized: "Away"), team: $model.padelScoreboard.away)
                Spacer()
            }
            .padding()
        }
        .ignoresSafeArea()
    }
}
