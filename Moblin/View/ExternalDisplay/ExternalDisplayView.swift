import AVFoundation
import Foundation
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private let fontSizeScaleFactor = 3.0

private struct HighlightMessageView: View {
    let chat: SettingsChat
    let highlight: ChatHighlight

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: highlight.image)
            Text(" ")
            Text(highlight.titleNoEmotes())
        }
        .foregroundStyle(highlight.messageColor())
        .padding([.leading], 5)
        .font(.system(size: fontSizeScaleFactor * CGFloat(chat.fontSize)))
    }
}

private struct LineView: View {
    @ObservedObject var postState: ChatPostState
    let post: ChatPost
    @ObservedObject var chat: SettingsChat
    let platform: Bool

    private func usernameColor() -> Color {
        return post.userColor.color()
    }

    private func imageOpacity() -> Double {
        return postState.deleted ? 0.25 : 1
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
                    .foregroundStyle(.gray)
            }
            if chat.platform, platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .frame(height: fontSizeScaleFactor * CGFloat(chat.fontSize * 1.4))
                    .opacity(imageOpacity())
            }
            if chat.badges {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                    .frame(height: fontSizeScaleFactor * CGFloat(chat.fontSize * 1.4))
                    .opacity(imageOpacity())
                }
            }
            Text(post.user!)
                .foregroundStyle(postState.deleted ? .gray : usernameColor)
                .strikethrough(postState.deleted)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold()
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(postState.deleted ? .gray : .white)
                        .strikethrough(postState.deleted)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: fontSizeScaleFactor * 25)
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: fontSizeScaleFactor * 25)
                        .opacity(imageOpacity())
                    }
                    Text(" ")
                }
            }
        }
        .padding([.leading], 5)
        .font(.system(size: fontSizeScaleFactor * CGFloat(chat.fontSize)))
    }
}

private struct PostView: View {
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
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
                        VStack(alignment: .leading, spacing: 1) {
                            HighlightMessageView(chat: chatSettings, highlight: highlight)
                            LineView(postState: post.state,
                                     post: post,
                                     chat: chatSettings,
                                     platform: chat.moreThanOneStreamingPlatform)
                        }
                    }
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                } else {
                    LineView(postState: post.state,
                             post: post,
                             chat: chatSettings,
                             platform: chat.moreThanOneStreamingPlatform)
                        .padding([.leading], 3)
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
    @EnvironmentObject var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
        GeometryReader { metrics in
            ScrollView {
                VStack {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(chat.posts) { post in
                            PostView(chatSettings: chatSettings,
                                     chat: chat,
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
            .foregroundStyle(.white)
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

    func makeUIView(context _: Context) -> PreviewView {
        return model.externalDisplayStreamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
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
