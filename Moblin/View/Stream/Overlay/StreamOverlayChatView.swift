import Collections
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5

private struct HighlightMessageView: View {
    @ObservedObject var postState: ChatPostState
    let chat: SettingsChat
    let highlight: ChatHighlight

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColorColor.opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColorColor
        } else {
            return .clear
        }
    }

    private func frameHeightEmotes() -> CGFloat {
        return CGFloat(chat.fontSize * 1.7)
    }

    private func imageOpacity() -> Double {
        return postState.deleted ? 0.25 : 1
    }

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: highlight.image)
            Text(" ")
            ForEach(highlight.titleSegments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(highlight.messageColor(defaultColor: chat.messageColorColor))
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: frameHeightEmotes())
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                        .frame(height: frameHeightEmotes())
                        .opacity(imageOpacity())
                    }
                }
            }
        }
        .stroke(color: shadowColor(), width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundStyle(.white)
        .cornerRadius(5)
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

    private func messageColor(usernameColor: Color) -> Color {
        if post.isAction && chat.meInUsernameColor {
            return usernameColor
        } else {
            return chat.messageColorColor
        }
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColorColor.opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColorColor
        } else {
            return .clear
        }
    }

    private func frameHeightBadges() -> CGFloat {
        return CGFloat(chat.fontSize * 1.4)
    }

    private func frameHeightEmotes() -> CGFloat {
        return CGFloat(chat.fontSize * 1.7)
    }

    private func imageOpacity() -> Double {
        return postState.deleted ? 0.25 : 1
    }

    var body: some View {
        let usernameColor = usernameColor()
        let messageColor = messageColor(usernameColor: usernameColor)
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundStyle(chat.timestampColorColor)
            }
            if chat.platform, platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .frame(height: frameHeightBadges())
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
                    .frame(height: frameHeightBadges())
                    .opacity(imageOpacity())
                }
            }
            Text(post.displayName(nicknames: chat.nicknames, displayStyle: chat.displayStyle))
                .foregroundStyle(postState.deleted ? .gray : usernameColor)
                .strikethrough(postState.deleted)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold(chat.boldUsername)
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(postState.deleted ? .gray : messageColor)
                        .strikethrough(postState.deleted)
                        .bold(chat.boldMessage)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: frameHeightEmotes())
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                        .frame(height: frameHeightEmotes())
                        .opacity(imageOpacity())
                    }
                    Text(" ")
                }
            }
        }
        .stroke(color: shadowColor(), width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundStyle(.white)
        .cornerRadius(5)
    }
}

private let startId = UUID()

private struct PostView: View {
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    let fullSize: Bool
    let post: ChatPost
    @ObservedObject var state: ChatPostState
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
                            HighlightMessageView(postState: post.state,
                                                 chat: chatSettings,
                                                 highlight: highlight)
                            LineView(postState: post.state,
                                     post: post,
                                     chat: chatSettings,
                                     platform: chat.moreThanOneStreamingPlatform)
                        }
                    }
                } else {
                    LineView(postState: post.state,
                             post: post,
                             chat: chatSettings,
                             platform: chat.moreThanOneStreamingPlatform)
                        .padding([.leading], 3)
                }
            }
        } else {
            Rectangle()
                .fill(.red)
                .frame(width: size.width, height: 1.5)
                .padding(2)
        }
    }
}

struct StreamOverlayChatView: View {
    let model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    let fullSize: Bool

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

    private func heightFactor() -> CGFloat {
        if fullSize {
            return 1
        } else {
            return chatSettings.height
        }
    }

    private func widthFactor() -> CGFloat {
        if fullSize {
            return 1
        } else {
            return chatSettings.width
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
                                    // App hangs if not doing this async.
                                    DispatchQueue.main.async {
                                        tryUnpause()
                                    }
                                }
                                .onDisappear {
                                    tryPause()
                                }
                                .frame(height: 1)
                                .id(startId)
                            ForEach(chat.posts) { post in
                                PostView(chatSettings: chatSettings,
                                         chat: chat,
                                         fullSize: fullSize,
                                         post: post,
                                         state: post.state,
                                         size: metrics.size)
                                    .rotationEffect(Angle(degrees: rotation))
                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundStyle(.white)
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
                    .frame(width: metrics.size.width * widthFactor(),
                           height: metrics.size.height * heightFactor())
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
