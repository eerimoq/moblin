import SwiftUI

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    var body: some View {
        Section {
            HStack {
                Text("Type")
                Spacer()
                Picker("", selection: $scoreboard.type) {
                    ForEach(SettingsWidgetScoreboardType.allCases.filter { $0 == .padel }, id: \.self) {
                        Text($0.toString())
                    }
                }
                .onChange(of: scoreboard.type) { _ in
                    model.resetSelectedScene(changeScene: false)
                }
            }
            switch scoreboard.type {
            case .padel:
                WidgetScoreboardPadelGeneralSettingsView(model: model, padel: scoreboard.padel)
            case .generic:
                WidgetScoreboardGenericGeneralSettingsView(model: model, generic: scoreboard.generic)
            }
        } header: {
            Text("General")
        }
        switch scoreboard.type {
        case .padel:
            WidgetScoreboardPadelSettingsView(model: model, padel: scoreboard.padel)
        case .generic:
            WidgetScoreboardGenericSettingsView(model: model, generic: scoreboard.generic)
        }
    }
}
