import SwiftUI

struct TextEditNavigationView: View {
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var sensitive: Bool = false
    var color: Color = .gray
    var valueFormat: ((String) -> String)?

    var body: some View {
        NavigationLink {
            TextEditBindingView(
                title: title,
                value: $value,
                footers: footers,
                capitalize: capitalize,
                keyboardType: keyboardType,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
        } label: {
            TextItemView(name: title,
                         value: valueFormat?(value) ?? value,
                         sensitive: sensitive,
                         color: color)
        }
    }
}

struct TextEditBindingNavigationView: View {
    var title: String
    @Binding var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var sensitive: Bool = false
    var color: Color = .gray
    var valueFormat: ((String) -> String)?

    var body: some View {
        NavigationLink {
            TextEditBindingView(
                title: title,
                value: $value,
                footers: footers,
                capitalize: capitalize,
                keyboardType: keyboardType,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
        } label: {
            TextItemView(name: title,
                         value: valueFormat?(value) ?? value,
                         sensitive: sensitive,
                         color: color)
        }
    }
}
