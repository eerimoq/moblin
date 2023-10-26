import SwiftUI

struct WidgetBrowserUrlSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var value: String

    func submitUrl() {
        value = value.trim()
        widget.browser.url = value
        model.store()
        model.resetSelectedScene()
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $value, onEditingChanged: { isEditing in
                    if !isEditing {
                        submitUrl()
                    }
                })
                .disableAutocorrection(true)
                .onSubmit {
                    submitUrl()
                }
            }
        }
        .navigationTitle("URL")
    }
}
