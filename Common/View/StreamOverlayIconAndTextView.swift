import SwiftUI

enum StreamOverlayIconAndTextPlacement {
    case beforeIcon
    case afterIcon
    case hide
}

struct StreamOverlayIconAndTextView: View {
    var show: Bool
    var icon: String
    var text: String
    var textPlacement: StreamOverlayIconAndTextPlacement
    var color: Color = .white
    var iconBackgroundColor: Color = backgroundColor

    var body: some View {
        if show {
            HStack(spacing: 1) {
                if textPlacement == .beforeIcon {
                    StreamOverlayTextView(text: text)
                        .font(smallFont)
                }
                Image(systemName: icon)
                    .frame(width: 17, height: 17)
                    .font(smallFont)
                    .padding([.leading, .trailing], 2)
                    .foregroundColor(color)
                    .background(iconBackgroundColor)
                    .cornerRadius(5)
                if textPlacement == .afterIcon {
                    StreamOverlayTextView(text: text)
                        .font(smallFont)
                }
            }
            .padding(20)
            .contentShape(Rectangle())
            .padding(-20)
        }
    }
}
