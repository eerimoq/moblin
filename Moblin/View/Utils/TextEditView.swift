import SwiftUI

struct TextEditView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footer: Text = .init("")

    var body: some View {
        Form {
            Section {
                TextField("", text: $value)
                    .disableAutocorrection(true)
                    .onSubmit {
                        value = value.trim()
                        dismiss()
                        onSubmit(value)
                    }
                    .submitLabel(.done)
            } footer: {
                footer
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
