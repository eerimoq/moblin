import Foundation

private struct Badge: Decodable {
    var type: String
    var text: String?
    var count: Int?
}

private enum BadgeType {
    static let verified = "verified"
    static let staff = "staff"
    static let moderator = "moderator"
    static let og = "og"
    static let vip = "vip"
    static let bot = "bot"
    static let broadcaster = "broadcaster"
    static let founder = "founder"
    static let subscriber = "subscriber"
    static let subGifter = "sub_gifter"
}

private let badgesBaseUrl = "https://raw.githubusercontent.com/id3adeye/kickicons/refs/heads/main"

private struct KickBadge {
    let months: Int
    let url: URL
}

private class KickBadges {
    private var subscriberBadges: [KickBadge] = []
    private let staticBadges: [String: URL] = [
        BadgeType.verified: URL(string: "\(badgesBaseUrl)/kick-verified.png")!,
        BadgeType.staff: URL(string: "\(badgesBaseUrl)/kick-staff.png")!,
        BadgeType.moderator: URL(string: "\(badgesBaseUrl)/kick-moderator.png")!,
        BadgeType.og: URL(string: "\(badgesBaseUrl)/kick-og.png")!,
        BadgeType.vip: URL(string: "\(badgesBaseUrl)/kick-vip.png")!,
        BadgeType.bot: URL(string: "\(badgesBaseUrl)/kick-bot.png")!,
        BadgeType.broadcaster: URL(string: "\(badgesBaseUrl)/kick-broadcaster.png")!,
        BadgeType.founder: URL(string: "\(badgesBaseUrl)/kick-founder.png")!,
        BadgeType.subGifter: URL(string: "\(badgesBaseUrl)/kick-sub_gifter.png")!,
    ]

    func setBadges(_ badges: [SubscriberBadge]) {
        subscriberBadges.removeAll()
        for badge in badges.sorted(by: { $0.months < $1.months }) {
            if let url = URL(string: badge.badge_image.src) {
                subscriberBadges.append(KickBadge(months: badge.months, url: url))
            }
        }
    }

    func getSubscriberBadgeUrl(months: Int) -> URL? {
        return subscriberBadges.last(where: { months >= $0.months })?.url
    }

    func getStaticBadgeUrl(for badgeType: String) -> URL? {
        return staticBadges[badgeType]
    }
}

private struct Identity: Decodable {
    var color: String
    var badges: [Badge]
}

private struct Sender: Decodable {
    var id: Int?
    var username: String
    var identity: Identity
}

private struct OriginalSender: Decodable {
    var username: String
}

private struct OriginalMessage: Decodable {
    var content: String
}

private struct Metadata: Decodable {
    var original_sender: OriginalSender?
    var original_message: OriginalMessage?
}

private struct ChatMessageEvent: Decodable {
    var id: String?
    var type: String?
    var content: String
    var sender: Sender
    var metadata: Metadata?

    func isModerator() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == BadgeType.moderator })
    }

    func isSubscriber() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == BadgeType.subscriber })
    }
}

private struct Message: Decodable {
    var id: String
}

private struct MessageDeletedEvent: Decodable {
    var message: Message
}

struct User: Decodable {
    var id: Int
    var slug: String
    var username: String
}

struct Moderator: Decodable {
    var id: Int
    var slug: String
    var username: String
}

struct KickPusherUserBannedEvent: Decodable {
    var id: String
    var user: User
    var banned_by: Moderator
    var permanent: Bool
}

struct KickPusherSubscriptionEvent: Decodable {
    var username: String
    var months: Int
}

struct KickPusherGiftedSubscriptionsEvent: Decodable {
    var gifted_usernames: [String]
    var gifter_username: String
    var gifter_total: Int
}

struct KickPusherRewardRedeemedEvent: Decodable {
    var reward_title: String
    var username: String
    var user_input: String
}

struct KickPusherStreamHostEvent: Decodable {
    var host_username: String
    var number_viewers: Int
}

struct KickPusherKickSender: Decodable {
    var id: Int
    var username: String
}

struct KickPusherKickGift: Decodable {
    var name: String
    var amount: Int
}

struct KickPusherKicksGiftedEvent: Decodable {
    var message: String
    var sender: KickPusherKickSender
    var gift: KickPusherKickGift
}

private func decodeEvent(message: String) throws -> (String, String) {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(
            with: jsonData,
            options: JSONSerialization.ReadingOptions.mutableContainers
        )
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type: String = jsonResult["event"] as? String {
                if let data: String = jsonResult["data"] as? String {
                    return (type, data)
                }
            }
        }
    }
    throw "Failed to get message event type"
}

private func decodeChatMessageEvent(data: String) throws -> ChatMessageEvent {
    return try JSONDecoder().decode(ChatMessageEvent.self, from: data.utf8Data)
}

