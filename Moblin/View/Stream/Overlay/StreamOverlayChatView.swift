import Collections
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5

private struct HighlightMessageView: View {
    let chat: SettingsChat
    let image: String
    let name: String

    private func messageColor() -> Color {
        return chat.messageColor.color()
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColor.color()
        } else {
            return .clear
        }
    }

    var body: some View {
        let messageColor = messageColor()
        let shadowColor = shadowColor()
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
        .foregroundColor(messageColor)
        .stroke(color: shadowColor, width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

private struct LineView: View {
    var post: ChatPost
    @ObservedObject var chat: SettingsChat
    var platform: Bool

    private func usernameColor() -> Color {
        return post.userColor.color()
    }

    private func messageColor(usernameColor: Color) -> Color {
        if post.isAction && chat.meInUsernameColor {
            return usernameColor
        } else {
            return chat.messageColor.color()
        }
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColor.color()
        } else {
            return .clear
        }
    }

    var body: some View {
        let timestampColor = chat.timestampColor.color()
        let usernameColor = usernameColor()
        let messageColor = messageColor(usernameColor: usernameColor)
        let shadowColor = shadowColor()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundColor(timestampColor)
            }
            if chat.platform, platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .frame(height: CGFloat(chat.fontSize * 1.4))
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
                    .frame(height: CGFloat(chat.fontSize * 1.4))
                }
            }
            Text(post.user!)
                .foregroundColor(usernameColor)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold(chat.boldUsername)
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundColor(messageColor)
                        .bold(chat.boldMessage)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: CGFloat(chat.fontSize * 1.7))
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                        .frame(height: CGFloat(chat.fontSize * 1.7))
                    }
                    Text(" ")
                }
            }
        }
        .stroke(color: shadowColor, width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

private let startId = UUID()

struct StreamOverlayChatView: View {
    var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider

    private func tryPause() {
        guard chat.interactiveChat else {
            return
        }
        if !chat.paused {
            if !chat.posts.isEmpty {
                model.pauseChat()
            }
        }
    }

    private func tryUnpause() {
        guard chat.interactiveChat else {
            return
        }
        if chat.paused {
            model.endOfChatReachedWhenPaused()
        }
    }

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
        GeometryReader { metrics in
            VStack {
                Spacer()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            Color.clear
                                .onAppear {
                                    tryUnpause()
                                }
                                .onDisappear {
                                    tryPause()
                                }
                                .frame(height: 1)
                                .id(startId)
                            ForEach(chat.posts) { post in
                                if post.user != nil {
                                    if let highlight = post.highlight {
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: 3)
                                                .foregroundColor(highlight.barColor)
                                            VStack(alignment: .leading, spacing: 1) {
                                                HighlightMessageView(
                                                    chat: chatSettings,
                                                    image: highlight.image,
                                                    name: highlight.title
                                                )
                                                LineView(post: post,
                                                         chat: chatSettings,
                                                         platform: chat.moreThanOneStreamingPlatform)
                                            }
                                        }
                                        .rotationEffect(Angle(degrees: rotation))
                                        .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                    } else {
                                        LineView(post: post,
                                                 chat: chatSettings,
                                                 platform: chat.moreThanOneStreamingPlatform)
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
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
                    .frame(width: metrics.size.width * chatSettings.width,
                           height: metrics.size.height * chatSettings.height)
                    .onChange(of: chat.interactiveChat) { _ in
                        proxy.scrollTo(startId, anchor: .bottom)
                    }
                    .onChange(of: chat.triggerScrollToBottom) { _ in
                        proxy.scrollTo(startId, anchor: .bottom)
                    }
                    .onAppear {
                        // Trigger after tryPause() of bottom of chat detector.
                        DispatchQueue.main.async {
                            tryUnpause()
                        }
                    }
                }
            }
        }
    }
}
