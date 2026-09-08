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
        displayStyle: chat.displayStyle
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
    let rotation: Double
    let scaleX: Double
    let size: CGSize

    var body: some View {
        if post.user != nil {
            if !state.deleted || chatSettings.showDeletedMessages {
                if let highlight = post.highlight {
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 3)
                            .foregroundStyle(highlight.barColor)
                        if chatSettings.compactEvents {
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
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                } else {
                    LineView(deleted: state.deleted,
                             post: post,
                             style: style,
                             platform: moreThanOneStreamingPlatform)
                        .padding(.leading, 3)
                        .rotationEffect(Angle(degrees: rotation))
                        .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                }
            }
        } else {
            Rectangle()
                .fill(.red)
                .frame(width: size.width, height: 1.5)
                .padding(2)
                .rotationEffect(Angle(degrees: rotation))
                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
        }
    }
}

private struct MessagesView: View {
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
        let style = makeChatLineStyle(chat: chatSettings)
        GeometryReader { metrics in
            ScrollView {
                VStack {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(chat.posts) { post in
                            PostView(chatSettings: chatSettings,
                                     style: style,
                                     moreThanOneStreamingPlatform: chat.moreThanOneStreamingPlatform,
                                     post: post,
                                     state: post.state,
                                     rotation: rotation,
                                     scaleX: scaleX,
                                     size: metrics.size)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: metrics.size.height)
            }
            .rotationEffect(Angle(degrees: rotation))
            .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
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
