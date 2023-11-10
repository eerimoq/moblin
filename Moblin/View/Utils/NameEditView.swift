import SwiftUI

struct NameEditView: View {
    @State var name: String
    @Environment(\.dismiss) var dismiss
    var onSubmit: (String) -> Void

    private func handleSubmit(value: String) {
        dismiss()
        onSubmit(value)
    }

    var body: some View {
        TextEditView(title: "Name", value: name, onSubmit: onSubmit)
    }
}
