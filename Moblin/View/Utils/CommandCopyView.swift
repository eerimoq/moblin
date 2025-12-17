import SwiftUI

struct CommandCopyView: View {
    let command: String

    var body: some View {
        HStack {
            Text("`\(command)`")
            Button {
                UIPasteboard.general.string = command
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
    }
}
