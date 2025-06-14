import Collections
import Foundation
import SwiftUI
import WrappingHStack

let maximumNumberOfChatMessages = 50
let maximumNumberOfInteractiveChatMessages = 100

struct ChatMessageEmote: Identifiable {
    var id = UUID()
    var url: URL
    var range: ClosedRange<Int>
}

struct ChatPostSegment: Identifiable, Codable {
    var id: Int
    var text: String?
    var url: URL?
}

func makeChatPostTextSegments(text: String, id: inout Int) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for word in text.split(separator: " ") {
        segments.append(ChatPostSegment(
            id: id,
            text: "\(word) "
        ))
        id += 1
    }
    return segments
}

enum ChatHighlightKind: Codable {
    case redemption
    case other
    case firstMessage
    case newFollower
    case reply
}

struct ChatHighlight {
    let kind: ChatHighlightKind
    let color: Color
    let image: String
    let title: String

    func toWatchProtocol() -> WatchProtocolChatHighlight {
        let watchProtocolKind: WatchProtocolChatHighlightKind
        switch kind {
        case .redemption:
            watchProtocolKind = .redemption
        case .other:
            watchProtocolKind = .other
        case .newFollower:
            watchProtocolKind = .redemption
        case .firstMessage:
            watchProtocolKind = .other
        case .reply:
            watchProtocolKind = .other
        }
        let color = color.toRgb() ?? .init(red: 0, green: 255, blue: 0)
        return WatchProtocolChatHighlight(
            kind: watchProtocolKind,
            color: .init(red: color.red, green: color.green, blue: color.blue),
            image: image,
            title: title
        )
    }
}

struct ChatPost: Identifiable, Equatable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func isRedemption() -> Bool {
        return highlight?.kind == .redemption || highlight?.kind == .newFollower
    }

    var id: Int
    var user: String?
    var userColor: RgbColor
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var timestampTime: ContinuousClock.Instant
    var isAction: Bool
    var isSubscriber: Bool
    var bits: String?
    var highlight: ChatHighlight?
    var live: Bool
    var filter: SettingsChatFilter?
    var platform: Platform?
}

class ChatProvider: ObservableObject {
    var newPosts: Deque<ChatPost> = []
    var pausedPosts: Deque<ChatPost> = []
    @Published var posts: Deque<ChatPost> = []
    @Published var pausedPostsCount: Int = 0
    @Published var paused = false
    private let maximumNumberOfMessages: Int
    @Published var moreThanOneStreamingPlatform = false
    @Published var interactiveChat = false

    init(maximumNumberOfMessages: Int) {
        self.maximumNumberOfMessages = maximumNumberOfMessages
    }

    func reset() {
        posts = []
        pausedPosts = []
        newPosts = []
    }

    func appendMessage(post: ChatPost) {
        if paused {
            if pausedPosts.count < 2 * maximumNumberOfMessages {
                pausedPosts.append(post)
            }
        } else {
            newPosts.append(post)
        }
    }

    func update() {
        if paused {
            let count = max(pausedPosts.count - 1, 0)
            if count != pausedPostsCount {
                pausedPostsCount = count
            }
        } else {
            while let post = newPosts.popFirst() {
                if posts.count > maximumNumberOfMessages - 1 {
                    posts.removeLast()
                }
                posts.prepend(post)
            }
        }
    }
}

extension Model {
    func pauseChat() {
        chat.paused = true
        chat.pausedPostsCount = 0
        chat.pausedPosts = [createRedLineChatPost()]
    }

    func disableInteractiveChat() {
        _ = appendPausedChatPosts(maximumNumberOfPostsToAppend: Int.max)
        chat.paused = false
    }

    private func createRedLineChatPost() -> ChatPost {
        defer {
            chatPostId += 1
        }
        return ChatPost(
            id: chatPostId,
            user: nil,
            userColor: .init(red: 0, green: 0, blue: 0),
            userBadges: [],
            segments: [],
            timestamp: "",
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            bits: nil,
            highlight: nil,
            live: true,
            filter: nil,
            platform: nil
        )
    }

