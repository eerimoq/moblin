import SwiftUI

struct CopyToClipboardButtonView: View {
    let text: String

    var body: some View {
        ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20))
        }
    }
}

struct CommandCopyView: View {
    let command: String

    var body: some View {
        HStack {
            Text("`\(command)`")
            CopyToClipboardButtonView(text: command)
        }
    }
}
