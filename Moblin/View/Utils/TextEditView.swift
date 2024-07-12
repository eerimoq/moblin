import SwiftUI

struct TextEditView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    @State private var changed = false
    @State private var submitted = false

    private func submit() {
        submitted = true
        value = value.trim()
        onSubmit(value)
    }

    var body: some View {
        Form {
            Section {
                TextField(placeholder, text: $value)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(capitalize ? .sentences : .never)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        changed = true
                    }
                    .onSubmit {
                        submit()
                        dismiss()
                    }
                    .submitLabel(.done)
                    .onDisappear {
                        if changed && !submitted {
                            submit()
                        }
                    }
            } footer: {
                VStack(alignment: .leading) {
                    ForEach(footers, id: \.self) { footer in
                        Text(footer)
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
