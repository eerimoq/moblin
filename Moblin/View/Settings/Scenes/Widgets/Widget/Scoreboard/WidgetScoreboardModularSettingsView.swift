import SwiftUI

private struct LayoutSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    private func updateEffect() {
        model.updateScoreboardEffect(widget: widget)
    }

    var body: some View {
        NavigationLink("Appearance") {
            Form {
                Section {
                    HStack {
                        Text("Width")
                        Slider(value: $modular.width, in: 100 ... 650)
                            .onChange(of: modular.width) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Height")
                        Slider(value: $modular.rowHeight, in: 10 ... 50)
                            .onChange(of: modular.rowHeight) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.rowHeight)))
                            .frame(width: 35)
                    }
                    Toggle("Title", isOn: $modular.showTitle)
                        .onChange(of: modular.showTitle) { _ in
                            updateEffect()
                        }
                    Toggle("Info box", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updateEffect()
                        }
                    Toggle("More stats", isOn: $modular.showMoreStats)
                        .onChange(of: modular.showMoreStats) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Layout")
                }
                Section {
                    HStack {
                        Text("Size")
                        Slider(value: $modular.fontSize, in: 5 ... 25)
                            .onChange(of: modular.fontSize) { _ in
                                updateEffect()
                            }
                        Text(String(Int(modular.fontSize)))
                            .frame(width: 35)
                    }
                    Toggle("Bold", isOn: $modular.isBold)
                        .onChange(of: modular.isBold) { _ in
                            updateEffect()
                        }
                } header: {
                    Text("Font")
                }
            }
            .navigationTitle("Appearance")
        }
    }
}

private struct TeamView: View {
    let model: Model
    let widget: SettingsWidget
    let side: String
    @ObservedObject var team: SettingsWidgetModularScoreboardTeam

    private func updateEffect() {
        model.updateScoreboardEffect(widget: widget)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: String(localized: "Name"), value: team.name) {
                        team.name = $0
                        model.remoteControlScoreboardUpdate()
                        model.sceneUpdated()
                    }
                    ColorPicker("Text", selection: $team.textColorColor, supportsOpacity: false)
                        .onChange(of: team.textColorColor) {
                            if let rgb = $0.toRgb() {
                                team.textColor = rgb
                            }
                            model.remoteControlScoreboardUpdate()
                            updateEffect()
                        }
                    ColorPicker("Background", selection: $team.backgroundColorColor, supportsOpacity: false)
                        .onChange(of: team.backgroundColorColor) {
                            if let rgb = $0.toRgb() {
                                team.backgroundColor = rgb
                            }
                            model.remoteControlScoreboardUpdate()
                            updateEffect()
                        }
                }
            }
            .navigationTitle(side)
        } label: {
            HStack {
                Text(side)
                Spacer()
                Text(team.name)
                    .foregroundStyle(.gray)
            }
        }
    }
}

struct WidgetScoreboardModularSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var modular: SettingsWidgetModularScoreboard
    @ObservedObject var clock: SettingsWidgetScoreboardClock

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
        clock.maximum = maximum
    }

    private func formatMaximum(value: String) -> String {
        guard let maximum = Int(value) else {
            return ""
        }
        return formatFullDuration(seconds: 60 * maximum)
    }

    var body: some View {
        Section {
            TeamView(model: model, widget: widget, side: String(localized: "Home"), team: modular.home)
            TeamView(model: model, widget: widget, side: String(localized: "Away"), team: modular.away)
        } header: {
            Text("Teams")
        }
        Section {
            TextEditNavigationView(title: String(localized: "Maximum"),
                                   value: String(clock.maximum),
                                   onChange: isValidClockMaximum,
                                   onSubmit: submitClockMaximum,
                                   valueFormat: formatMaximum)
                .onChange(of: clock.maximum) { _ in
                    clock.reset()
                    model.remoteControlScoreboardUpdate()
                    model.sceneUpdated()
                }
            Picker("Direction", selection: $clock.direction) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: clock.direction) { _ in
                clock.reset()
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
    @ObservedObject var modular: SettingsWidgetModularScoreboard

    var body: some View {
        Picker("Type", selection: $modular.layout) {
            ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: modular.layout) { _ in
            model.updateScoreboardEffect(widget: widget)
            model.remoteControlScoreboardUpdate()
        }
        LayoutSettingsView(model: model, widget: widget, modular: modular)
    }
}
