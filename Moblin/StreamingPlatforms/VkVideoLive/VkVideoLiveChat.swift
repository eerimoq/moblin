import Foundation

// Chat events are delivered over WebSocket using Centrifugo (V4, client protocol v2).
// See https://dev.live.vkvideo.ru/docs/pubsub/websocket and https://centrifugal.dev/.
private let pubSubUrl =
    URL(string: "wss://pubsub-dev.live.vkvideo.ru/connection/websocket?format=json&cf_protocol_version=v2")!
private let connectCommandId = 1
private let subscribeCommandId = 2
private let subscribeInfoCommandId = 3
private let subscribeChannelPointsCommandId = 4
private let subscribePrivateBaseCommandId = 10

// The platform's internal chat bot posts reward redemptions (and other system
// messages) into the chat. Identified by this badge achievement name.
private let internalChatBotAchievementName = "internal_chatbot"
private let rewardRedemptionTextPrefix = "получает награду"

private struct CentrifugoConnect: Encodable {
    let token: String
}

private struct CentrifugoSubscribe: Encodable {
    let channel: String
    var token: String?
}

private struct CentrifugoCommand: Encodable {
    let id: Int
    var connect: CentrifugoConnect?
    var subscribe: CentrifugoSubscribe?
}

private struct CentrifugoError: Decodable {
    let code: Int?
    let message: String?
}

private struct CentrifugoPublication: Decodable {
    let data: VkVideoLiveEvent?
}

private struct CentrifugoPush: Decodable {
    let channel: String?
    let pub: CentrifugoPublication?
}

private struct CentrifugoReply: Decodable {
    let id: Int?
    let error: CentrifugoError?
    let push: CentrifugoPush?
}

// Nick colors as rendered by the platform's web player, indexed by the
// documented nick_color number.
private let nickColors = [
    "#D66E34", "#B8AAFF", "#1D90FF", "#9961F9",
    "#59A840", "#E73629", "#DE6489", "#20BBA1",
    "#F8B301", "#0099BB", "#7BBEFF", "#E542FF",
    "#A36C59", "#8BA259", "#00A9FF", "#A20BFF",
].map { RgbColor.fromHex(string: $0) }

private func lookupNickColor(number: Int?) -> RgbColor? {
    guard let number, nickColors.indices.contains(number) else {
        return nil
    }
    return nickColors[number]
}

// Events have a type and a payload whose structure depends on the type.
// See https://dev.live.vkvideo.ru/docs/pubsub/websocket.
private let chatMessageSendEventType = "channel_chat_message_send"
private let chatMessageDeleteEventType = "channel_chat_message_delete"
private let followCreateEventType = "channel_follow_create"
private let raidIncomeEventType = "channel_raid_income"

private struct VkVideoLiveEvent: Decodable {
    let type: String?
    let data: JsonValue?
}

private struct VkVideoLiveChatMessageEventData: Decodable {
    let chat_message: VkVideoLiveChatMessage
}

private struct VkVideoLiveDeletedChatMessage: Decodable {
    let id: Int64
}

private struct VkVideoLiveChatMessageDeleteEventData: Decodable {
    let chat_message: VkVideoLiveDeletedChatMessage
}

private struct VkVideoLiveFollower: Decodable {
    let id: Int64?
    let nick: String
    let nick_color: Int?
}

private struct VkVideoLiveFollow: Decodable {
    let follower: VkVideoLiveFollower
}

private struct VkVideoLiveFollowEventData: Decodable {
    let follow: VkVideoLiveFollow
}

private struct VkVideoLiveRaidOwner: Decodable {
    let id: Int64?
    let nick: String
    let nick_color: Int?
}

private struct VkVideoLiveRaidSource: Decodable {
    let owner: VkVideoLiveRaidOwner
}

private struct VkVideoLiveRaid: Decodable {
    let source: VkVideoLiveRaidSource
    let raiders_count: Int?
}

private struct VkVideoLiveRaidEventData: Decodable {
    let raid: VkVideoLiveRaid
}

// Generic JSON value so event payloads can be re-decoded based on event type.
private enum JsonValue: Decodable {
    case object([String: JsonValue])
    case array([JsonValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JsonValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JsonValue].self) {
            self = .object(value)
        } else {
            throw "Unsupported JSON value"
        }
    }

    private func toFoundation() -> Any {
        switch self {
        case let .object(value):
            value.mapValues { $0.toFoundation() }
        case let .array(value):
            value.map { $0.toFoundation() }
        case let .string(value):
            value
        case let .integer(value):
            value
        case let .number(value):
            value
        case let .bool(value):
            value
        case .null:
            NSNull()
        }
    }

    func toData() -> Data? {
        try? JSONSerialization.data(withJSONObject: toFoundation())
    }
}

