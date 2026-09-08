import Collections
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5
let chatEmoteScale: Float = 1.5

private struct HighlightMessageView: View {
    let postState: ChatPostState
    let chat: SettingsChat
    let highlight: ChatHighlight

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            chat.backgroundColorColor.opacity(0.6)
        } else {
            .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            chat.shadowColorColor
        } else {
            .clear
        }
    }

    private func frameHeightEmotes() -> CGFloat {
        CGFloat(chat.fontSize * chatEmoteScale)
    }

    private func imageOpacity() -> Double {
        postState.deleted ? 0.25 : 1
    }

    var body: some View {
        if let titleSegments = highlight.titleSegments {
            WrappingHStack(
                alignment: .leading,
                horizontalSpacing: 0,
                verticalSpacing: 0,
                fitContentWidth: true
            ) {
                Image(systemName: highlight.image)
                Text(" ")
                ForEach(titleSegments, id: \.id) { segment in
                    if let text = segment.text {
                        Text(text)
                            .foregroundStyle(highlight.messageColor(defaultColor: chat.messageColorColor))
                    }
                    if let url = segment.url?.url(animated: chat.animatedEmotes) {
                        if chat.animatedEmotes {
                            AnimatedEmoteView(url: url)
                                .padding(.vertical, chat.shadowColorEnabled ? 1.5 : 0)
                                .frame(height: frameHeightEmotes())
                                .opacity(imageOpacity())
                        } else {
                            CacheAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                EmptyView()
                            }
                            .padding(.vertical, chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: frameHeightEmotes())
                            .opacity(imageOpacity())
                        }
                    }
                }
            }
            .stroke(color: shadowColor(), width: chat.shadowColorEnabled ? borderWidth : 0)
            .padding(.leading, 5)
            .font(.system(size: CGFloat(chat.fontSize)))
            .background(backgroundColor())
            .foregroundStyle(.white)
            .cornerRadius(5)
        }
    }
}

private struct HighlightImageView: View {
    let chat: SettingsChat
    let highlight: ChatHighlight

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            chat.shadowColorColor
        } else {
            .clear
        }
    }

    var body: some View {
        Image(systemName: highlight.image)
            .stroke(color: shadowColor(), width: chat.shadowColorEnabled ? borderWidth : 0)
            .font(.system(size: CGFloat(chat.fontSize)))
            .foregroundStyle(highlight.messageColor(defaultColor: chat.messageColorColor))
            .padding(.leading, 5)
    }
}

private struct LineView: View {
    let deleted: Bool
    let post: ChatPost
    let chat: SettingsChat
    let platform: Bool

    private func usernameColor() -> Color {
        post.userColor.color()
    }

    private func messageColor(usernameColor: Color) -> Color {
        if post.isAction, chat.meInUsernameColor {
            usernameColor
        } else {
            chat.messageColorColor
        }
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            chat.backgroundColorColor.opacity(0.6)
        } else {
            .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            chat.shadowColorColor
        } else {
            .clear
        }
    }

    private func frameHeightBadges() -> CGFloat {
        CGFloat(chat.fontSize * 1.4)
    }

    private func frameHeightEmotes() -> CGFloat {
        CGFloat(chat.fontSize * chatEmoteScale)
    }

    private func imageOpacity() -> Double {
        deleted ? 0.25 : 1
    }

    var body: some View {
        let usernameColor = usernameColor()
        let messageColor = messageColor(usernameColor: usernameColor)
        WrappingHStack(
            alignment: post.isBigGif() ? .topLeading : .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundStyle(chat.timestampColorColor)
            }
            if platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
                    .frame(height: frameHeightBadges())
                    .opacity(imageOpacity())
            }
            if chat.sharedChatIcons, let iconUrl = post.sourceChannelIcon {
                CacheAsyncImage(url: iconUrl) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    EmptyView()
                }
                .padding(2)
                .frame(height: frameHeightBadges())
                .opacity(imageOpacity())
            }
            if chat.badges {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                    .frame(height: frameHeightBadges())
                    .opacity(imageOpacity())
                }
            }
            Text(post.displayName(nicknames: chat.nicknames, displayStyle: chat.displayStyle))
                .foregroundStyle(deleted ? .gray : usernameColor)
                .strikethrough(deleted)
                .lineLimit(1)
                .padding(.trailing, 0)
                .bold(chat.boldUsername)
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(deleted ? .gray : messageColor)
                        .strikethrough(deleted)
                        .bold(chat.boldMessage)
                        .italic(post.isAction)
                }
                if let url = segment.url?.url(animated: chat.animatedEmotes) {
                    if chat.animatedEmotes {
                        AnimatedEmoteView(url: url)
                            .padding(.vertical, chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: frameHeightEmotes())
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            EmptyView()
                        }
                        .padding(.vertical, chat.shadowColorEnabled ? 1.5 : 0)
                        .frame(height: frameHeightEmotes())
                        .opacity(imageOpacity())
                    }
                    Text(" ")
                }
                if let url = segment.bigGifUrl?.url(animated: chat.animatedEmotes) {
                    ChatGifView(
                        url: url,
                        animated: chat.animatedEmotes,
                        height: CGFloat(chat.fontSize * chatEmoteScale * chat.bigGifScale)
                    )
                    .padding(.vertical, chat.shadowColorEnabled ? 1.5 : 0)
                    .opacity(imageOpacity())
                    Text(" ")
                }
            }
        }
        .stroke(color: shadowColor(), width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding(.leading, 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundStyle(.white)
        .cornerRadius(5)
    }
}