    func pauseQuickButtonChat() {
        quickButtonChat.paused = true
        quickButtonChat.pausedPostsCount = 0
        quickButtonChat.pausedPosts = [createRedLineChatPost()]
    }

    func endOfQuickButtonChatReachedWhenPaused() {
        while let post = quickButtonChat.pausedPosts.popFirst() {
            if post.user == nil {
                if let lastPost = quickButtonChat.posts.first, lastPost.user == nil {
                    continue
                }
                if quickButtonChat.pausedPosts.isEmpty {
                    continue
                }
            }
            if quickButtonChat.posts.count > maximumNumberOfInteractiveChatMessages - 1 {
                quickButtonChat.posts.removeLast()
            }
            quickButtonChat.posts.prepend(post)
        }
        quickButtonChat.paused = false
    }

    func endOfChatReachedWhenPaused() {
        _ = appendPausedChatPosts(maximumNumberOfPostsToAppend: Int.max)
        chat.paused = false
    }

    private func appendPausedChatPosts(maximumNumberOfPostsToAppend: Int) -> Int {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < maximumNumberOfPostsToAppend, let post = chat.pausedPosts.popFirst() {
            if post.user == nil {
                if let lastPost = chat.posts.first, lastPost.user == nil {
                    continue
                }
                if chat.pausedPosts.isEmpty {
                    continue
                }
            }
            if chat.posts.count > maximumNumberOfChatMessages - 1 {
                chat.posts.removeLast()
            }
            chat.posts.prepend(post)
            numberOfPostsAppended += 1
        }
        return numberOfPostsAppended
    }

    func pauseQuickButtonChatAlerts() {
        quickButtonChatAlertsPaused = true
        pausedQuickButtonChatAlertsPostsCount = 0
    }

