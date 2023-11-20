import SwiftUI

struct TextEditView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footer: Text = .init("")
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
                TextField("", text: $value)
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
                footer
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
