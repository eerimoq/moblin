import SwiftUI

struct NameEditView: View {
    @State var name: String
    var onSubmit: (String) -> Void

    var body: some View {
        TextEditView(title: "Name", value: name, onSubmit: onSubmit)
    }
}
