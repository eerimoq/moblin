import SwiftUI

struct StreamOverlayIconAndTextView: View {
    var icon: String
    var text: String
    var textFirst = false
    var color: Color = .white

    var body: some View {
        HStack(spacing: 1) {
            if textFirst {
                StreamOverlayTextView(text: text)
                    .font(smallFont)
            }
            Image(systemName: icon)
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundColor(color)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(5)
            if !textFirst {
                StreamOverlayTextView(text: text)
                    .font(smallFont)
            }
        }
        .padding(0)
    }
}
