import AVFoundation
import Foundation
import SwiftUI

private func makeChatLineStyle(chat: SettingsChat) -> ChatLineStyle {
    ChatLineStyle(
        fontSize: 3 * CGFloat(chat.fontSize),
        timestampColor: chat.timestampColorEnabled ? UIColor(Color.gray) : nil,
        boldUsername: true,
        badges: chat.badges,
        animatedEmotes: chat.animatedEmotes,
        nicknames: chat.nicknames,
        displayStyle: chat.displayStyle,
        font: chat.font
    )
}

private struct HighlightMessageView: View {
    let style: ChatLineStyle
    let highlight: ChatHighlight

    private func content(title: String) -> ChatLineContent {
        let color = UIColor(highlight.messageColor())
        return style.content(items: [
            style.symbolItem(name: highlight.image, color: color),
            .text(" \(title)", ChatLineTextStyle(color: color)),
        ])
    }

    var body: some View {
        if let title = highlight.titleNoEmotes() {
            ChatLineView(content: content(title: title))
        }
    }
}

private struct HighlightImageView: View {
    let style: ChatLineStyle
    let highlight: ChatHighlight

    var body: some View {
        ChatLineView(content: style.makeHighlightImageContent(highlight: highlight))
    }
}

private struct LineView: View {
    let deleted: Bool
    let post: ChatPost
    let style: ChatLineStyle
    let platform: Bool

    var body: some View {
        ChatLineView(content: style.makeContent(post: post, platform: platform, deleted: deleted))
    }
}

private struct PostView: View {
    let chatSettings: SettingsChat
    let style: ChatLineStyle
    let moreThanOneStreamingPlatform: Bool
    let post: ChatPost
    @ObservedObject var state: ChatPostState

    var body: some View {
        if !state.deleted || chatSettings.showDeletedMessages {
            if let highlight = post.highlight {
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: 3)
                        .foregroundStyle(highlight.barColor)
                    if chatSettings.compactEvents, highlight.titleSegments != nil {
                        HighlightImageView(style: style, highlight: highlight)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        if !chatSettings.compactEvents {
                            HighlightMessageView(style: style, highlight: highlight)
                        }
                        LineView(deleted: state.deleted,
                                 post: post,
                                 style: style,
                                 platform: moreThanOneStreamingPlatform)
                    }
                }
            } else {
                LineView(deleted: state.deleted,
                         post: post,
                         style: style,
                         platform: moreThanOneStreamingPlatform)
                    .padding(.leading, 3)
            }
        }
    }
}

private struct MessagesView: View {
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider

    var body: some View {
        let style = makeChatLineStyle(chat: chatSettings)
        ChatScrollView(chat: chat,
                       newMessagesAtTop: chatSettings.newMessagesAtTop,
                       mirrored: chatSettings.mirrored)
        { post in
            PostView(chatSettings: chatSettings,
                     style: style,
                     moreThanOneStreamingPlatform: chat.moreThanOneStreamingPlatform,
                     post: post,
                     state: post.state)
        }
    }
}

private struct ChatView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: ChatProvider

    var body: some View {
        MessagesView(chatSettings: model.database.chat, chat: chat)
            .padding()
    }
}

private struct ExternalDisplayStreamPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> SharedUiViewContainerView {
        SharedUiViewContainerView(sharedView: model.externalDisplayStreamPreviewView)
    }

    func updateUIView(_ uiView: SharedUiViewContainerView, context _: Context) {
        uiView.attachSharedView()
    }
}

struct ExternalDisplayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var externalDisplay: ExternalDisplay

    var body: some View {
        ZStack {
            if externalDisplay.chatEnabled {
                ChatView(chat: model.externalDisplayChat)
            } else {
                ExternalDisplayStreamPreviewView()
            }
        }
        .background(.black)
    }
}
