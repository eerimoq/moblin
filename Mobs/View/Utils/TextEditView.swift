import SwiftUI

struct TextEditView: View {
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void

    var body: some View {
        Form {
            TextField("", text: $value)
                .onSubmit {
                    value = value.trim()
                    onSubmit(value)
                }
        }
        .navigationTitle(title)
    }
}
