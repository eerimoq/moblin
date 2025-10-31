import SwiftUI

struct WidgetScoreboardGenericGeneralSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        TextEditNavigationView(title: String(localized: "Title"), value: generic.title) { title in
            generic.title = title
        }
        .onChange(of: generic.title) { _ in
            model.resetSelectedScene(changeScene: false)
        }
    }
}

struct WidgetScoreboardGenericSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Home"), value: generic.home) { home in
                generic.home = home
            }
            .onChange(of: generic.home) { _ in
                model.resetSelectedScene(changeScene: false)
            }
            TextEditNavigationView(title: String(localized: "Away"), value: generic.away) { away in
                generic.away = away
            }
            .onChange(of: generic.away) { _ in
                model.resetSelectedScene(changeScene: false)
            }
        } header: {
            Text("Teams")
        }
    }
}
