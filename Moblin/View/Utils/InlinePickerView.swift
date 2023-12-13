import SwiftUI

struct InlinePickerView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    var onChange: (String) -> Void
    var footers: [String] = []
    var items: [String]
    @State var selected: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selected) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                    }
                }
                .onChange(of: selected) { item in
                    onChange(item)
                    dismiss()
                }
                .pickerStyle(.inline)
                .labelsHidden()
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
