import SwiftUI

struct TextValueLocalizedView: View {
    let name: LocalizedStringKey
    let value: String
    var sensitive: Bool = false

    var body: some View {
        TextItemLocalizedView(name: name, value: value, sensitive: sensitive, color: .primary)
    }
}
