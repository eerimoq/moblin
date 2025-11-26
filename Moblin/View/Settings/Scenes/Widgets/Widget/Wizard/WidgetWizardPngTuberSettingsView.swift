import SwiftUI

struct WidgetWizardPngTuberSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var pngTuber: SettingsWidgetPngTuber
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            WidgetPngTuberPickerView(model: model, pngTuber: pngTuber)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(pngTuber.modelName.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