private func decodeMessageDeletedEvent(data: String) throws -> MessageDeletedEvent {
    return try JSONDecoder().decode(MessageDeletedEvent.self, from: data.utf8Data)
}

private func decodeUserBannedEvent(data: String) throws -> KickPusherUserBannedEvent {
    return try JSONDecoder().decode(KickPusherUserBannedEvent.self, from: data.utf8Data)
}

private func decodeSubscriptionEvent(data: String) throws -> KickPusherSubscriptionEvent {
    return try JSONDecoder().decode(KickPusherSubscriptionEvent.self, from: data.utf8Data)
}

private func decodeGiftedSubscriptionsEvent(data: String) throws -> KickPusherGiftedSubscriptionsEvent {
    return try JSONDecoder().decode(KickPusherGiftedSubscriptionsEvent.self, from: data.utf8Data)
}

private func decodeRewardRedeemedEvent(data: String) throws -> KickPusherRewardRedeemedEvent {
    return try JSONDecoder().decode(KickPusherRewardRedeemedEvent.self, from: data.utf8Data)
}

private func decodeStreamHostEvent(data: String) throws -> KickPusherStreamHostEvent {
    return try JSONDecoder().decode(KickPusherStreamHostEvent.self, from: data.utf8Data)
}

private func decodeKicksGiftedEvent(data: String) throws -> KickPusherKicksGiftedEvent {
    return try JSONDecoder().decode(KickPusherKicksGiftedEvent.self, from: data.utf8Data)
}

private var url =
    URL(
        string: "wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=7.6.0&flash=false"
    )!

protocol KickPusherDelegate: AnyObject {
    func kickPusherMakeErrorToast(title: String, subTitle: String?)
    func kickPusherAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool,
        highlight: ChatHighlight?
    )
    func kickPusherDeleteMessage(messageId: String)
    func kickPusherDeleteUser(userId: String)
    func kickPusherSubscription(event: KickPusherSubscriptionEvent)
    func kickPusherGiftedSubscription(event: KickPusherGiftedSubscriptionsEvent)
    func kickPusherRewardRedeemed(event: KickPusherRewardRedeemedEvent)
    func kickPusherStreamHost(event: KickPusherStreamHostEvent)
    func kickPusherUserBanned(event: KickPusherUserBannedEvent)
    func kickPusherKicksGifted(event: KickPusherKicksGiftedEvent)
}

final class KickPusher: NSObject {
    private var channelName: String
    private var channelId: String
    private var chatroomChannelId: String
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var badges: KickBadges
    private let settings: SettingsStreamChat
    private var gotInfo = false
    private weak var delegate: (any KickPusherDelegate)?

    init(
        delegate: KickPusherDelegate,
        channelName: String,
        channelId: String,
        chatroomChannelId: String,
        settings: SettingsStreamChat
    ) {
        self.delegate = delegate
        self.channelName = channelName
        self.channelId = channelId
        self.chatroomChannelId = chatroomChannelId
        self.settings = settings.clone()
        emotes = Emotes()
        badges = KickBadges()
        webSocket = .init(url: url)
    }

    func start() {
        logger.debug("kick: Start")
        stopInternal()
        connect()
        fetchSubscriberBadges()
    }