protocol VkVideoLiveChatDelegate: AnyObject {
    func vkVideoLiveChatAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isModerator: Bool,
        isOwner: Bool
    )
    func vkVideoLiveChatDeleteMessage(messageId: String)
    func vkVideoLiveChatFollow(user: String, userColor: RgbColor?)
    func vkVideoLiveChatRaid(user: String, userColor: RgbColor?, raidersCount: Int)
    func vkVideoLiveChatRewardRedemption(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        segments: [ChatPostSegment]
    )
}

final class VkVideoLiveChat: NSObject {
    private let channelUrl: String
    private let api: VkVideoLiveApi
    private var webSocket: WebSocketClient
    private weak var delegate: (any VkVideoLiveChatDelegate)?
    private var connectionToken: String?
    private var chatChannelName: String?
    private var infoChannelName: String?
    private var channelPointsChannelName: String?
    private var privateChannels: [(name: String, token: String)] = []
    private var streamId: String?
    private var subscribed = false
    private var started = false
    private let restartTimer = SimpleTimer(queue: .main)

    init(delegate: any VkVideoLiveChatDelegate, channelUrl: String, accessToken: String) {
        self.delegate = delegate
        self.channelUrl = channelUrl
        api = VkVideoLiveApi(accessToken: accessToken)
        webSocket = .init(url: pubSubUrl)
    }

    func start() {
        logger.debug("vk-video-live: Start")
        stopInternal()
        started = true
        fetchTokenAndConnect()
    }

    func stop() {
        logger.debug("vk-video-live: Stop")
        stopInternal()
    }

    private func stopInternal() {
        started = false
        subscribed = false
        restartTimer.stop()
        webSocket.stop()
    }

    func isConnected() -> Bool {
        webSocket.isConnected() && subscribed
    }

    func hasEmotes() -> Bool {
        false
    }

    func getStreamId() -> String? {
        streamId
    }

    private func fetchTokenAndConnect() {
        api.getWebSocketToken { [weak self] token in
            guard let self, started else {
                return
            }
            guard let token else {
                startRestartTimer()
                return
            }
            connectionToken = token
            api.getChannel(channelUrl: channelUrl) { [weak self] data in
                guard let self, started else {
                    return
                }
                guard let chatChannelName = data?.channel?.web_socket_channels?.chat else {
                    startRestartTimer()
                    return
                }
                self.chatChannelName = chatChannelName
                infoChannelName = data?.channel?.web_socket_channels?.info
                channelPointsChannelName = data?.channel?.web_socket_channels?.channel_points
                streamId = data?.stream?.id
                fetchPrivateChannelTokensAndConnect(
                    webSocketChannels: data?.channel?.web_socket_channels
                )
            }
        }
    }

    private func fetchPrivateChannelTokensAndConnect(
        webSocketChannels: VkVideoLiveWebSocketChannels?
    ) {
        privateChannels = []
        let channelNames = [
            webSocketChannels?.limited_chat,
            webSocketChannels?.private_chat,
            webSocketChannels?.limited_private_chat,
            webSocketChannels?.private_info,
            webSocketChannels?.private_channel_points,
        ].compactMap { $0 }
        guard !channelNames.isEmpty else {
            connect()
            return
        }
        api.getWebSocketSubscriptionTokens(channels: channelNames) { [weak self] tokens in
            guard let self, started else {
                return
            }
            for token in tokens ?? [] {
                if let name = token.channel, let token = token.token {
                    privateChannels.append((name, token))
                }
            }
            connect()
        }
    }

    private func connect() {
        webSocket = .init(url: pubSubUrl)
        webSocket.delegate = self
        webSocket.start()
    }

    private func startRestartTimer() {
        restartTimer.startSingleShot(timeout: 30) { [weak self] in
            guard let self, started else {
                return
            }
            fetchTokenAndConnect()
        }
    }

    private func send(command: CentrifugoCommand) {
        guard let data = try? JSONEncoder().encode(command),
              let message = String(bytes: data, encoding: .utf8)
        else {
            return
        }
        webSocket.send(string: message)
    }

    private func handleMessage(message: String) {
        for line in message.split(separator: "\n") {
            do {
                try handleReply(reply: String(line))
            } catch {
                logger.info("vk-video-live: Failed to process reply \"\(line)\" with error \(error)")
            }
        }
    }