private let startId = UUID()

private struct PostView: View {
    let chatSettings: SettingsChat
    let moreThanOneStreamingPlatform: Bool
    let post: ChatPost
    @ObservedObject var state: ChatPostState
    let width: CGFloat

    var body: some View {
        if post.user != nil {
            if !state.deleted || chatSettings.showDeletedMessages {
                if let highlight = post.highlight {
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 3)
                            .foregroundStyle(highlight.barColor)
                        if chatSettings.compactEvents {
                            HighlightImageView(chat: chatSettings, highlight: highlight)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            if !chatSettings.compactEvents {
                                HighlightMessageView(postState: post.state,
                                                     chat: chatSettings,
                                                     highlight: highlight)
                            }
                            LineView(deleted: state.deleted,
                                     post: post,
                                     chat: chatSettings,
                                     platform: moreThanOneStreamingPlatform)
                        }
                    }
                } else {
                    LineView(deleted: state.deleted,
                             post: post,
                             chat: chatSettings,
                             platform: moreThanOneStreamingPlatform)
                        .padding(.leading, 3)
                }
            }
        } else {
            Rectangle()
                .fill(.red)
                .frame(width: width, height: 1.5)
                .padding(2)
        }
    }
}

private struct MessagesView: View {
    let model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    let width: CGFloat

    private func tryPause() {
        guard chat.interactiveChat else {
            return
        }
        if !chat.paused {
            if !chat.posts.isEmpty {
                model.pauseChat(chat: chat)
            }
        }
    }

    private func tryUnpause() {
        guard chat.interactiveChat else {
            return
        }
        if chat.paused {
            model.endOfChatReachedWhenPaused(chat: chat)
        }
    }

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
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
                                 moreThanOneStreamingPlatform: chat.moreThanOneStreamingPlatform,
                                 post: post,
                                 state: post.state,
                                 width: width)
                            .rotationEffect(Angle(degrees: rotation))
                            .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                    }
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(.white)
            .rotationEffect(Angle(degrees: rotation))
            .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
            .frame(width: width)
            .allowsHitTesting(chat.interactiveChat)
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

private struct ChatPausedView: View {
    @ObservedObject var chat: ChatProvider
    let alerts: Bool

    private func message() -> String {
        if alerts {
            String(localized: "Chat paused: \(chat.pausedPostsCount) new alerts")
        } else {
            String(localized: "Chat paused: \(chat.pausedPostsCount) new messages")
        }
    }

    var body: some View {
        if chat.paused {
            ChatInfo(message: message())
                .padding(2)
        }
    }
}

private let separatorHeight = 2.0

private struct ChatLabelView: View {
    @ObservedObject var chat: ChatProvider
    let message: String
    let alignment: Alignment

