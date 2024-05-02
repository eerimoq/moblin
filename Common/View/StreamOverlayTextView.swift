import SwiftUI

struct StreamOverlayTextView: View {
    var text: String

    var body: some View {
        Text(text)
            .foregroundColor(.white)
            .padding([.leading, .trailing], 2)
            .background(backgroundColor)
            .cornerRadius(5)
    }
}
