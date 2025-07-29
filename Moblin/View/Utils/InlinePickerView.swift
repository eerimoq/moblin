import SwiftUI

struct InlinePickerItem: Identifiable {
    let id: String
    let text: String

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
                    if !items.contains(where: { $0.id == selectedId }) {
                        Text("Unknown 😢")
                            .tag(selectedId)
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
    }
}
