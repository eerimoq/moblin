import SwiftUI

struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    var home: Int
    var away: Int
}

struct PadelScoreboardPlayer: Identifiable {
    let id: UUID = .init()
    var name: String
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
    var players: [PadelScoreboardPlayer]

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            ForEach(players) { player in
                Text(player.name.prefix(5))
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
                TeamPlayersView(players: scoreboard.home.players)
                TeamPlayersView(players: scoreboard.away.players)
            }
            ForEach(scoreboard.score) { score in
                VStack {
                    if score.id == scoreboard.score.last?.id {
                        TeamScoreView(score: score.home)
                        TeamScoreView(score: score.away)
                    } else {
                        TeamScoreView(score: score.home)
                            .bold(score.home > score.away)
                        TeamScoreView(score: score.away)
                            .bold(score.away > score.home)
                    }
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
