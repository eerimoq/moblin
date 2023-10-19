import SwiftUI

struct NameEditView: View {
    var toolbar: Toolbar
    @State var name: String
    var onSubmit: (String) -> Void

    var body: some View {
        TextEditView(toolbar: toolbar, title: "Name", value: name, onSubmit: onSubmit)
    }
}
