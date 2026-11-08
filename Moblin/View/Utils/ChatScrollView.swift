import SwiftUI

private let latestPostId = "latest"

private struct LatestPostView: View {
    let onLatestAppear: () -> Void
    let onLatestDisappear: () -> Void

    var body: some View {
        Color.clear
            .onAppear {
                DispatchQueue.main.async {
                    onLatestAppear()
                }
            }
            .onDisappear {
                onLatestDisappear()
            }
            .frame(height: 1)
            .id(latestPostId)
    }
}

struct ChatScrollView<Row: View>: View {
    @ObservedObject var chat: ChatProvider
    let newMessagesAtTop: Bool
    let mirrored: Bool
    var onLatestAppear: () -> Void = {}
    var onLatestDisappear: () -> Void = {}
    @ViewBuilder let row: (ChatPost) -> Row

    var body: some View {
        let scaleY: CGFloat = newMessagesAtTop ? 1 : -1
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    LatestPostView(onLatestAppear: onLatestAppear, onLatestDisappear: onLatestDisappear)
                    ForEach(chat.posts.reversed()) { post in
                        row(post)
                            .scaleEffect(y: scaleY)
                    }
                }
            }
            .scaleEffect(x: mirrored ? -1 : 1, y: scaleY)
            .chatScrollEdgeEffectHidden()
            .onChange(of: chat.interactiveChat) { _ in
                proxy.scrollTo(latestPostId, anchor: .top)
            }
            .onChange(of: chat.triggerScrollToBottom) { _ in
                proxy.scrollTo(latestPostId, anchor: .top)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func chatScrollEdgeEffectHidden() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectHidden()
        } else {
            self
        }
    }
}
