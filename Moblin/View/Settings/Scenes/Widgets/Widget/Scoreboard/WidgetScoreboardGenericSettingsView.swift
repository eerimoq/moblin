import SwiftUI

struct WidgetScoreboardGenericGeneralSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        TextEditNavigationView(title: String(localized: "Title"), value: generic.title) { title in
            generic.title = title
        }
        .onChange(of: generic.title) { _ in
            model.resetSelectedScene(changeScene: false, attachCamera: false)
        }
    }
}

struct WidgetScoreboardGenericSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

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
        generic.clockMaximum = maximum
    }

    private func formatMaximum(value: String) -> String {
        guard let maximum = Int(value) else {
            return ""
        }
        return formatMinutes(minutes: maximum)
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
                                   value: String(generic.clockMaximum),
                                   onChange: isValidClockMaximum,
                                   onSubmit: submitClockMaximum,
                                   valueFormat: formatMaximum)
                .onChange(of: generic.clockMaximum) { _ in
                    generic.resetClock()
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                }
            Picker("Direction", selection: $generic.clockDirection) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: generic.clockDirection) { _ in
                generic.resetClock()
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        } header: {
            Text("Clock")
        }
    }
}
