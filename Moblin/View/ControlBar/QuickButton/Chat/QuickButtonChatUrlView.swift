import SwiftUI

struct QuickButtonChatUrlView: View {
    let text: String
    let url: URL
    let deleted: Bool
    @State private var presentingConfirmation = false

    var body: some View {
        Button(text) {
            presentingConfirmation = true
        }
        .foregroundStyle(deleted ? .gray : .blue)
        .strikethrough(deleted)
        .disabled(deleted)
        .confirmationDialog("", isPresented: $presentingConfirmation) {
            Button("Open link") {
                UIApplication.shared.open(url)
            }
        } message: {
            Text(url.absoluteString)
        }
    }
}
