import SwiftUI

private struct QuickButtonChatLinkConfirmationModifier: ViewModifier {
    @Binding var url: URL?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                url?.absoluteString ?? "",
                isPresented: Binding(get: { url != nil }, set: {
                    if !$0 {
                        url = nil
                    }
                }),
                titleVisibility: .visible,
                presenting: url
            ) { url in
                Button("Open link") {
                    UIApplication.shared.open(url)
                }
            }
    }
}

extension View {
    func quickButtonChatLinkConfirmation(url: Binding<URL?>) -> some View {
        modifier(QuickButtonChatLinkConfirmationModifier(url: url))
    }
}
