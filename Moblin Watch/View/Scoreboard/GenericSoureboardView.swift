import SwiftUI

private struct TeamView: View {
    let model: Model

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            Text(String("Linkoping"))
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
    let model: Model

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                TeamView(model: model)
                TeamView(model: model)
            }
            .padding([.bottom], 2)
            Spacer()
            VStack {
                TeamScoreView(score: 1)
                TeamScoreView(score: 2)
            }
            .frame(width: 17)
            .padding([.bottom], 2)
            .padding([.trailing], 15)
        }
        .padding([.leading, .trailing], 2)
        .padding([.top], 2)
        .background(scoreboardBlueColor)
        .foregroundColor(.white)
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
                model.genericScoreBoardResetScore()
            }
            Button("Cancel") {}
        }
        .tint(.red)
    }
}

struct GenericScoreboardView: View {
    let model: Model
    @ObservedObject var generic: Padel

    var body: some View {
        VStack(spacing: 5) {
            ScoreboardScoreboardView(model: model)
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
