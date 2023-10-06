import SwiftUI

struct WidgetWebPageUrlSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var value: String

    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        value = widget.webPage!.url
    }

    func submitUrl() {
        value = value.trim()
        widget.webPage!.url = value
        model.store()
        print("Storef!!!!!! \(widget.webPage!.url)")
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
