import SwiftUI

struct IconAndTextView: View {
    var image: String
    var text: String
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
