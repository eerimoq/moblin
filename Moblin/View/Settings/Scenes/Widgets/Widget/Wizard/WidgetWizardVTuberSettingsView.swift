import SwiftUI

struct WidgetWizardVTuberSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var vTuber: SettingsWidgetVTuber
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            WidgetVTuberPickerView(model: model, vTuber: vTuber)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(vTuber.modelName.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
