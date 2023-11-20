import SwiftUI

struct InlinePickerView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    var onChange: (String) -> Void
    var footer: Text = .init("")
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
                footer
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
