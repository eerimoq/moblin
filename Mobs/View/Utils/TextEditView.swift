import SwiftUI

struct TextEditView: View {
    var toolbar: Toolbar
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footer: Text = .init("")

    var body: some View {
        Form {
            Section {
                TextField("", text: $value, onEditingChanged: { isEditing in
                    if !isEditing {
                        value = value.trim()
                        onSubmit(value)
                    }
                })
                .disableAutocorrection(true)
                .onSubmit {
                }
            } footer: {
                footer
            }
        }
        .navigationTitle(title)
        .toolbar {
            toolbar
        }
    }
}
