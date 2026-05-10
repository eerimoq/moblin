import SwiftUI

struct NameEditView: View {
    @Binding var name: String
    var existingNames: [Named] = []

    private func onChange(value: String) -> String? {
        if value.isEmpty {
            String(localized: "Empty names are not allowed.")
        } else if existingNames.contains(where: { $0.name == value }), value != name {
            String(localized: "The name '\(value)' is already in use.")
        } else {
            nil
        }
    }

    var body: some View {
        NavigationLink {
            TextEditView(title: String(localized: "Name"), value: name, capitalize: true,
                         onChange: onChange)
            {
                name = $0
            }
        } label: {
            TextItemLocalizedView(name: "Name", value: name)
        }
    }
}
