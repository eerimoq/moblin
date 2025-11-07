import SwiftUI

private let clockFieldWidth = 70.0
private let clockFont: Font = .system(size: 35)

class Generic: ObservableObject {
    var id: UUID = .init()
    @Published var homeTeam: String = ""
    @Published var awayTeam: String = ""
    @Published var homeScore: Int = 0
    @Published var awayScore: Int = 0
    @Published var clockMinutes: Int = 0
    @Published var clockSeconds: Int = 0
    @Published var clockMaximum: Int = 45
    @Published var isClockStopped: Bool = false
    @Published var title: String = ""
}

private func formatSeconds(_ value: Int) -> String {
    if value < 10 {
        return "0\(value)"
    } else {
        return String(value)
    }
}

private struct TeamView: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            Text(name)
            Spacer(minLength: 0)
        }
        .font(.system(size: 20))
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
    @ObservedObject var generic: Generic

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                TeamView(name: generic.homeTeam)
                TeamView(name: generic.awayTeam)
            }
            .padding([.bottom], 2)
            Spacer()
            VStack {
                TeamScoreView(score: generic.homeScore)
                TeamScoreView(score: generic.awayScore)
            }
            .frame(width: 17)
            .padding([.bottom], 2)
            .padding([.trailing], 15)
        }
        .padding([.leading, .trailing], 2)
        .padding([.top], 2)
        .background(scoreboardBlueColor)
        .foregroundStyle(.white)
    }
}

private struct ScoreboardUndoButtonView: View {
    let model: Model

    var body: some View {
        Button {
            model.genericScoreboardUndoScore()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
    }
}

private struct ScoreboardIncrementHomeButtonView: View {
    let model: Model

    var body: some View {
        Button {
            model.genericScoreboardIncrementHomeScore()
        } label: {
            Image(systemName: "plus")
        }
    }
}

private struct ScoreboardIncrementAwayButtonView: View {
    let model: Model

    var body: some View {
        Button {
            model.genericScoreboardIncrementAwayScore()
        } label: {
            Image(systemName: "plus")
        }
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
                model.genericScoreboardResetScore()
            }
            Button("Cancel") {}
        }
        .tint(.red)
    }
}

private struct ScoreboardTabView: View {
    let model: Model

    var body: some View {
        VStack(spacing: 5) {
            ScoreboardScoreboardView(generic: model.generic)
            HStack {
                ScoreboardUndoButtonView(model: model)
                ScoreboardIncrementHomeButtonView(model: model)
            }
            HStack {
                ScoreboardResetScoreButtonView(model: model)
                ScoreboardIncrementAwayButtonView(model: model)
            }
            Spacer()
        }
    }
}

private struct ClockTabView: View {
    let model: Model
    @ObservedObject var generic: Generic
    @State var editingMinutes: Int = 0
    @State var editingSeconds: Int = 0
    @State var isEditing: Bool = false
    @State var title: String = ""

    private func clockEdit() -> some View {
        VStack {
            HStack {
                VStack {
                    Picker("", selection: $editingMinutes) {
                        ForEach(0 ... generic.clockMaximum, id: \.self) { value in
                            Text(String(value))
                        }
                    }
                    .pickerStyle(.wheel)
                    Spacer()
                }
                Text(String(":"))
                VStack {
                    Picker("", selection: $editingSeconds) {
                        ForEach(0 ... 59, id: \.self) { value in
                            Text(formatSeconds(value))
                        }
                    }
                    .pickerStyle(.wheel)
                    Spacer()
                }
            }
            .font(clockFont)
            Button {
                isEditing = false
                model.genericScoreboardSetClock(minutes: editingMinutes, seconds: editingSeconds)
            } label: {
                Text("Set clock")
            }
        }
    }

    private func clockTime() -> some View {
        HStack {
            Spacer()
            HStack {
                Spacer()
                Text(String(generic.clockMinutes))
            }
            .frame(width: clockFieldWidth)
            Text(String(":"))
            HStack {
                Text(formatSeconds(generic.clockSeconds))
                Spacer()
            }
            .frame(width: clockFieldWidth)
            Spacer()
        }
        .monospacedDigit()
        .font(clockFont)
        .background(scoreboardBlueColor)
        .foregroundStyle(.white)
        .sheet(isPresented: $isEditing) {
            clockEdit()
        }
    }

    private func clockButtons() -> some View {
        HStack {
            Button {
                model.genericScoreboardSetClockState(stopped: !generic.isClockStopped)
            } label: {
                if generic.isClockStopped {
                    Image(systemName: "play.fill")
                } else {
                    Image(systemName: "stop.fill")
                }
            }
            Button {
                isEditing = true
                editingMinutes = generic.clockMinutes
                editingSeconds = generic.clockSeconds
            } label: {
                Image(systemName: "pencil")
            }
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            clockTime()
            clockButtons()
            TextField("Title", text: $title)
                .onChange(of: title) {
                    model.genericScoreboardSetTitle(title: title)
                }
            Spacer()
        }
        .onAppear {
            title = generic.title
        }
    }
}

struct GenericScoreboardView: View {
    let model: Model
    @ObservedObject var generic: Padel

    var body: some View {
        TabView {
            ScoreboardTabView(model: model)
            ClockTabView(model: model, generic: model.generic)
        }
        .tabViewStyle(.verticalPage)
    }
}
