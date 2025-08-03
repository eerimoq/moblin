import Foundation

private struct Badge: Decodable {
    var type: String
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
        return sender.identity.badges.contains(where: { $0.type == "moderator" })
    }

    func isSubscriber() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == "subscriber" })
    }
}

private struct Message: Decodable {
    var id: String
}

private struct MessageDeletedEvent: Decodable {
    var message: Message
}

private struct User: Decodable {
    var id: Int
}

private struct UserBannedEvent: Decodable {
    var user: User
}

struct SubscriptionEvent: Decodable {
    var chatroom_id: Int
    var username: String
    var months: Int
}

struct GiftedSubscriptionsEvent: Decodable {
    var chatroom_id: Int
    var gifted_usernames: [String]
    var gifter_username: String
    var gifter_total: Int
}

private struct RewardRedeemedEvent: Decodable {
    // {"reward_title":"test",
    // "user_id":2478206,
    // "channel_id":2423391,
    // "username":"iChrisIRL",
    // "user_input":"123",
    // "reward_background_color":"#FFD899"}
    var reward_title: String
    var user_id: Int
    var channel_id: Int
    var username: String
    var user_input: String
    // var reward_background_color: String
}

private struct StreamHostEvent: Decodable {
    // {"host_username": "channel",
    // "number_viewers": 674}
    var host_username: String
    var number_viewers: Int
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
    return try JSONDecoder().decode(
        ChatMessageEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeMessageDeletedEvent(data: String) throws -> MessageDeletedEvent {
    return try JSONDecoder().decode(
        MessageDeletedEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeUserBannedEvent(data: String) throws -> UserBannedEvent {
    return try JSONDecoder().decode(
        UserBannedEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeSubscriptionEvent(data: String) throws -> SubscriptionEvent {
    return try JSONDecoder().decode(
        SubscriptionEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeGiftedSubscriptionsEvent(data: String) throws -> GiftedSubscriptionsEvent {
    return try JSONDecoder().decode(
        GiftedSubscriptionsEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeRewardRedeemedEvent(data: String) throws -> RewardRedeemedEvent {
    return try JSONDecoder().decode(
        RewardRedeemedEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private func decodeStreamHostEvent(data: String) throws -> StreamHostEvent {
    return try JSONDecoder().decode(
        StreamHostEvent.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private var url =
    URL(
        string: "wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=7.6.0&flash=false"
    )!

protocol KickOusherDelegate: AnyObject {
    func kickPusherMakeErrorToast(title: String, subTitle: String?)
    func kickPusherAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool,
        highlight: ChatHighlight?
    )
    func kickPusherDeleteMessage(messageId: String)
    func kickPusherDeleteUser(userId: String)
    func kickPusherSubscription(event: SubscriptionEvent)
    func kickPusherGiftedSubscription(event: GiftedSubscriptionsEvent)
}

final class KickPusher: NSObject {
    private var channelName: String
    private var channelId: String
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private let settings: SettingsStreamChat
    private var gotInfo = false
    private weak var delegate: (any KickOusherDelegate)?

    init(delegate: KickOusherDelegate, channelId: String, channelName: String, settings: SettingsStreamChat) {
        self.delegate = delegate
        self.channelId = channelId
        self.channelName = channelName
        self.settings = settings.clone()
        emotes = Emotes()
        webSocket = .init(url: url)
    }

    func start() {
        logger.debug("kick: Start")
        stopInternal()
        if channelName.isEmpty {
            connect()
        } else {
            getInfoAndConnect()
        }
    }

    private func getInfoAndConnect() {
        logger.debug("kick: Get info and connect")
        getKickChannelInfo(channelName: channelName) { [weak self] channelInfo in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.gotInfo else {
                    return
                }
                guard let channelInfo else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.getInfoAndConnect()
                    }
                    return
                }
                self.gotInfo = true
                self.channelId = String(channelInfo.chatroom.id)
                self.connect()
            }
        }
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
            // kickSub kickGift kickGifts kickIncomingRaid kickRewardRedeemed kickBan kickTO ???
            // we can get without auth
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
        delegate?.kickPusherAppendMessage(
            messageId: event.id,
            user: event.sender.username,
            userId: event.sender.id != nil ? String(event.sender.id!) : nil,
            userColor: RgbColor.fromHex(string: event.sender.identity.color),
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
    }

    private func handleSubscriptionEvent(data: String) throws {
        let event = try decodeSubscriptionEvent(data: data)
        delegate?.kickPusherSubscription(event: event)
    }

    private func handleGiftedSubscriptionsEvent(data: String) throws {
        let event = try decodeGiftedSubscriptionsEvent(data: data)
        delegate?.kickPusherGiftedSubscription(event: event)
    }

    private func handleRewardRedeemedEvent(data _: String) throws {
        // let event = try decodeRewardRedeemedEvent(data: data)
        // delegate?.kickPusherDeleteUser(userId: String(event.user.id))
    }

    private func handleStreamHostEvent(data _: String) throws {
        // let event = try decodeStreamHostEvent(data: data)
        // delegate?.kickPusherDeleteUser(userId: String(event.user.id))
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
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("kick: Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        handleMessage(message: string)
    }
}
