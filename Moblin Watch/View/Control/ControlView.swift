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

private struct PadelScoreboardView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingResetConfirimation = false

    var body: some View {
        Divider()
        ScoreboardView(scoreboard: $model.padelScoreboard)
        HStack {
            Button {
                model.padelScoreboardUndoScore()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            Button {
                model.padelScoreboardIncrementHomeScore()
            } label: {
                Image(systemName: "plus")
            }
            .tint(model.padelScoreboardIncrementTintColor)
        }
        HStack {
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
            Button {
                model.padelScoreboardIncrementAwayScore()
            } label: {
                Image(systemName: "plus")
            }
            .tint(model.padelScoreboardIncrementTintColor)
        }
        VStack {
            Text("Home")
            PlayerPickerView(player: $model.padelScoreboard.home.players[0])
            if model.padelScoreboard.home.players.count > 1 {
                PlayerPickerView(player: $model.padelScoreboard.home.players[1])
            }
            Text("Away")
            PlayerPickerView(player: $model.padelScoreboard.away.players[0])
            if model.padelScoreboard.away.players.count > 1 {
                PlayerPickerView(player: $model.padelScoreboard.away.players[1])
            }
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingIsLiveConfirm: Bool = false
    @State private var pendingLiveValue = false
    @State private var isPresentingIsRecordingConfirm: Bool = false
    @State private var pendingRecordingValue = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Toggle(isOn: Binding(get: {
                    model.isLive
                }, set: { value in
                    pendingLiveValue = value
                    isPresentingIsLiveConfirm = true
                })) {
                    Text("Live")
                }
                .confirmationDialog("", isPresented: $isPresentingIsLiveConfirm) {
                    Button(pendingLiveValue ? String(localized: "Go Live") : String(localized: "End")) {
                        model.setIsLive(value: pendingLiveValue)
                    }
                    Button("Cancel") {}
                }
                Toggle(isOn: Binding(get: {
                    model.isRecording
                }, set: { value in
                    pendingRecordingValue = value
                    isPresentingIsRecordingConfirm = true
                })) {
                    Text("Recording")
                }
                .confirmationDialog("", isPresented: $isPresentingIsRecordingConfirm) {
                    Button(pendingRecordingValue ? String(localized: "Start") : String(localized: "Stop")) {
                        model.setIsRecording(value: pendingRecordingValue)
                    }
                    Button("Cancel") {}
                }
                Toggle(isOn: Binding(get: {
                    model.isMuted
                }, set: { value in
                    model.setIsMuted(value: value)
                })) {
                    Text("Muted")
                }
                Button {
                    model.skipCurrentChatTextToSpeechMessage()
                } label: {
                    Text("Skip current TTS")
                }
                if model.showPadelScoreBoard {
                    PadelScoreboardView()
                }
                Spacer()
            }
            .padding()
        }
    }
}
