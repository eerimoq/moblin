import SwiftUI

struct WidgetWizardWheelOfLuckSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $wheelOfLuck.text)
                    .onChange(of: wheelOfLuck.text) { _ in
                        wheelOfLuck.optionsFromText(text: wheelOfLuck.text)
                    }
                    .onAppear {
                        wheelOfLuck.optionsFromText(text: wheelOfLuck.text)
                    }
            } header: {
                Text("Options")
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(wheelOfLuck.options.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
