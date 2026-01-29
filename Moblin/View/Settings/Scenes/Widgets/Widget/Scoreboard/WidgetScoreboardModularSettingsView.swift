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
        NavigationLink("Colors") {
            Form {
                Section {
                    ColorPicker(
                        "Text",
                        selection: $modular.homeTextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.homeTextColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.homeTextColor = rgb
                        }
                        model.remoteControlScoreboardUpdate()
                        updateEffect()
                    }
                    ColorPicker(
                        "Background",
                        selection: $modular.homeBgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.homeBgColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.homeBgColor = rgb
                        }
                        model.remoteControlScoreboardUpdate()
                        updateEffect()
                    }
                } header: {
                    Text("Home")
                }
                Section {
                    ColorPicker(
                        "Text",
                        selection: $modular.awayTextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.awayTextColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.awayTextColor = rgb
                        }
                        model.remoteControlScoreboardUpdate()
                        updateEffect()
                    }
                    ColorPicker(
                        "Background",
                        selection: $modular.awayBgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.awayBgColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.awayBgColor = rgb
                        }
                        model.remoteControlScoreboardUpdate()
                        updateEffect()
                    }
                } header: {
                    Text("Away")
                }
                Section {
                    ColorPicker(
                        "Background",
                        selection: $modular.secondaryBackgroundColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: modular.secondaryBackgroundColorColor) {
                        if let rgb = $0.toRgb() {
                            modular.secondaryBackgroundColor = rgb
                        }
                        updateEffect()
                    }
                } header: {
                    Text("Global")
                }
                Section {
                    TextButtonView("Reset") {
                        modular.resetColors()
                        model.remoteControlScoreboardUpdate()
                        updateEffect()
                    }
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
        NavigationLink("Layout") {
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
                        Text("Width")
                            .layoutPriority(1)
                        Slider(value: $stacked.width, in: 100 ... 650)
                            .onChange(of: stacked.width) { _ in
                                updateEffect()
                            }
                        Text(String(Int(stacked.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Height")
                            .layoutPriority(1)
                        Slider(value: $stacked.rowHeight, in: 10 ... 35)
                            .onChange(of: stacked.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(stacked.rowHeight)))
                            .frame(width: 35)
                    }
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
                }
                Section {
                    Toggle("Title", isOn: $modular.showStackedHeader)
                        .onChange(of: modular.showStackedHeader) { _ in
                            updateEffect()
                        }
                    Toggle("Second row (TO, Foul, etc.)", isOn: $modular.showSecondaryRows)
                        .onChange(of: modular.showSecondaryRows) { _ in
                            updateEffect()
                        }
                    Toggle("Info box (Time, Period)", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updateEffect()
                        }
                }
            }
            .navigationTitle("Layout")
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
        NavigationLink("Layout") {
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
                        Text("Height")
                            .layoutPriority(1)
                        Slider(value: $sideBySide.rowHeight, in: 10 ... 35)
                            .onChange(of: sideBySide.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(sideBySide.rowHeight)))
                            .frame(width: 35)
                    }
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
                }
                Section {
                    Toggle("Title", isOn: $sideBySide.showTitle)
                        .onChange(of: sideBySide.showTitle) { _ in
                            updateEffect()
                        }
                    Toggle("Second row (TO, Foul, etc.)", isOn: $modular.showSecondaryRows)
                        .onChange(of: modular.showSecondaryRows) { _ in
                            updateEffect()
                        }
                    Toggle("Info box (Time, Period)", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updateEffect()
                        }
                }
            }
            .navigationTitle("Layout")
        }
    }
}

struct WidgetScoreboardModularSettingsView: View {
    let model: Model
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    private func isValidClockMaximum(value: String) -> String? {
        guard let maximum = Int(value) else {
            return String(localized: "Not a number")
        }
        guard maximum > 0 else {
            return String(localized: "Too small")
        }
        guard maximum <= 180 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitClockMaximum(value: String) {
        guard let maximum = Int(value) else {
            return
        }
        modular.clockMaximum = maximum
    }

    private func formatMaximum(value: String) -> String {
        guard let maximum = Int(value) else {
            return ""
        }
        return formatFullDuration(seconds: 60 * maximum)
    }

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Home"), value: modular.home) {
                modular.home = $0
                model.remoteControlScoreboardUpdate()
                model.sceneUpdated()
            }
            TextEditNavigationView(title: String(localized: "Away"), value: modular.away) {
                modular.away = $0
                model.remoteControlScoreboardUpdate()
                model.sceneUpdated()
            }
        } header: {
            Text("Teams")
        }
        Section {
            TextEditNavigationView(title: String(localized: "Maximum"),
                                   value: String(modular.clockMaximum),
                                   onChange: isValidClockMaximum,
                                   onSubmit: submitClockMaximum,
                                   valueFormat: formatMaximum)
                .onChange(of: modular.clockMaximum) { _ in
                    modular.resetClock()
                    model.remoteControlScoreboardUpdate()
                    model.sceneUpdated()
                }
            Picker("Direction", selection: $modular.clockDirection) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: modular.clockDirection) { _ in
                modular.resetClock()
                model.remoteControlScoreboardUpdate()
                model.sceneUpdated()
            }
        } header: {
            Text("Clock")
        }
    }
}

struct WidgetScoreboardModularGeneralSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    var body: some View {
        Picker("Type", selection: $modular.layout) {
            ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: modular.layout) { _ in
            model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard,
                                                             config: model.getCurrentConfig(),
                                                             players: model.database.scoreboardPlayers)
            model.remoteControlScoreboardUpdate()
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
        ColorsView(model: model, widget: widget, scoreboard: scoreboard, modular: modular)
    }
}
