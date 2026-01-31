import SwiftUI

struct WidgetScoreboardGenericGeneralSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        TextEditNavigationView(title: String(localized: "Title"), value: generic.title) { title in
            generic.title = title
        }
        .onChange(of: generic.title) { _ in
            model.resetSelectedScene(changeScene: false, attachCamera: false)
        }
        ScoreboardColorsView(model: model, widget: widget, scoreboard: scoreboard)
    }
}

struct WidgetScoreboardGenericSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard
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
            TextEditNavigationView(title: String(localized: "Home"), value: generic.home) { home in
                generic.home = home
            }
            .onChange(of: generic.home) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            TextEditNavigationView(title: String(localized: "Away"), value: generic.away) { away in
                generic.away = away
            }
            .onChange(of: generic.away) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
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
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                }
            Picker("Direction", selection: $clock.direction) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: clock.direction) { _ in
                clock.reset()
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        } header: {
            Text("Clock")
        }
    }
}
