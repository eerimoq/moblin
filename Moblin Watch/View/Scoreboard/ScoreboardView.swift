import SwiftUI

enum ScoreboardType {
    case padel
    case generic
}

struct ScoreboardView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        switch model.scoreboardType {
        case .padel:
            PadelScoreboardView(model: model, padel: model.padel)
        case .generic:
            GenericScoreboardView(model: model, generic: model.padel)
        case nil:
            EmptyView()
        }
    }
}
