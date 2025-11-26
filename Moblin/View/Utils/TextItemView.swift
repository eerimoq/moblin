import SwiftUI

struct TextItemView: View {
    let name: String
    let value: String
    var sensitive: Bool = false
    var color: Color = .gray

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(replaceSensitive(value: value, sensitive: sensitive))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}
