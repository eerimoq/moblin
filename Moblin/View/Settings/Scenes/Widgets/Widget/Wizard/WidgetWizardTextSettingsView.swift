import SwiftUI

struct WidgetWizardTextSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @ObservedObject var text: SettingsWidgetText
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            TextWidgetTextView(value: $text.formatString)
            Section {
                TextWidgetSuggestionsView(text: $text.formatString)
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(text.formatString.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
