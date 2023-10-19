import SwiftUI

struct WidgetBrowserUrlSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var widget: SettingsWidget
    @State var value: String

    init(model: Model, widget: SettingsWidget, toolbar: Toolbar) {
        self.model = model
        self.widget = widget
        self.toolbar = toolbar
        value = widget.browser!.url
    }

    func submitUrl() {
        value = value.trim()
        widget.browser!.url = value
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
        .toolbar {
            toolbar
        }
    }
}
