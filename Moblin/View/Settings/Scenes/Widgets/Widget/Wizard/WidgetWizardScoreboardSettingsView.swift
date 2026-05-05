import SwiftUI

struct WidgetWizardScoreboardSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            Section {
                Picker("Sport", selection: $scoreboard.sport) {
                    ForEach(SettingsWidgetScoreboardSport.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
