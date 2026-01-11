import SwiftUI

struct WidgetWizardWheelOfLuckSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool
    @State var text: String = ""

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $text)
                    .onChange(of: text) { _ in
                        wheelOfLuck.optionsFromText(text: text)
                    }
                    .onAppear {
                        text = wheelOfLuck.options.map { $0.text }.joined(separator: "\n")
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
