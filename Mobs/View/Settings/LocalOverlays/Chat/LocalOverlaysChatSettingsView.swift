import SwiftUI

struct LocalOverlaysChatSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    init(model: Model, toolbar: Toolbar) {
        self.model = model
        self.toolbar = toolbar
    }

    func submitFontSize(value: String) {
        guard let fontSize = Float(value) else {
            return
        }
        guard fontSize > 0 else {
            return
        }
        model.database.chat!.fontSize = fontSize
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    toolbar: toolbar,
                    title: "Font size",
                    value: String(model.database.chat!.fontSize),
                    onSubmit: submitFontSize)
                ) {
                    TextItemView(name: "Font size", value: String(model.database.chat!.fontSize))
                }
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            toolbar
        }
    }
}
