import SwiftUI

private struct ColorsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?
            .update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    ColorPicker("Text", selection: $scoreboard.textColorColor, supportsOpacity: false)
                        .onChange(of: scoreboard.textColorColor) { _ in
                            if let color = scoreboard.textColorColor.toRgb() {
                                scoreboard.textColor = color
                            }
                            updateEffect()
                        }
                    ColorPicker("Primary background",
                                selection: $scoreboard.primaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.primaryBackgroundColorColor) { _ in
                            if let color = scoreboard.primaryBackgroundColorColor.toRgb() {
                                scoreboard.primaryBackgroundColor = color
                            }
                            updateEffect()
                        }
                    ColorPicker("Secondary background",
                                selection: $scoreboard.secondaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.secondaryBackgroundColorColor) { _ in
                            if let color = scoreboard.secondaryBackgroundColorColor.toRgb() {
                                scoreboard.secondaryBackgroundColor = color
                            }
                            updateEffect()
                        }
                }
                Section {
                    TextButtonView("Reset") {
                        scoreboard.resetColors()
                        updateEffect()
                    }
                }
            }
            .navigationTitle("Colors")
        } label: {
            Text("Colors")
        }
    }
}

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    var body: some View {
        Section {
            Picker("Type", selection: $scoreboard.type) {
                ForEach(SettingsWidgetScoreboardType.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: scoreboard.type) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            switch scoreboard.type {
            case .padel:
                WidgetScoreboardPadelGeneralSettingsView(model: model, padel: scoreboard.padel)
            case .generic:
                WidgetScoreboardGenericGeneralSettingsView(model: model, generic: scoreboard.generic)
            }
            ColorsView(model: model, widget: widget, scoreboard: scoreboard)
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
