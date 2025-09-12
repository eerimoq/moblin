import SwiftUI

private struct TextEditNavigationViewInner: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    @Binding var value: String
    let onSubmit: (String) -> Void
    let onChange: ((String) -> String?)?
    let footers: [String]
    let capitalize: Bool
    let keyboardType: UIKeyboardType
    let placeholder: String
    @Binding var errorMessage: String?
    @Binding var submittedValue: String
    @State var submitted: Bool = false

    private func submit() {
        guard !submitted else {
            return
        }
        if errorMessage == nil {
            value = value.trim()
            onSubmit(value)
            submittedValue = value
        } else {
            errorMessage = nil
            value = submittedValue
        }
        submitted = true
    }

    var body: some View {
        Form {
            Section {
                TextField(placeholder, text: $value)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(capitalize ? .sentences : .never)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        errorMessage = onChange?(value.trim())
                    }
                    .onSubmit {
                        submit()
                        dismiss()
                    }
                    .onDisappear {
                        submit()
                    }
                    .submitLabel(.done)
            } footer: {
                VStack(alignment: .leading) {
                    if let errorMessage {
                        Text(errorMessage)
                            .bold()
                            .foregroundColor(.red)
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

struct TextEditNavigationView: View {
    @Environment(\.dismiss) var dismiss
    private let title: String
    @State private var value: String
    private let onSubmit: (String) -> Void
    private let onChange: (String) -> String?
    private let footers: [String]
    private let capitalize: Bool
    private let keyboardType: UIKeyboardType
    private let placeholder: String
    private let sensitive: Bool
    private let valueFormat: ((String) -> String)?
    @State private var errorMessage: String?
    @State private var submittedValue: String

    init(title: String,
         value: String,
         onChange: (@escaping (String) -> String?) = { _ in nil },
         onSubmit: @escaping (String) -> Void,
         footers: [String] = [],
         capitalize: Bool = false,
         keyboardType: UIKeyboardType = .default,
         placeholder: String = "",
         sensitive: Bool = false,
         valueFormat: ((String) -> String)? = nil)
    {
        self.title = title
        self.value = value
        self.onChange = onChange
        self.onSubmit = onSubmit
        self.footers = footers
        self.capitalize = capitalize
        self.keyboardType = keyboardType
        self.placeholder = placeholder
        self.sensitive = sensitive
        self.valueFormat = valueFormat
        submittedValue = value
    }

    var body: some View {
        NavigationLink {
            TextEditNavigationViewInner(title: title,
                                        value: $value,
                                        onSubmit: onSubmit,
                                        onChange: onChange,
                                        footers: footers,
                                        capitalize: capitalize,
                                        keyboardType: keyboardType,
                                        placeholder: placeholder,
                                        errorMessage: $errorMessage,
                                        submittedValue: $submittedValue)
        } label: {
            TextItemView(name: title,
                         value: valueFormat?(submittedValue) ?? submittedValue,
                         sensitive: sensitive)
        }
    }
}

struct TextEditBindingNavigationView: View {
    var title: String
    @Binding var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var sensitive: Bool = false
    var color: Color = .gray
    var valueFormat: ((String) -> String)?

    var body: some View {
        NavigationLink {
            TextEditBindingView(
                title: title,
                value: $value,
                footers: footers,
                capitalize: capitalize,
                keyboardType: keyboardType,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
        } label: {
            TextItemView(name: title,
                         value: valueFormat?(value) ?? value,
                         sensitive: sensitive,
                         color: color)
        }
    }
}
