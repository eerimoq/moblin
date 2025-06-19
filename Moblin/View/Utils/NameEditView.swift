import SwiftUI

struct NameEditView: View {
    @Binding var name: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TextEditView(title: String(localized: "Name"), value: name, capitalize: true) {
            name = $0
            dismiss()
        }
    }
}
