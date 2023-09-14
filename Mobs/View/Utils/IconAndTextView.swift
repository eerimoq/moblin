import SwiftUI

struct IconAndTextView: View {
    var image: String
    var text: String

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(text)
        }
    }
}
