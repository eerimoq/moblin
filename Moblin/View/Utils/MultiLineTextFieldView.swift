import SwiftUI

struct MultiLineTextFieldView: View {
    @Binding var value: String
    @FocusState var focusedField: Bool?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TextField("My text", text: $value, axis: .vertical)
                .padding(.trailing, 30)
                .focused($focusedField, equals: true)
            if !value.isEmpty {
                Button {
                    value = ""
                    focusedField = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(uiColor: .gray))
                        .opacity(0.5)
                }
                .padding([.top], 1)
                .padding([.trailing], 5)
                .buttonStyle(.plain)
            }
        }
    }
}

struct MultiLineTextFieldNavigationView: View {
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var color: Color = .gray

    var body: some View {
        NavigationLink {
            MultiLineTextFieldBindingView(
                title: title,
                value: $value,
                footers: footers,
                onSubmit: onSubmit
            )
        } label: {
            TextItemView(name: title, value: value, color: color)
        }
    }
}

private struct MultiLineTextFieldBindingView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @Binding var value: String
    var footers: [String] = []
    var onSubmit: (String) -> Void
    @State private var changed = false

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $value)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        changed = true
                    }
                    .onDisappear {
                        if changed {
                            value = value.trim()
                            onSubmit(value)
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
    }
}