    private func handleReply(reply: String) throws {
        // The server periodically sends empty commands and expects empty replies to them.
        if reply == "{}" {
            webSocket.send(string: "{}")
            return
        }
        let decoded = try JSONDecoder().decode(CentrifugoReply.self, from: reply.utf8Data)
        if let error = decoded.error {
            logger.info("""
            vk-video-live: Command \(decoded.id ?? -1) failed with code \(error.code ?? -1) \
            and message \(error.message ?? "-")
            """)
            switch decoded.id {
            case connectCommandId:
                // The connection token has likely expired. Fetch a new one and reconnect.
                webSocket.stop()
                startRestartTimer()
            case subscribeCommandId:
                // The chat channel name may be outdated. Fetch channel info again and reconnect.
                webSocket.stop()
                startRestartTimer()
            default:
                break
            }
            return
        }
        switch decoded.id {
        case connectCommandId:
            handleConnected()
        case subscribeCommandId:
            handleSubscribed()
        case subscribeInfoCommandId:
            logger.debug("vk-video-live: Subscribed to info channel")
        case subscribeChannelPointsCommandId:
            logger.debug("vk-video-live: Subscribed to channel points channel")
        case let id? where id >= subscribePrivateBaseCommandId:
            logger.debug("vk-video-live: Subscribed to private channel")
        default:
            if let push = decoded.push, let event = push.pub?.data {
                if isPrivateChannel(name: push.channel) {
                    // Only inspected for now. Events also show up in the debug log.
                    logger.debug("""
                    vk-video-live: Got event of type \(event.type ?? "-") on private channel \
                    \(push.channel ?? "-")
                    """)
                } else {
                    handleEvent(event: event)
                }
            }
        }
    }

    private func isPrivateChannel(name: String?) -> Bool {
        privateChannels.contains(where: { $0.name == name })
    }

    private func handleConnected() {
        guard let chatChannelName else {
            return
        }
        send(command: CentrifugoCommand(id: subscribeCommandId,
                                        subscribe: CentrifugoSubscribe(channel: chatChannelName)))
        if let infoChannelName {
            send(command: CentrifugoCommand(id: subscribeInfoCommandId,
                                            subscribe: CentrifugoSubscribe(channel: infoChannelName)))
        }
        if let channelPointsChannelName {
            send(command: CentrifugoCommand(
                id: subscribeChannelPointsCommandId,
                subscribe: CentrifugoSubscribe(channel: channelPointsChannelName)
            ))
        }
        for (index, channel) in privateChannels.enumerated() {
            send(command: CentrifugoCommand(
                id: subscribePrivateBaseCommandId + index,
                subscribe: CentrifugoSubscribe(channel: channel.name, token: channel.token)
            ))
        }
    }

    private func handleSubscribed() {
        logger.debug("vk-video-live: Subscribed to chat channel")
        subscribed = true
    }

    private func handleEvent(event: VkVideoLiveEvent) {
        guard let data = event.data?.toData() else {
            return
        }
        switch event.type {
        case chatMessageSendEventType:
            do {
                let event = try JSONDecoder().decode(VkVideoLiveChatMessageEventData.self, from: data)
                handleChatMessage(message: event.chat_message)
            } catch {
                logger.info("vk-video-live: Failed to decode chat message with error \(error)")
            }
        case chatMessageDeleteEventType:
            do {
                let event = try JSONDecoder().decode(VkVideoLiveChatMessageDeleteEventData.self,
                                                     from: data)
                delegate?.vkVideoLiveChatDeleteMessage(messageId: String(event.chat_message.id))
            } catch {
                logger.info("vk-video-live: Failed to decode deleted chat message with error \(error)")
            }
        case followCreateEventType:
            do {
                let event = try JSONDecoder().decode(VkVideoLiveFollowEventData.self, from: data)
                delegate?.vkVideoLiveChatFollow(
                    user: event.follow.follower.nick,
                    userColor: lookupNickColor(number: event.follow.follower.nick_color)
                )
            } catch {
                logger.info("vk-video-live: Failed to decode follow with error \(error)")
            }
        case raidIncomeEventType:
            do {
                let event = try JSONDecoder().decode(VkVideoLiveRaidEventData.self, from: data)
                delegate?.vkVideoLiveChatRaid(
                    user: event.raid.source.owner.nick,
                    userColor: lookupNickColor(number: event.raid.source.owner.nick_color),
                    raidersCount: event.raid.raiders_count ?? 0
                )
            } catch {
                logger.info("vk-video-live: Failed to decode raid with error \(error)")
            }
        default:
            logger.debug("""
            vk-video-live: Unsupported event of type \(event.type ?? "-") with data \
            \(String(bytes: data, encoding: .utf8) ?? "-")
            """)
        }
    }

