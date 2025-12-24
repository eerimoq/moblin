import SwiftUI

struct CopyToClipboardButtonView: View {
    let text: String

    var body: some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
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
