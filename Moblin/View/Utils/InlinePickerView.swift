import SwiftUI

struct InlinePickerItem: Identifiable {
    var id: String
    var text: String

    static func fromStrings(values: [String]) -> [InlinePickerItem] {
        return values.map { InlinePickerItem(id: $0, text: $0) }
    }
}

struct InlinePickerView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    var onChange: (String) -> Void
    var footers: [String] = []
    var items: [InlinePickerItem]
    @State var selectedId: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selectedId) {
                    ForEach(items) { item in
                        Text(item.text)
                            .tag(item.id)
                    }
                }
                .onChange(of: selectedId) { item in
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
