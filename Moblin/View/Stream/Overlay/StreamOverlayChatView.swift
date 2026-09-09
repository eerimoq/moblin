import Collections
import SwiftUI

private func makeChatLineStyle(chat: SettingsChat) -> ChatLineStyle {
    ChatLineStyle(
        fontSize: CGFloat(chat.fontSize),
        borderColor: chat.shadowColorEnabled ? chat.shadowColor.uiColor() : nil,
        borderWidth: 1.5,
        backgroundColor: chat.backgroundColorEnabled ? chat.backgroundColor.uiColor()
            .withAlphaComponent(0.6) : nil,
        timestampColor: chat.timestampColorEnabled ? chat.timestampColor.uiColor() : nil,
        messageColor: chat.messageColor.uiColor(),
        meInUsernameColor: chat.meInUsernameColor,
        boldUsername: chat.boldUsername,
        boldMessage: chat.boldMessage,
        badges: chat.badges,
        sharedChatIcons: chat.sharedChatIcons,
        animatedEmotes: chat.animatedEmotes,
        bigGifScale: chat.bigGifScale,
        highlightSymbolColor: .white,
        highlightDefaultColor: chat.messageColorColor,
        nicknames: chat.nicknames,
        displayStyle: chat.displayStyle
    )
}

private struct HighlightMessageView: View {
    let deleted: Bool
    let style: ChatLineStyle
    let highlight: ChatHighlight

    var body: some View {
        if let titleSegments = highlight.titleSegments {
            ChatLineView(content: style.makeHighlightContent(highlight: highlight,
                                                             titleSegments: titleSegments,
                                                             deleted: deleted))
        }
    }
}

private struct HighlightImageView: View {
    let style: ChatLineStyle
    let highlight: ChatHighlight

    private func content() -> ChatLineContent {
        var style = style
        style.backgroundColor = nil
        return style.makeHighlightImageContent(highlight: highlight)
    }

    var body: some View {
        ChatLineView(content: content())
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

private let startId = UUID()

private struct PostView: View {
    let chatSettings: SettingsChat
    let style: ChatLineStyle
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
                            HighlightImageView(style: style, highlight: highlight)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            if !chatSettings.compactEvents {
                                HighlightMessageView(deleted: state.deleted,
                                                     style: style,
                                                     highlight: highlight)
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
        let style = makeChatLineStyle(chat: chatSettings)
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
                                 style: style,
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
        if fullSize {
            1
        } else if database.appMode == .chatPhone {
            0.96
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
