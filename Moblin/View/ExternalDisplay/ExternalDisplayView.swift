import AVFoundation
import Foundation
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private struct HighlightMessageView: View {
    var chat: SettingsChat
    let image: String
    let name: String

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: image)
            Text(" ")
            Text(name)
        }
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
    }
}

private struct LineView: View {
    var post: ChatPost
    var chat: SettingsChat

    private func usernameColor() -> Color {
        if let color = post.userColor {
            return color.color()
        } else {
            return chat.usernameColor.color()
        }
    }

    var body: some View {
        let usernameColor = usernameColor()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundColor(.gray)
            }
            if chat.badges! {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                    .frame(height: CGFloat(chat.fontSize * 1.4))
                }
            }
            Text(post.user!)
                .foregroundColor(usernameColor)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold()
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 25)
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: 25)
                    }
                    Text(" ")
                }
            }
        }
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
    }
}

private struct MessagesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: ChatProvider

    private func getRotation() -> Double {
        if model.database.chat.newMessagesAtTop! {
            return 0.0
        } else {
            return 180.0
        }
    }

    private func getScaleX() -> Double {
        if model.database.chat.newMessagesAtTop! {
            return 1.0
        } else {
            return -1.0
        }
    }

    private func isMirrored() -> CGFloat {
        if model.database.chat.mirrored! {
            return -1
        } else {
            return 1
        }
    }

    var body: some View {
        let rotation = getRotation()
        let scaleX = getScaleX()
        GeometryReader { metrics in
            ScrollView {
                VStack {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(chat.posts) { post in
                            if post.user != nil {
                                if let highlight = post.highlight {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: 3)
                                            .foregroundColor(highlight.color)
                                        VStack(alignment: .leading, spacing: 1) {
                                            HighlightMessageView(
                                                chat: model.database.chat,
                                                image: highlight.image,
                                                name: highlight.title
                                            )
                                            LineView(
                                                post: post,
                                                chat: model.database.chat
                                            )
                                        }
                                    }
                                    .rotationEffect(Angle(degrees: rotation))
                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                } else {
                                    LineView(post: post, chat: model.database.chat)
                                        .padding([.leading], 3)
                                        .rotationEffect(Angle(degrees: rotation))
                                        .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                }
                            } else {
                                Rectangle()
                                    .fill(.red)
                                    .frame(width: metrics.size.width, height: 1.5)
                                    .padding(2)
                                    .rotationEffect(Angle(degrees: rotation))
                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: metrics.size.height)
            }
            .foregroundColor(.white)
            .rotationEffect(Angle(degrees: rotation))
            .scaleEffect(x: scaleX * isMirrored(), y: 1.0, anchor: .center)
        }
    }
}

private struct ChatView: View {
    @ObservedObject var chat: ChatProvider

    var body: some View {
        MessagesView(chat: chat)
            .padding()
    }
}

private struct ExternalDisplayStreamPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PreviewView {
        return model.externalDisplayStreamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
}

struct ExternalDisplayView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            if model.externalDisplayChatEnabled {
                ChatView(chat: model.externalDisplayChat)
            } else {
                ExternalDisplayStreamPreviewView()
            }
        }
    }
}
