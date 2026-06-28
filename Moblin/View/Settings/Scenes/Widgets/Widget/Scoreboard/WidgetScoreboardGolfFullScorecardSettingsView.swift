import SwiftUI

struct WidgetScoreboardGolfFullScorecardGeneralSettingsView: View {
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    @ObservedObject var golf: SettingsWidgetGolfScoreboard
    let updated: () -> Void

    var body: some View {
        ScoreboardColorsView(scoreboard: scoreboard, updated: updated)
        Toggle(isOn: $golf.showPars) {
            Text("Show pars")
        }
        .onChange(of: golf.showPars) { _ in
            updated()
        }
    }
}
