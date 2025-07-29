import SwiftUI

struct TextValueView: View {
    let name: String
    let value: String
    var sensitive: Bool = false

    var body: some View {
        TextItemView(name: name, value: value, sensitive: sensitive, color: .primary)
    }
}
