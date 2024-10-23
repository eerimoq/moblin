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

private struct ScoreboardView: View {
    @Binding var scoreboard: PadelScoreboard

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Spacer(minLength: 0)
                    ForEach(scoreboard.home.players) { player in
                        Text(player.name.prefix(5))
                    }
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading) {
                    Spacer(minLength: 0)
                    ForEach(scoreboard.away.players) { player in
                        Text(player.name.prefix(5))
                    }
                    Spacer(minLength: 0)
                }
            }
            .font(.system(size: 15))
            ForEach(scoreboard.score) { score in
                VStack {
                    VStack {
                        Spacer(minLength: 0)
                        Text(String(score.home))
                        Spacer(minLength: 0)
                    }
                    VStack {
                        Spacer(minLength: 0)
                        Text(String(score.away))
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 17)
                .font(.system(size: 30))
            }
            Spacer()
        }
        .padding([.leading, .trailing], 2)
        .padding([.top], 2)
        .background(RgbColor(red: 0x0B, green: 0x10, blue: 0xAC).color())
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
