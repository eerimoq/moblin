import SwiftUI

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?
            .update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
    }

    var body: some View {
        Section {
            Picker("Type", selection: $scoreboard.type) {
                ForEach(SettingsWidgetScoreboardType.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: scoreboard.type) { _ in
                model.resetSelectedScene(changeScene: false)
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
        Section {
            ColorPicker("Text", selection: $scoreboard.textColorColor)
                .onChange(of: scoreboard.textColorColor) { _ in
                    if let color = scoreboard.textColorColor.toRgb() {
                        scoreboard.textColor = color
                    }
                    updateEffect()
                }
            ColorPicker("Primary background", selection: $scoreboard.primaryBackgroundColorColor)
                .onChange(of: scoreboard.primaryBackgroundColorColor) { _ in
                    if let color = scoreboard.primaryBackgroundColorColor.toRgb() {
                        scoreboard.primaryBackgroundColor = color
                    }
                    updateEffect()
                }
            ColorPicker("Secondary background", selection: $scoreboard.secondaryBackgroundColorColor)
                .onChange(of: scoreboard.secondaryBackgroundColorColor) { _ in
                    if let color = scoreboard.secondaryBackgroundColorColor.toRgb() {
                        scoreboard.secondaryBackgroundColor = color
                    }
                    updateEffect()
                }
        } header: {
            Text("Colors")
        }
    }
}
