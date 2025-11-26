import Collections
import Foundation
import SwiftUI
import WrappingHStack

let maximumNumberOfChatMessages = 50
let maximumNumberOfInteractiveChatMessages = 100

enum ChatPlatformSelection: CaseIterable {
    case all
    case twitch
    case kick
}

extension Model {
    func getAvailableChatPlatforms() -> [ChatPlatformSelection] {
        var platforms: [ChatPlatformSelection] = []
        let hasTwitch = stream.twitchLoggedIn
        let hasKick = stream.kickLoggedIn
        if hasTwitch, hasKick {
            platforms.append(.all)
        }
        if hasTwitch {
            platforms.append(.twitch)
        }
        if hasKick {
            platforms.append(.kick)
        }
        if !platforms.contains(selectedChatPlatform) {
            if platforms.contains(.all) {
                selectedChatPlatform = .all
            } else if let firstPlatform = platforms.first {
                selectedChatPlatform = firstPlatform
            }
        }
        return platforms
    }

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
            messageId: nil,
            displayName: nil,
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
            platform: nil,
            state: ChatPostState()
        )
    }

    func pauseQuickButtonChat() {
        quickButtonChat.paused = true
        quickButtonChat.pausedPostsCount = 0
        quickButtonChat.pausedPosts = [createRedLineChatPost()]
    }

    func endOfQuickButtonChatReachedWhenPaused() {
        while let post = quickButtonChat.pausedPosts.popFirst() {
            if post.isRedLine() {
                if quickButtonChat.posts.first?.isRedLine() == true {
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
            if post.isRedLine() {
                if chat.posts.first?.isRedLine() == true {
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
        quickButtonChatState.chatAlertsPaused = true
        quickButtonChatState.pausedChatAlertsPostsCount = 0
    }

    func endOfQuickButtonChatAlertsReachedWhenPaused() {
        while let post = pausedQuickButtonChatAlertsPosts.popFirst() {
            if post.isRedLine() {
                if quickButtonChatState.chatAlertsPosts.first?.isRedLine() == true {
                    continue
                }
                if pausedQuickButtonChatAlertsPosts.isEmpty {
                    continue
                }
            }
            if quickButtonChatState.chatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                quickButtonChatState.chatAlertsPosts.removeLast()
            }
            quickButtonChatState.chatAlertsPosts.prepend(post)
        }
        quickButtonChatState.chatAlertsPaused = false
    }

    func removeOldChatMessages(now: ContinuousClock.Instant) {
        if chat.paused {
            return
        }
        guard database.chat.maximumAgeEnabled else {
            return
        }
        while let post = chat.posts.last {
            if post.timestampTime.duration(to: now) > .seconds(database.chat.maximumAge) {
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
            streamTotalChatMessages += 1
        }
        chat.update()
        quickButtonChat.update()
        if externalDisplay.chatEnabled {
            externalDisplayChat.update()
        }
        if quickButtonChatState.chatAlertsPaused {
            quickButtonChatState.pausedChatAlertsPostsCount = max(pausedQuickButtonChatAlertsPosts.count - 1, 0)
        } else {
            while let post = newQuickButtonChatAlertsPosts.popFirst() {
                if quickButtonChatState.chatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                    quickButtonChatState.chatAlertsPosts.removeLast()
                }
                quickButtonChatState.chatAlertsPosts.prepend(post)
            }
        }
        chatWidgetChat.update()
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
        reloadDLiveChat()
        reloadYouTubeLiveChat()
        reloadSoopChat()
        reloadOpenStreamingPlatformChat()
    }

    func updateChatMoreThanOneChatConfigured() {
        let moreThanOneStreamingPlatform = isMoreThanOneChatConfigured()
        chat.moreThanOneStreamingPlatform = moreThanOneStreamingPlatform
        quickButtonChat.moreThanOneStreamingPlatform = moreThanOneStreamingPlatform
        externalDisplayChat.moreThanOneStreamingPlatform = moreThanOneStreamingPlatform
        chatWidgetChat.moreThanOneStreamingPlatform = moreThanOneStreamingPlatform
    }

    private func isMoreThanOneChatConfigured() -> Bool {
        var numberOfChats = 0
        if isTwitchChatConfigured() {
            numberOfChats += 1
        }
        if isKickPusherConfigured() {
            numberOfChats += 1
        }
        if isDLiveChatConfigured() {
            numberOfChats += 1
        }
        if isYouTubeLiveChatConfigured() {
            numberOfChats += 1
        }
        if isSoopChatConfigured() {
            numberOfChats += 1
        }
        if isOpenStreamingPlatformChatConfigured() {
            numberOfChats += 1
        }
        return numberOfChats > 1
    }

    func isChatConfigured() -> Bool {
        return isTwitchChatConfigured() || isKickPusherConfigured() ||
            isYouTubeLiveChatConfigured() || isSoopChatConfigured() ||
            isDLiveChatConfigured() || isOpenStreamingPlatformChatConfigured()
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
        if isSoopChatConfigured() && !isSoopChatConnected() {
            return false
        }
        if isOpenStreamingPlatformChatConfigured() && !isOpenStreamingPlatformChatConnected() {
            return false
        }
        if isDLiveChatConfigured() && !isDLiveChatConnected() {
            return false
        }
        return true
    }

    func hasChatEmotes() -> Bool {
        return hasTwitchChatEmotes()
            || hasKickPusherEmotes()
            || hasYouTubeLiveChatEmotes()
            || hasSoopChatEmotes()
            || hasOpenStreamingPlatformChatEmotes()
            || hasDLiveChatEmotes()
    }

    func resetChat() {
        chatTextToSpeech.reset(running: true)
    }

    func sendChatMessage(message: String) {
        var messageSent = false
        if stream.twitchSendMessagesTo, stream.twitchLoggedIn {
            sendTwitchChatMessage(message: message)
            messageSent = true
        }
        if stream.kickSendMessagesTo, stream.kickLoggedIn {
            sendKickChatMessage(message: message)
            messageSent = true
        }
        if !messageSent {
            if stream.twitchSendMessagesTo, stream.kickSendMessagesTo {
                makeErrorToast(title: String(localized: "Please login to a streaming platform"))
            } else if stream.twitchSendMessagesTo, !stream.twitchLoggedIn {
                makeNotLoggedInToTwitchToast()
            } else if stream.kickSendMessagesTo, !stream.kickLoggedIn {
                makeNotLoggedInToKickToast()
            }
        }
    }

    private func evaluateFilters(user: String?, segments: [ChatPostSegment]) -> SettingsChatFilter? {
        return database.chat.filters.first(where: { $0.isMatching(user: user, segments: segments) })
    }

    func appendChatMessage(
        platform: Platform,
        messageId: String?,
        displayName: String?,
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
        isOwner: Bool,
        bits: String?,
        highlight: ChatHighlight?,
        live: Bool
    ) {
        let filter = evaluateFilters(user: user, segments: segments)
        if database.chat.botEnabled, live, filter?.chatBot != false,
           segments.first?.text?.trim().starts(with: "!") == true
        {
            if chatBotMessages.count < 25 || isModerator {
                chatBotMessages.append(ChatBotMessage(
                    platform: platform,
                    user: user,
                    isOwner: isOwner,
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
            messageId: messageId,
            displayName: displayName,
            user: user,
            userId: userId,
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
            platform: platform,
            state: ChatPostState()
        )
        chatPostId += 1
        if isTextToSpeechEnabledForMessage(post: post) {
            let message = post.text()
            if !message.trimmingCharacters(in: .whitespaces).isEmpty {
                chatTextToSpeech.say(
                    messageId: post.messageId,
                    user: post.shortDisplayName(nicknames: database.chat.nicknames),
                    userId: post.userId,
                    message: message,
                    isRedemption: post.isRedemption()
                )
            }
        }
        if filter?.print != false, isAnyConnectedCatPrinterPrintingChat() {
            printChatMessage(post: post)
        }
        if filter?.showOnScreen != false {
            chat.appendMessage(post: post)
        }
        if filter?.showOnScreen != false {
            quickButtonChat.appendMessage(post: post)
            for browserEffect in browserEffects.values {
                browserEffect.sendChatMessage(post: post)
            }
            if externalDisplay.chatEnabled {
                externalDisplayChat.appendMessage(post: post)
            }
            if highlight != nil {
                if quickButtonChatState.chatAlertsPaused {
                    if pausedQuickButtonChatAlertsPosts.count < 2 * maximumNumberOfInteractiveChatMessages {
                        pausedQuickButtonChatAlertsPosts.append(post)
                    }
                } else {
                    newQuickButtonChatAlertsPosts.append(post)
                }
            }
        }
        if !enabledChatEffects.isEmpty {
            chatWidgetChat.appendMessage(post: post)
        }
    }

    func reloadChatMessages() {
        chat.posts = newPostIds(posts: chat.posts)
        quickButtonChat.posts = newPostIds(posts: quickButtonChat.posts)
        externalDisplayChat.posts = newPostIds(posts: externalDisplayChat.posts)
        chatWidgetChat.posts = newPostIds(posts: chatWidgetChat.posts)
        quickButtonChatState.chatAlertsPosts = newPostIds(posts: quickButtonChatState.chatAlertsPosts)
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
        if status != statusTopLeft.statusChatText {
            statusTopLeft.statusChatText = status
        }
    }

    func printChatMessage(post: ChatPost) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let message = HStack {
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    fitContentWidth: true
                ) {
                    let chat = self.database.chat
                    Text(post.displayName(nicknames: chat.nicknames, displayStyle: chat.displayStyle))
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
                .foregroundStyle(.black)
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

    func banUser(post: ChatPost) {
        guard let user = post.user else {
            return
        }
        switch post.platform {
        case .twitch:
            guard let userId = post.userId else {
                return
            }
            banTwitchUser(user: user, userId: userId, duration: nil)
        case .kick:
            banKickUser(user: user, duration: nil)
        default:
            makeErrorToast(title: "Ban not supported for this platform")
        }
    }

    func timeoutUser(post: ChatPost, duration: Int) {
        guard let user = post.user else {
            return
        }
        switch post.platform {
        case .twitch:
            guard let userId = post.userId else {
                return
            }
            banTwitchUser(user: user, userId: userId, duration: duration)
        case .kick:
            banKickUser(user: user, duration: duration)
        default:
            makeErrorToast(title: "Timeout not supported for this platform")
        }
    }

    func deleteMessage(post: ChatPost) {
        guard let messageId = post.messageId else {
            return
        }
        switch post.platform {
        case .twitch:
            deleteTwitchChatMessage(messageId: messageId)
        case .kick:
            deleteKickMessage(messageId: messageId)
        default:
            makeErrorToast(title: "Delete message not supported for this platform")
        }
    }

    func copyMessage(post: ChatPost) {
        UIPasteboard.general.string = post.text()
        makeToast(title: String(localized: "Message copied to clipboard"))
    }

    func deleteChatMessage(messageId: String) {
        chat.deleteMessage(messageId: messageId)
        quickButtonChat.deleteMessage(messageId: messageId)
        externalDisplayChat.deleteMessage(messageId: messageId)
        chatWidgetChat.deleteMessage(messageId: messageId)
        chatTextToSpeech.delete(messageId: messageId)
    }

    func deleteChatUser(userId: String) {
        chat.deleteUser(userId: userId)
        quickButtonChat.deleteUser(userId: userId)
        externalDisplayChat.deleteUser(userId: userId)
        chatWidgetChat.deleteUser(userId: userId)
        chatTextToSpeech.delete(userId: userId)
    }
}
