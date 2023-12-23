import SwiftUI

struct TextValueView: View {
    var name: String
    var value: String
    var sensitive: Bool = false

    var body: some View {
        TextItemView(name: name, value: value, sensitive: sensitive, color: .primary)
    }
}
