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

private struct LayoutSettingsView: View {
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
        NavigationLink("Layout") {
            Form {
                Section {
                    HStack {
                        Text("Font size")
                            .layoutPriority(1)
                        Slider(value: $modular.fontSize, in: 5 ... 25)
                            .onChange(of: modular.fontSize) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.fontSize)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Width")
                            .layoutPriority(1)
                        Slider(value: $modular.width, in: 100 ... 650)
                            .onChange(of: modular.width) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Height")
                            .layoutPriority(1)
                        Slider(value: $modular.rowHeight, in: 10 ... 50)
                            .onChange(of: modular.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.rowHeight)))
                            .frame(width: 35)
                    }
                }
                Section {
                    Toggle("Bold", isOn: $modular.isBold)
                        .onChange(of: modular.isBold) { _ in
                            updateEffect()
                        }
                    Toggle("Italic", isOn: $modular.isItalic)
                        .onChange(of: modular.isItalic) { _ in
                            updateEffect()
                        }
                }
                Section {
                    if modular.layout.isStacked() {
                        Toggle("Title", isOn: $modular.showTitle)
                            .onChange(of: modular.showTitle) { _ in
                                updateEffect()
                            }
                    }
                    Toggle("Timeout, foul, etc.", isOn: $modular.showSecondaryRows)
                        .onChange(of: modular.showSecondaryRows) { _ in
                            updateEffect()
                        }
                    Toggle("Clock, half, etc.", isOn: $modular.showGlobalStatsBlock)
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
        LayoutSettingsView(model: model,
                           widget: widget,
                           scoreboard: scoreboard,
                           modular: modular)
        ColorsView(model: model, widget: widget, scoreboard: scoreboard, modular: modular)
    }
}
