import SwiftUI

struct NameEditView: View {
    @Binding var name: String
    @Environment(\.dismiss) var dismiss

    private func handleSubmit(value: String) {
        name = value
        dismiss()
    }

    var body: some View {
        TextEditView(title: String(localized: "Name"), value: name, onSubmit: handleSubmit, capitalize: true)
    }
}
