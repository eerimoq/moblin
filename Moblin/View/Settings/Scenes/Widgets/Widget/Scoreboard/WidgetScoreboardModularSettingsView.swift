import SwiftUI

private struct TeamView: View {
    let side: String
    @ObservedObject var team: SettingsWidgetModularScoreboardTeam
    let updated: () -> Void

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: String(localized: "Name"), value: team.name) {
                        team.name = $0
                        updated()
                    }
                    ColorPicker("Text", selection: $team.textColorColor, supportsOpacity: false)
                        .onChange(of: team.textColorColor) {
                            if let rgb = $0.toRgb() {
                                team.textColor = rgb
                            }
                            updated()
                        }
                    ColorPicker("Background", selection: $team.backgroundColorColor, supportsOpacity: false)
                        .onChange(of: team.backgroundColorColor) {
                            if let rgb = $0.toRgb() {
                                team.backgroundColor = rgb
                            }
                            updated()
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
    @ObservedObject var modular: SettingsWidgetModularScoreboard
    @ObservedObject var clock: SettingsWidgetScoreboardClock
    let updated: () -> Void

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
            TeamView(side: String(localized: "Home"), team: modular.home, updated: updated)
            TeamView(side: String(localized: "Away"), team: modular.away, updated: updated)
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
                    updated()
                }
            Picker("Direction", selection: $clock.direction) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: clock.direction) { _ in
                clock.reset()
                updated()
            }
        } header: {
            Text("Clock")
        }
    }
}

struct WidgetScoreboardModularGeneralSettingsView: View {
    @ObservedObject var modular: SettingsWidgetModularScoreboard
    let updated: () -> Void

    var body: some View {
        NavigationLink("Layout") {
            Form {
                Section {
                    Picker("Type", selection: $modular.layout) {
                        ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .onChange(of: modular.layout) { _ in
                        updated()
                    }
                }
                Section {
                    HStack {
                        Text("Width")
                        Slider(value: $modular.width, in: 100 ... 1000)
                            .onChange(of: modular.width) { _ in
                                updated()
                            }
                        Text(String(Int(modular.width)))
                            .frame(width: 35)
                    }
                    HStack {
                        Text("Height")
                        Slider(value: $modular.rowHeight, in: 10 ... 150)
                            .onChange(of: modular.rowHeight) { _ in
                                updated()
                            }
                        Text(String(Int(modular.rowHeight)))
                            .frame(width: 35)
                    }
                }
                Section {
                    Toggle("Title", isOn: $modular.showTitle)
                        .onChange(of: modular.showTitle) { _ in
                            updated()
                        }
                    Toggle("More stats", isOn: $modular.showMoreStats)
                        .onChange(of: modular.showMoreStats) { _ in
                            updated()
                        }
                    Toggle("Info box", isOn: $modular.showGlobalStatsBlock)
                        .onChange(of: modular.showGlobalStatsBlock) { _ in
                            updated()
                        }
                    Toggle("Bold", isOn: $modular.isBold)
                        .onChange(of: modular.isBold) { _ in
                            updated()
                        }
                }
            }
            .navigationTitle("Layout")
        }
    }
}