    private func handleChatMessage(message: VkVideoLiveChatMessage) {
        if handleRewardRedemptionMessage(message: message) {
            return
        }
        let segments = makeSegments(parts: message.parts)
        guard !segments.isEmpty else {
            return
        }
        delegate?.vkVideoLiveChatAppendMessage(
            messageId: message.id != nil ? String(message.id!) : nil,
            user: message.author.nick,
            userId: String(message.author.id),
            userColor: makeNickColor(author: message.author),
            userBadges: makeBadgeUrls(author: message.author),
            segments: segments,
            isModerator: message.author.is_moderator == true,
            isOwner: message.author.is_owner == true
        )
    }

    // Reward redemptions are posted into the chat by the platform's internal
    // chat bot as a mention of the redeeming user followed by text.
    private func handleRewardRedemptionMessage(message: VkVideoLiveChatMessage) -> Bool {
        guard message.author.badges?
            .contains(where: { $0.achievement_name == internalChatBotAchievementName }) == true
        else {
            return false
        }
        guard let mention = message.parts.first?.mention, let nick = mention.nick else {
            return false
        }
        guard let text = message.parts.compactMap({ $0.text?.content }).first,
              text.hasPrefix(rewardRedemptionTextPrefix)
        else {
            return false
        }
        let segments = makeSegments(parts: Array(message.parts.dropFirst()))
        guard !segments.isEmpty else {
            return false
        }
        let messageId = message.id != nil ? String(message.id!) : nil
        let userId = mention.id != nil ? String(mention.id!) : nil
        // The mention does not contain the user's nick color, so look it up.
        fetchNickColor(userId: userId) { [weak self] userColor in
            self?.delegate?.vkVideoLiveChatRewardRedemption(
                messageId: messageId,
                user: nick,
                userId: userId,
                userColor: userColor,
                segments: segments
            )
        }
        return true
    }

    private func fetchNickColor(userId: String?, onComplete: @escaping (RgbColor?) -> Void) {
        guard let userId else {
            onComplete(nil)
            return
        }
        api.getChatMember(channelUrl: channelUrl, userId: userId) { member in
            onComplete(lookupNickColor(number: member?.user?.nick_color))
        }
    }

    private func makeNickColor(author: VkVideoLiveMessageAuthor) -> RgbColor? {
        lookupNickColor(number: author.nick_color)
    }

    private func makeBadgeUrls(author: VkVideoLiveMessageAuthor) -> [URL] {
        var badgeUrls: [URL] = []
        for role in author.roles ?? [] {
            if let url = URL(string: role.medium_url ?? role.small_url ?? "") {
                badgeUrls.append(url)
            }
        }
        for badge in author.badges ?? [] {
            if let url = URL(string: badge.medium_url ?? badge.small_url ?? "") {
                badgeUrls.append(url)
            }
        }
        return badgeUrls
    }

    private func makeSegments(parts: [VkVideoLiveMessagePart]) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var id = 0
        for part in parts {
            if let content = part.text?.content {
                segments += makeChatPostTextSegments(text: content, id: &id)
            }
            if let smile = part.smile {
                if let url = URL(string: smile.medium_url ?? smile.small_url ?? "") {
                    segments.append(ChatPostSegment(id: id, url: url))
                    id += 1
                } else if let name = smile.name {
                    segments += makeChatPostTextSegments(text: name, id: &id)
                }
            }
            if let mention = part.mention, let nick = mention.nick {
                segments += makeChatPostTextSegments(text: "@\(nick)", id: &id)
            }
            if let link = part.link, let text = link.content ?? link.url {
                segments += makeChatPostTextSegments(text: text, id: &id)
            }
        }
        return segments
    }
}

extension VkVideoLiveChat: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.debug("vk-video-live: Connected")
        guard let connectionToken else {
            return
        }
        subscribed = false
        send(command: CentrifugoCommand(id: connectCommandId,
                                        connect: CentrifugoConnect(token: connectionToken)))
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("vk-video-live: Disconnected")
        subscribed = false
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        logger.debug("vk-video-live: Received \(string)")
        handleMessage(message: string)
    }
}