    func endOfQuickButtonChatAlertsReachedWhenPaused() {
        while let post = pausedQuickButtonChatAlertsPosts.popFirst() {
            if post.user == nil {
                if let lastPost = quickButtonChatAlertsPosts.first, lastPost.user == nil {
                    continue
                }
                if pausedQuickButtonChatAlertsPosts.isEmpty {
                    continue
                }
            }
            if quickButtonChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                quickButtonChatAlertsPosts.removeLast()
            }
            quickButtonChatAlertsPosts.prepend(post)
        }
        quickButtonChatAlertsPaused = false
    }

    func removeOldChatMessages(now: ContinuousClock.Instant) {
        if quickButtonChat.paused {
            return
        }
        guard database.chat.maximumAgeEnabled else {
            return
        }
        while let post = chat.posts.last {
            if now > post.timestampTime + .seconds(database.chat.maximumAge) {
                chat.posts.removeLast()
            } else {
                break
            }
        }
    }

    func updateChat() {
        while let post = chat.newPosts.popFirst() {
            if chat.posts.count > maximumNumberOfChatMessages - 1 {
                chat.posts.removeLast()
            }
            if post.filter?.showOnScreen != false {
                chat.posts.prepend(post)
                if isWatchLocal() {
                    sendChatMessageToWatch(post: post)
                }
            }
            if isTextToSpeechEnabledForMessage(post: post), let user = post.user {
                let message = post.segments.filter { $0.text != nil }.map { $0.text! }.joined(separator: "")
                if !message.trimmingCharacters(in: .whitespaces).isEmpty {
                    chatTextToSpeech.say(user: user, message: message, isRedemption: post.isRedemption())
                }
            }
            if post.filter?.print != false, isAnyConnectedCatPrinterPrintingChat() {
                printChatMessage(post: post)
            }
            streamTotalChatMessages += 1
        }
        chat.update()
        quickButtonChat.update()
        if externalDisplayChatEnabled {
            externalDisplayChat.update()
        }
        if quickButtonChatAlertsPaused {
            // The red line is one post.
            pausedQuickButtonChatAlertsPostsCount = max(pausedQuickButtonChatAlertsPosts.count - 1, 0)
        } else {
            while let post = newQuickButtonChatAlertsPosts.popFirst() {
                if quickButtonChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                    quickButtonChatAlertsPosts.removeLast()
                }
                quickButtonChatAlertsPosts.prepend(post)
            }
        }
    }

    func isAlertMessage(post: ChatPost) -> Bool {
        switch post.highlight?.kind {
        case .redemption:
            return true
        case .newFollower:
            return true
        default:
            return false
        }
    }

    func reloadChats() {
        reloadTwitchChat()
        reloadKickPusher()
        reloadYouTubeLiveChat()
        reloadAfreecaTvChat()
        reloadOpenStreamingPlatformChat()
    }

    func updateChatMoreThanOneChatConfigured() {
        chat.moreThanOneStreamingPlatform = isMoreThanOneChatConfigured()
    }

    private func isMoreThanOneChatConfigured() -> Bool {
        var numberOfChats = 0
        if isTwitchChatConfigured() {
            numberOfChats += 1
        }
        if isKickPusherConfigured() {
            numberOfChats += 1
        }
        if isYouTubeLiveChatConfigured() {
            numberOfChats += 1
        }
        if isAfreecaTvChatConfigured() {
            numberOfChats += 1
        }
        if isOpenStreamingPlatformChatConfigured() {
            numberOfChats += 1
        }
        return numberOfChats > 1
    }

    func isChatConfigured() -> Bool {
        return isTwitchChatConfigured() || isKickPusherConfigured() ||
            isYouTubeLiveChatConfigured() || isAfreecaTvChatConfigured() ||
            isOpenStreamingPlatformChatConfigured()
    }

    func isChatRemoteControl() -> Bool {
        return useRemoteControlForChatAndEvents && database.debug.reliableChat
    }

    func isChatConnected() -> Bool {
        if isTwitchChatConfigured() && !isTwitchChatConnected() {
            return false
        }
        if isKickPusherConfigured() && !isKickPusherConnected() {
            return false
        }
        if isYouTubeLiveChatConfigured() && !isYouTubeLiveChatConnected() {
            return false
        }
        if isAfreecaTvChatConfigured() && !isAfreecaTvChatConnected() {
            return false
        }
        if isOpenStreamingPlatformChatConfigured() && !isOpenStreamingPlatformChatConnected() {
            return false
        }
        return true
    }

    func hasChatEmotes() -> Bool {
        return hasTwitchChatEmotes() || hasKickPusherEmotes() ||
            hasYouTubeLiveChatEmotes() || hasAfreecaTvChatEmotes() || hasOpenStreamingPlatformChatEmotes()
    }

    func resetChat() {
        chat.reset()
        quickButtonChat.reset()
        externalDisplayChat.reset()
        quickButtonChatAlertsPosts = []
        pausedQuickButtonChatAlertsPosts = []
        newQuickButtonChatAlertsPosts = []
        chatBotMessages = []
        chatTextToSpeech.reset(running: true)
        remoteControlStreamerLatestReceivedChatMessageId = -1
    }

    func sendChatMessage(message: String) {
        guard isTwitchAccessTokenConfigured() else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken, urlSession)
            .sendChatMessage(broadcasterId: stream.twitchChannelId, message: message) { ok in
                if !ok {
                    self.makeErrorToast(title: "Failed to send chat message")
                }
            }
    }

    private func evaluateFilters(user: String?, segments: [ChatPostSegment]) -> SettingsChatFilter? {
        return database.chat.filters.first(where: { $0.isMatching(user: user, segments: segments) })
    }

    func appendChatMessage(
        platform: Platform,
        user: String?,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        timestamp: String,
        timestampTime: ContinuousClock.Instant,
        isAction: Bool,
        isSubscriber: Bool,
        isModerator: Bool,
        bits: String?,
        highlight: ChatHighlight?,
        live: Bool
    ) {
        let filter = evaluateFilters(user: user, segments: segments)
        if database.chat.botEnabled, live, filter?.chatBot != false,
           segments.first?.text?.trim().lowercased() == "!moblin"
        {
            if chatBotMessages.count < 25 || isModerator {
                chatBotMessages.append(ChatBotMessage(
                    platform: platform,
                    user: user,
                    isModerator: isModerator,
                    isSubscriber: isSubscriber,
                    userId: userId,
                    segments: segments
                ))
            }
        }
        if pollEnabled, live, filter?.poll != false {
            handlePollVote(vote: segments.first?.text?.trim())
        }
        let post = ChatPost(
            id: chatPostId,
            user: user,
            userColor: userColor?.makeReadableOnDarkBackground() ?? database.chat.usernameColor,
            userBadges: userBadges,
            segments: segments,
            timestamp: timestamp,
            timestampTime: timestampTime,
            isAction: isAction,
            isSubscriber: isSubscriber,
            bits: bits,
            highlight: highlight,
            live: live,
            filter: filter,
            platform: platform
        )
        chatPostId += 1
        if filter?.showOnScreen != false || filter?.textToSpeech != false {
            chat.appendMessage(post: post)
        }
        if filter?.showOnScreen != false {
            quickButtonChat.appendMessage(post: post)
            for browserEffect in browserEffects.values {
                browserEffect.sendChatMessage(post: post)
            }
            if externalDisplayChatEnabled {
                externalDisplayChat.appendMessage(post: post)
            }
            if highlight != nil {
                if quickButtonChatAlertsPaused {
                    if pausedQuickButtonChatAlertsPosts.count < 2 * maximumNumberOfInteractiveChatMessages {
                        pausedQuickButtonChatAlertsPosts.append(post)
                    }
                } else {
                    newQuickButtonChatAlertsPosts.append(post)
                }
            }
        }
    }

    func reloadChatMessages() {
        chat.posts = newPostIds(posts: chat.posts)
        quickButtonChat.posts = newPostIds(posts: quickButtonChat.posts)
        externalDisplayChat.posts = newPostIds(posts: externalDisplayChat.posts)
        quickButtonChatAlertsPosts = newPostIds(posts: quickButtonChatAlertsPosts)
    }

    private func newPostIds(posts: Deque<ChatPost>) -> Deque<ChatPost> {
        var newPosts: Deque<ChatPost> = []
        for post in posts {
            var newPost = post
            newPost.id = chatPostId
            chatPostId += 1
            newPosts.append(newPost)
        }
        return newPosts
    }

    func isShowingStatusChat() -> Bool {
        return database.show.chat && isChatConfigured()
    }

    func updateStatusChatText() {
        let status: String
        if !isChatConfigured() {
            status = String(localized: "Not configured")
        } else if isChatRemoteControl() {
            if isRemoteControlStreamerConnected() {
                status = String(localized: "Connected (remote control)")
            } else {
                status = String(localized: "Disconnected (remote control)")
            }
        } else if isChatConnected() {
            status = String(localized: "Connected")
        } else {
            status = String(localized: "Disconnected")
        }
        if status != statusChatText {
            statusChatText = status
        }
    }

    func printChatMessage(post: ChatPost) {
        // Delay 2 seconds to likely have emotes fetched.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let message = HStack {
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    fitContentWidth: true
                ) {
                    Text(post.user!)
                        .lineLimit(1)
                        .padding([.trailing], 0)
                    if post.isRedemption() {
                        Text(" ")
                    } else {
                        Text(": ")
                    }
                    ForEach(post.segments) { segment in
                        if let text = segment.text {
                            Text(text)
                        }
                        if let url = segment.url {
                            CacheAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image("AppIconNoBackground")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                            .frame(height: 45)
                            Text(" ")
                        }
                    }
                }
                .foregroundColor(.black)
                .font(.system(size: CGFloat(30), weight: .bold, design: .default))
                Spacer()
            }
            .frame(width: 384)
            let renderer = ImageRenderer(content: message)
            guard let image = renderer.uiImage else {
                return
            }
            guard let ciImage = CIImage(image: image) else {
                return
            }
            for catPrinter in self.catPrinters.values
                where self.getCatPrinterSettings(catPrinter: catPrinter)?.printChat == true
            {
                catPrinter.print(image: ciImage, feedPaperDelay: 3)
            }
        }
    }
}