    var body: some View {
        if chat.showLabel {
            Text(message)
                .bold()
                .foregroundStyle(.white)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(backgroundColor)
                .cornerRadius(10)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .allowsHitTesting(false)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SeparatorView: View {
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var activityFeed: ChatProvider
    let width: CGFloat
    let height: CGFloat
    let activityFeedHeight: CGFloat
    @Binding var draggedActivityFeedHeight: Double?
    @State private var dragStartActivityFeedHeight: Double?
    @State private var hasNewPosts = false
    @State private var hideNewPostsTimer = SimpleTimer(queue: .main)

    private func handleNewPost() {
        guard activityFeedHeight == 0 else {
            return
        }
        hasNewPosts = true
        hideNewPostsTimer.startSingleShot(timeout: 60) {
            hasNewPosts = false
        }
    }

    private func clearNewPosts() {
        hideNewPostsTimer.stop()
        hasNewPosts = false
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if activityFeed.showLabel || activityFeedHeight > 0 {
                Rectangle()
                    .fill(.white)
                    .frame(width: width, height: separatorHeight)
            }
            HStack(spacing: 4) {
                Triangle()
                    .fill(.white)
                    .frame(width: 12, height: 10)
                if hasNewPosts {
                    Text("New")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.black)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(width: width, height: separatorHeight, alignment: .leading)
        .onChange(of: activityFeed.posts.first?.id) { _ in
            handleNewPost()
        }
        .onChange(of: activityFeed.pausedPostsCount) { _ in
            if activityFeed.pausedPostsCount > 0 {
                handleNewPost()
            }
        }
        .onChange(of: activityFeedHeight) { _ in
            clearNewPosts()
        }
        .onDisappear {
            clearNewPosts()
        }
        .overlay {
            Color.clear
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            let start = dragStartActivityFeedHeight ?? chatSettings.activityFeedHeight
                            dragStartActivityFeedHeight = start
                            draggedActivityFeedHeight = (start + value.translation.height / height)
                                .clamped(to: 0 ... 1)
                        }
                        .onEnded { _ in
                            dragStartActivityFeedHeight = nil
                            if let draggedActivityFeedHeight {
                                chatSettings.activityFeedHeight = draggedActivityFeedHeight
                            }
                            draggedActivityFeedHeight = nil
                        }
                )
        }
    }
}

struct StreamOverlayChatView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var chatSettings: SettingsChat
    let chat: ChatProvider
    let chatActivityFeed: ChatProvider
    let fullSize: Bool

    @State private var draggedAlertsHeight: Double?

    private func heightFactor() -> CGFloat {
        if fullSize || database.appMode == .chatPhone {
            1
        } else {
            chatSettings.height
        }
    }

    private func widthFactor() -> CGFloat {
        if fullSize || database.appMode == .chatPhone {
            1
        } else {
            chatSettings.width
        }
    }

    var body: some View {
        GeometryReader { metrics in
            let width = metrics.size.width * widthFactor()
            let height = metrics.size.height * heightFactor()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if chatSettings.activityFeed {
                    let splitHeight = height - separatorHeight
                    let alertsHeight = splitHeight * (draggedAlertsHeight ?? chatSettings.activityFeedHeight)
                    MessagesView(model: model,
                                 chatSettings: chatSettings,
                                 chat: chatActivityFeed,
                                 width: width)
                        .overlay {
                            if alertsHeight > 10 {
                                ChatPausedView(chat: chatActivityFeed, alerts: true)
                            }
                        }
                        .overlay {
                            if alertsHeight > 40 {
                                ChatLabelView(chat: chatActivityFeed,
                                              message: String(localized: "Activity feed"),
                                              alignment: .bottom)
                            }
                        }
                        .frame(height: alertsHeight)
                    SeparatorView(chatSettings: chatSettings,
                                  activityFeed: chatActivityFeed,
                                  width: width,
                                  height: splitHeight,
                                  activityFeedHeight: alertsHeight,
                                  draggedActivityFeedHeight: $draggedAlertsHeight)
                        .zIndex(1)
                    MessagesView(model: model,
                                 chatSettings: chatSettings,
                                 chat: chat,
                                 width: width)
                        .overlay {
                            ChatPausedView(chat: chat, alerts: false)
                        }
                        .overlay {
                            if splitHeight - alertsHeight > 40 {
                                ChatLabelView(chat: chat,
                                              message: String(localized: "Chat"),
                                              alignment: .top)
                            }
                        }
                        .frame(height: splitHeight - alertsHeight)
                } else {
                    MessagesView(model: model,
                                 chatSettings: chatSettings,
                                 chat: chat,
                                 width: width)
                        .overlay {
                            ChatPausedView(chat: chat, alerts: false)
                        }
                        .frame(height: height)
                }
            }
        }
    }
}
