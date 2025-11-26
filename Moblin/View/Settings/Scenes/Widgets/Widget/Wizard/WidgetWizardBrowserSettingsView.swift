import SwiftUI

struct WidgetWizardBrowserSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @ObservedObject var browser: SettingsWidgetBrowser
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            Section {
                TextField(String("https://example.com"), text: $browser.url)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
            } header: {
                Text("URL")
            } footer: {
                if let message = isValidHttpUrl(url: browser.url) {
                    Text(message)
                        .foregroundStyle(.red)
                        .bold()
                }
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(isValidHttpUrl(url: browser.url) != nil || browser.url.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
