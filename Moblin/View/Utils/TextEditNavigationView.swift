import SwiftUI

struct TextEditNavigationView: View {
    var title: String
    var value: String
    var onSubmit: (String) -> Void
    var footers: [String] = []
    var capitalize: Bool = false
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var sensitive: Bool = false
    var color: Color = .gray
    var valueFormat: ((String) -> String)?

    var body: some View {
        NavigationLink(destination: TextEditView(
            title: title,
            value: value,
            onSubmit: onSubmit,
            footers: footers,
            capitalize: capitalize,
            keyboardType: keyboardType,
            placeholder: placeholder
        )) {
            TextItemView(name: title, value: valueFormat?(value) ?? value, sensitive: sensitive, color: color)
        }
    }
}