    private func connect() {
        emotes.stop()
        emotes.start(
            platform: .kick,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        webSocket = .init(url: url)
        webSocket.delegate = self
        webSocket.start()
    }

    func stop() {
        logger.debug("kick: Stop")
        stopInternal()
    }

    func stopInternal() {
        emotes.stop()
        webSocket.stop()
        gotInfo = false
    }

    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func fetchSubscriberBadges() {
        getKickChannelInfo(channelName: channelName) { [weak self] channelInfo in
            DispatchQueue.main.async {
                if let subscriberBadges = channelInfo?.subscriber_badges {
                    self?.badges.setBadges(subscriberBadges)
                }
            }
        }
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.delegate?.kickPusherMakeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleOk(title: String) {
        DispatchQueue.main.async {
            self.delegate?.kickPusherMakeErrorToast(title: title, subTitle: nil)
        }
    }

    private func handleMessage(message: String) {
        do {
            let (type, data) = try decodeEvent(message: message)
            // Handle supported Kick events (no auth required for these)
            switch type {
            case "App\\Events\\ChatMessageEvent":
                try handleChatMessageEvent(data: data)
            case "App\\Events\\MessageDeletedEvent":
                try handleMessageDeletedEvent(data: data)
            case "App\\Events\\UserBannedEvent":
                try handleUserBannedEvent(data: data)
            case "App\\Events\\SubscriptionEvent":
                try handleSubscriptionEvent(data: data)
            case "GiftedSubscriptionsEvent":
                try handleGiftedSubscriptionsEvent(data: data)
            case "RewardRedeemedEvent":
                try handleRewardRedeemedEvent(data: data)
            case "App\\Events\\StreamHostEvent":
                try handleStreamHostEvent(data: data)
            case "KicksGifted":
                try handleKicksGiftedEvent(data: data)
            default:
                logger.debug("kick: pusher: \(channelId): Unsupported type: \(type)")
            }
        } catch {
            logger
                .error("""
                kick: pusher: \(channelId): Failed to process \
                message \"\(message)\" with error \(error)
                """)
        }
    }

    private func handleChatMessageEvent(data: String) throws {
        let event = try decodeChatMessageEvent(data: data)
        var badgeUrls: [URL] = []
        for badge in event.sender.identity.badges {
            if badge.type == BadgeType.subscriber, let months = badge.count {
                if let badgeUrl = badges.getSubscriberBadgeUrl(months: months) {
                    badgeUrls.append(badgeUrl)
                }
            } else if let badgeUrl = badges.getStaticBadgeUrl(for: badge.type) {
                badgeUrls.append(badgeUrl)
            }
        }
        delegate?.kickPusherAppendMessage(
            messageId: event.id,
            user: event.sender.username,
            userId: event.sender.id != nil ? String(event.sender.id!) : nil,
            userColor: RgbColor.fromHex(string: event.sender.identity.color),
            userBadges: badgeUrls,
            segments: makeChatPostSegments(content: event.content),
            isSubscriber: event.isSubscriber(),
            isModerator: event.isModerator(),
            highlight: makeHighlight(message: event)
        )
    }

    private func handleMessageDeletedEvent(data: String) throws {
        let event = try decodeMessageDeletedEvent(data: data)
        delegate?.kickPusherDeleteMessage(messageId: event.message.id)
    }

    private func handleUserBannedEvent(data: String) throws {
        let event = try decodeUserBannedEvent(data: data)
        delegate?.kickPusherDeleteUser(userId: String(event.user.id))
        delegate?.kickPusherUserBanned(event: event)
    }

    private func handleSubscriptionEvent(data: String) throws {
        let event = try decodeSubscriptionEvent(data: data)
        delegate?.kickPusherSubscription(event: event)
    }

    private func handleGiftedSubscriptionsEvent(data: String) throws {
        let event = try decodeGiftedSubscriptionsEvent(data: data)
        delegate?.kickPusherGiftedSubscription(event: event)
    }

    private func handleRewardRedeemedEvent(data: String) throws {
        let event = try decodeRewardRedeemedEvent(data: data)
        delegate?.kickPusherRewardRedeemed(event: event)
    }

    private func handleStreamHostEvent(data: String) throws {
        let event = try decodeStreamHostEvent(data: data)
        delegate?.kickPusherStreamHost(event: event)
    }

    private func handleKicksGiftedEvent(data: String) throws {
        let event = try decodeKicksGiftedEvent(data: data)
        delegate?.kickPusherKicksGifted(event: event)
    }

    private func makeChatPostSegments(content: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var id = 0
        for var segment in createKickSegments(message: content, id: &id) {
            if let text = segment.text {
                segments += emotes.createSegments(text: text, id: &id)
                segment.text = nil
            }
            if segment.text != nil || segment.url != nil {
                segments.append(segment)
            }
        }
        return segments
    }

    private func makeHighlight(message: ChatMessageEvent) -> ChatHighlight? {
        if message.type == "reply" {
            if let username = message.metadata?.original_sender?.username,
               let content = message.metadata?.original_message?.content
            {
                return ChatHighlight.makeReply(user: username, segments: makeChatPostSegments(content: content))
            }
        }
        return nil
    }

    private func sendMessage(message: String) {
        logger.debug("kick: pusher: \(channelId): Sending \(message)")
        webSocket.send(string: message)
    }

    private func createKickSegments(message: String, id: inout Int) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var startIndex = message.startIndex
        for match in message[startIndex...].matches(of: /\[emote:(\d+):[^\]]+\]/) {
            let emoteId = match.output.1
            let textBeforeEmote = message[startIndex ..< match.range.lowerBound]
            let url = URL(string: "https://files.kick.com/emotes/\(emoteId)/fullsize")
            segments += makeChatPostTextSegments(text: String(textBeforeEmote), id: &id)
            segments.append(ChatPostSegment(id: id, url: url))
            id += 1
            startIndex = match.range.upperBound
        }
        if startIndex != message.endIndex {
            segments += makeChatPostTextSegments(text: String(message[startIndex...]), id: &id)
        }
        return segments
    }

    func sendSubscribe(channel: String) {
        sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"\(channel)\"}}
            """
        )
    }
}

extension KickPusher: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.debug("kick: Connected")
        sendSubscribe(channel: "chatrooms.\(channelId).v2")
        sendSubscribe(channel: "chatroom_\(channelId)")
        sendSubscribe(channel: "chatrooms.\(channelId)")
        sendSubscribe(channel: "predictions-channel-\(channelId)")
        sendSubscribe(channel: "channel_\(chatroomChannelId)")
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("kick: Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        handleMessage(message: string)
    }
}
