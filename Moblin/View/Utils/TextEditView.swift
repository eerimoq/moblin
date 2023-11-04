import SwiftUI

struct TextEditView: View {
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
                        onSubmit(value)
                    }
            } footer: {
                footer
            }
        }
        .navigationTitle(title)
    }
}
