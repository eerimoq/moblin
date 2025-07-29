import SwiftUI

struct IconAndTextView: View {
    let image: String
    let text: String
    var longDivider: Bool = false

    var body: some View {
        HStack {
            if longDivider {
                Text("")
            }
            Image(systemName: image)
                .frame(width: iconWidth)
            Text(text)
        }
    }
}
