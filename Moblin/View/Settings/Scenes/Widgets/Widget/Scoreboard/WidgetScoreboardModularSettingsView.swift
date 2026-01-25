import SwiftUI

private struct ColorsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard,
                                                         config: model.getCurrentConfig(),
                                                         players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink("Team Colors") {
            Form {
                Section {
                    ColorPicker(
                        "Text Color",
                        selection: $modular.homeTextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.homeTextColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.homeTextColor = rgb
                        }
                        model.broadcastCurrentState()
                        updateEffect()
                    }
                    ColorPicker(
                        "Background color",
                        selection: $modular.homeBgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.homeBgColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.homeBgColor = rgb
                        }
                        model.broadcastCurrentState()
                        updateEffect()
                    }
                } header: {
                    Text("Team 1")
                }
                Section {
                    ColorPicker(
                        "Text color",
                        selection: $modular.awayTextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.awayTextColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.awayTextColor = rgb
                        }
                        model.broadcastCurrentState()
                        updateEffect()
                    }
                    ColorPicker(
                        "Background color",
                        selection: $modular.awayBgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.awayBgColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.awayBgColor = rgb
                        }
                        model.broadcastCurrentState()
                        updateEffect()
                    }
                } header: {
                    Text("Team 2")
                }
                Section {
                    ColorPicker(
                        "Main background",
                        selection: $modular.secondaryBackgroundColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.secondaryBackgroundColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.secondaryBackgroundColor = rgb
                        }
                        updateEffect()
                    }
                    Button("Reset all colors") {
                        modular.resetColors()
                        model.broadcastCurrentState()
                        updateEffect()
                    }
                } header: {
                    Text("Global style")
                }
            }
            .navigationTitle("Colors")
        }
    }
}

private struct StackedSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard
    @ObservedObject var stacked: SettingsWidgetModularStackedScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard,
                                                         config: model.getCurrentConfig(),
                                                         players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink("Stacked layout settings") {
            Form {
                Section {
                    HStack {
                        Text("Font size")
                            .layoutPriority(1)
                        Slider(value: $stacked.fontSize, in: 5 ... 25)
                            .onChange(of: stacked.fontSize) { _ in
                                updateEffect()
                            }
                        Text(String(Int(stacked.fontSize)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Total width")
                            .layoutPriority(1)
                        Slider(value: $stacked.width, in: 150 ... 650)
                            .onChange(of: stacked.width) { _ in
                                updateEffect()
                            }
                        Text(String(Int(stacked.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Row height").layoutPriority(1)
                        Slider(value: $stacked.rowHeight, in: 10 ... 35)
                            .onChange(of: stacked.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(stacked.rowHeight)))
                            .frame(width: 35)
                    }
                } header: {
                    Text("Dimensions")
                }
                Section {
                    Toggle("Bold", isOn: $stacked.isBold)
                        .onChange(of: stacked.isBold) { _ in
                            updateEffect()
                        }
                    Toggle("Italic", isOn: $stacked.isItalic)
                        .onChange(of: stacked.isItalic) { _ in
                            updateEffect()
                        }
                    Toggle("Show title", isOn: $modular.showStackedHeader)
                        .onChange(of: modular.showStackedHeader) { _ in
                            updateEffect()
                        }
                    if modular.showStackedHeader {
                        Toggle("Title on top", isOn: $modular.titleAbove)
                            .onChange(of: modular.titleAbove) { _ in
                                updateEffect()
                            }
                    }
                    Toggle("Show Moblin footer", isOn: $stacked.showFooter)
                        .onChange(of: stacked.showFooter) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Basic style")
                }
                Section {
                    Toggle("Second row (TO, Foul, etc.)", isOn: $modular.showSecondaryRows)
                        .onChange(of: modular.showSecondaryRows) { _ in
                            updateEffect()
                        }
                    Toggle("Info box (Time, Period)", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Modular layout")
                }
            }
            .navigationTitle("Stacked layout")
        }
    }
}

private struct SideBySideSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard
    @ObservedObject var sideBySide: SettingsWidgetModularSideBySideScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard,
                                                         config: model.getCurrentConfig(),
                                                         players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink("Side by side") {
            Form {
                Section {
                    HStack {
                        Text("Font size")
                            .layoutPriority(1)
                        Slider(value: $sideBySide.fontSize, in: 5 ... 25)
                            .onChange(of: sideBySide.fontSize) { _ in
                                updateEffect()
                            }
                        Text(String(Int(sideBySide.fontSize)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Width")
                            .layoutPriority(1)
                        Slider(value: $sideBySide.width, in: 150 ... 650)
                            .onChange(of: sideBySide.width) { _ in
                                updateEffect()
                            }
                        Text(String(Int(sideBySide.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Row height")
                            .layoutPriority(1)
                        Slider(value: $sideBySide.rowHeight, in: 10 ... 35)
                            .onChange(of: sideBySide.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(sideBySide.rowHeight)))
                            .frame(width: 35)
                    }
                } header: {
                    Text("Dimensions")
                }
                Section {
                    Toggle("Bold", isOn: $sideBySide.isBold)
                        .onChange(of: sideBySide.isBold) { _ in
                            updateEffect()
                        }
                    Toggle("Italic", isOn: $sideBySide.isItalic)
                        .onChange(of: sideBySide.isItalic) { _ in
                            updateEffect()
                        }
                    Toggle("Show title", isOn: $sideBySide.showTitle)
                        .onChange(of: sideBySide.showTitle) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Basic style")
                }
                Section {
                    Toggle("Second row (TO, Foul, etc.)", isOn: $modular.showSecondaryRows)
                        .onChange(of: modular.showSecondaryRows) { _ in
                            updateEffect()
                        }
                    Toggle("Info box (Time, Period)", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Layout")
                }
            }
            .navigationTitle("Side by side")
        }
    }
}

struct WidgetScoreboardModularSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    var body: some View {
        Section {
            TextEditNavigationView(title: "Home", value: modular.home) {
                modular.home = $0
                model.broadcastCurrentState()
                model.sceneUpdated()
            }
            TextEditNavigationView(title: "Away", value: modular.away) {
                modular.away = $0
                model.broadcastCurrentState()
                model.sceneUpdated()
            }
            ColorsView(model: model, widget: widget, scoreboard: scoreboard, modular: modular)
        } header: {
            Text("Teams")
        }
    }
}

struct WidgetScoreboardModularGeneralSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    var body: some View {
        Picker("Layout", selection: $modular.layout) {
            ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: modular.layout) { _ in
            model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard,
                                                             config: model.getCurrentConfig(),
                                                             players: model.database.scoreboardPlayers)
            model.broadcastCurrentState()
        }
        if modular.layout.isStacked() {
            StackedSettingsView(model: model,
                                widget: widget,
                                scoreboard: scoreboard,
                                modular: modular,
                                stacked: modular.stacked)
        } else {
            SideBySideSettingsView(model: model,
                                   widget: widget,
                                   scoreboard: scoreboard,
                                   modular: modular,
                                   sideBySide: modular.sideBySide)
        }
        HStack {
            Text("Timer duration")
                .layoutPriority(1)
            Spacer()
            TextField("", value: $modular.clockMaximum, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
        }
        Picker("Timer direction", selection: $modular.clockDirection) {
            ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) {
                Text($0.toString())
            }
        }
    }
}
