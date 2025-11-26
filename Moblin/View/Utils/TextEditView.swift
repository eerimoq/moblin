import SwiftUI

struct TextEditView: View {
    let title: String
    @State var value: String
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var onChange: ((String) -> String?)?
    var onSubmit: (String) -> Void

    var body: some View {
        TextEditBindingView(title: title,
                            value: $value,
                            footers: footers,
                            capitalize: capitalize,
                            keyboardType: keyboardType,
                            placeholder: placeholder,
                            onChange: onChange,
                            onSubmit: onSubmit)
    }
}

struct TextEditBindingView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    @Binding var value: String
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var onChange: ((String) -> String?)?
    var onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @State private var errorMessage: String?

    private func submit() {
        guard errorMessage == nil else {
            return
        }
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
                        errorMessage = onChange?(value.trim())
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
                    if let errorMessage {
                        Text(errorMessage)
                            .bold()
                            .foregroundStyle(.red)
                        Text("")
                    }
                    ForEach(footers, id: \.self) { footer in
                        Text(footer)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}
