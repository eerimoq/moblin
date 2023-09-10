import SwiftUI

struct StreamOverlayIconAndTextView: View {
    var icon: String
    var text: String
    var textFirst = false

    var body: some View {
        HStack {
            if textFirst {
                StreamOverlayTextView(text: text)
                    .font(.system(size: 13))
            }
            Image(systemName: icon)
                .frame(width: 12)
                .font(.system(size: 13))
            if !textFirst {
                StreamOverlayTextView(text: text)
                    .font(.system(size: 13))
            }
        }
        .padding(0)
    }
}
