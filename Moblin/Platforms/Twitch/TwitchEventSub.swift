import Foundation

private struct BasicMetadata: Decodable {
    var message_type: String
    var subscription_type: String?
}

private struct BasicMessage: Decodable {
    var metadata: BasicMetadata
}

private struct WelcomePayloadSession: Decodable {
    var id: String
}

private struct WelcomePayload: Decodable {
    var session: WelcomePayloadSession
}

private struct WelcomeMessage: Decodable {
    var payload: WelcomePayload
}

struct TwitchEventSubNotificationChannelSubscribeEvent: Decodable {
    var user_name: String
}

private struct NotificationChannelSubscribePayload: Decodable {
    var event: TwitchEventSubNotificationChannelSubscribeEvent
}

private struct NotificationChannelSubscribeMessage: Decodable {
    var payload: NotificationChannelSubscribePayload
}

struct TwitchEventSubNotificationChannelFollowEvent: Decodable {
    var user_name: String
}

private struct NotificationChannelFollowPayload: Decodable {
    var event: TwitchEventSubNotificationChannelFollowEvent
}

private struct NotificationChannelFollowMessage: Decodable {
    var payload: NotificationChannelFollowPayload
}

// periphery:ignore
struct TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEventReward: Decodable {
    var id: String
    var title: String
    var cost: Int
    var prompt: String
}

// periphery:ignore
struct TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent: Decodable {
    var id: String
    var user_id: String
    var user_login: String
    var user_name: String
    var broadcaster_user_id: String
    var broadcaster_user_login: String
    var broadcaster_user_name: String
    var status: String
    var reward: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEventReward
    var redeemed_at: String
}

private struct NotificationChannelPointsCustomRewardRedemptionAddPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
}

private struct NotificationChannelPointsCustomRewardRedemptionAddMessage: Decodable {
    // periphery:ignore
    var payload: NotificationChannelPointsCustomRewardRedemptionAddPayload
}

struct TwitchEventSubChannelRaidEvent: Decodable {
    var from_broadcaster_user_name: String
    var viewers: Int
}

private struct NotificationChannelRaidPayload: Decodable {
    var event: TwitchEventSubChannelRaidEvent
}

private struct NotificationChannelRaidMessage: Decodable {
    var payload: NotificationChannelRaidPayload
}

struct TwitchEventSubChannelCheerEvent: Decodable {
    var user_name: String?
    var message: String
    var bits: Int
}

private struct NotificationChannelCheerPayload: Decodable {
    var event: TwitchEventSubChannelCheerEvent
}

private struct NotificationChannelCheerMessage: Decodable {
    var payload: NotificationChannelCheerPayload
}

struct TwitchEventSubChannelHypeTrainBeginEvent: Decodable {
    var progress: Int
    var goal: Int
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var expires_at: String
}

private struct NotificationChannelHypeTrainBeginPayload: Decodable {
    var event: TwitchEventSubChannelHypeTrainBeginEvent
}

private struct NotificationChannelHypeTrainBeginMessage: Decodable {
    var payload: NotificationChannelHypeTrainBeginPayload
}

struct TwitchEventSubChannelHypeTrainProgressEvent: Decodable {
    var progress: Int
    var goal: Int
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var expires_at: String
}

private struct NotificationChannelHypeTrainProgressPayload: Decodable {
    var event: TwitchEventSubChannelHypeTrainProgressEvent
}

private struct NotificationChannelHypeTrainProgressMessage: Decodable {
    var payload: NotificationChannelHypeTrainProgressPayload
}

struct TwitchEventSubChannelHypeTrainEndEvent: Decodable {
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var ended_at: String
}

private struct NotificationChannelHypeTrainEndPayload: Decodable {
    var event: TwitchEventSubChannelHypeTrainEndEvent
}

private struct NotificationChannelHypeTrainEndMessage: Decodable {
    var payload: NotificationChannelHypeTrainEndPayload
}

private var url = URL(string: "wss://eventsub.wss.twitch.tv/ws")!

protocol TwitchEventSubDelegate: AnyObject {
    func twitchEventSubMakeErrorToast(title: String)
    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent)
    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent)
    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    )
    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent)
    func twitchEventSubChannelCheer(event: TwitchEventSubChannelCheerEvent)
    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent)
    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent)
    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent)
    func twitchEventSubUnauthorized()
    func twitchEventSubNotification(message: String)
}

final class TwitchEventSub: NSObject {
    private var webSocket: WebSocketClient
    private var remoteControl: Bool
    private let userId: String
    private var sessionId: String = ""
    private var twitchApi: TwitchApi
    private let delegate: any TwitchEventSubDelegate
    private var connected = false

    init(remoteControl: Bool, userId: String, accessToken: String, delegate: TwitchEventSubDelegate) {
        self.remoteControl = remoteControl
        self.userId = userId
        self.delegate = delegate
        twitchApi = TwitchApi(accessToken: accessToken)
        webSocket = .init(url: url)
        super.init()
        twitchApi.delegate = self
    }

    func start() {
        logger.info("twitch: event-sub: Start")
        stopInternal()
        connect()
    }

    private func connect() {
        connected = false
        webSocket = .init(url: url)
        webSocket.delegate = self
        if !remoteControl {
            webSocket.start()
        }
    }

    func stop() {
        logger.info("twitch: event-sub: Stop")
        stopInternal()
    }

    func stopInternal() {
        connected = false
        webSocket.stop()
    }

    func isRemoteControl() -> Bool {
        return remoteControl
    }

    func isConnected() -> Bool {
        return connected
    }

    private func handleMessage(messageText: String) {
        let messageData = messageText.utf8Data
        guard let message = try? JSONDecoder().decode(BasicMessage.self, from: messageData) else {
            return
        }
        switch message.metadata.message_type {
        case "session_welcome":
            handleSessionWelcome(messageData: messageData)
        case "session_keepalive":
            break
        case "notification":
            handleNotification(message: message, messageText: messageText, messageData: messageData)
        default:
            logger.info("twitch: event-sub: Unknown message type \(message.metadata.message_type)")
        }
    }

    private func handleSessionWelcome(messageData: Data) {
        guard let message = try? JSONDecoder().decode(WelcomeMessage.self, from: messageData) else {
            logger.info("twitch: event-sub: Failed to decode welcome message")
            return
        }
        sessionId = message.payload.session.id
        subscribeToChannelFollow()
    }

    private func makeSubscribeErrorToastIfNotOk(ok: Bool, eventType: String) {
        guard !ok else {
            return
        }
        delegate
            .twitchEventSubMakeErrorToast(
                title: String(localized: "Failed to subscribe to Twitch \(eventType) event")
            )
    }

    private func subscribeToChannelFollow() {
        let body = createBody(
            type: "channel.follow",
            version: 2,
            condition: "{\"broadcaster_user_id\":\"\(userId)\",\"moderator_user_id\":\"\(userId)\"}"
        )
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "follow")
            self.subscribeToChannelSubscribe()
        }
    }

    private func subscribeToChannelSubscribe() {
        let body = createBody(type: "channel.subscribe",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "subscription")
            self.subscribeToChannelPointsCustomRewardRedemptionAdd()
        }
    }

    private func subscribeToChannelPointsCustomRewardRedemptionAdd() {
        let body = createBody(type: "channel.channel_points_custom_reward_redemption.add",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "reward redemption")
            self.subscribeToChannelRaid()
        }
    }

    private func subscribeToChannelRaid() {
        let body = createBody(type: "channel.raid",
                              version: 1,
                              condition: "{\"to_broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "raid")
            self.subscribeToChannelCheer()
        }
    }

    private func subscribeToChannelCheer() {
        let body = createBody(type: "channel.cheer",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "cheer")
            self.subscribeToChannelHypeTrainBegin()
        }
    }

    private func subscribeToChannelHypeTrainBegin() {
        let body = createBody(type: "channel.hype_train.begin",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "hype train begin")
            self.subscribeToChannelHypeTrainProgress()
        }
    }

    private func subscribeToChannelHypeTrainProgress() {
        let body = createBody(type: "channel.hype_train.progress",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "hype train progress")
            self.subscribeToChannelHypeTrainEnd()
        }
    }

    private func subscribeToChannelHypeTrainEnd() {
        let body = createBody(type: "channel.hype_train.end",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            self.makeSubscribeErrorToastIfNotOk(ok: ok, eventType: "hype train end")
            self.connected = true
        }
    }

    private func createBody(type: String, version: Int, condition: String) -> String {
        return """
        {
            "type": "\(type)",
            "version": "\(version)",
            "condition": \(condition),
            "transport": {
                "method": "websocket",
                "session_id": "\(sessionId)"
            }
        }
        """
    }

    private func handleNotification(message: BasicMessage, messageText: String, messageData: Data) {
        do {
            switch message.metadata.subscription_type {
            case "channel.follow":
                try handleNotificationChannelFollow(messageData: messageData)
            case "channel.subscribe":
                try handleNotificationChannelSubscribe(messageData: messageData)
            case "channel.channel_points_custom_reward_redemption.add":
                try handleChannelPointsCustomRewardRedemptionAdd(messageData: messageData)
            case "channel.raid":
                try handleChannelRaid(messageData: messageData)
            case "channel.cheer":
                try handleChannelCheer(messageData: messageData)
            case "channel.hype_train.begin":
                try handleChannelHypeTrainBegin(messageData: messageData)
            case "channel.hype_train.progress":
                try handleChannelHypeTrainProgress(messageData: messageData)
            case "channel.hype_train.end":
                try handleChannelHypeTrainEnd(messageData: messageData)
            default:
                if let type = message.metadata.subscription_type {
                    logger.info("twitch: event-sub: Unknown notification type \(type)")
                } else {
                    logger.info("twitch: event-sub: Missing notification type")
                }
            }
            delegate.twitchEventSubNotification(message: messageText)
        } catch {
            let subscription_type = message.metadata.subscription_type ?? "unknown"
            logger.info("twitch: event-sub: Failed to handle notification \(subscription_type).")
        }
    }

    private func handleNotificationChannelFollow(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelFollowMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelFollow(event: message.payload.event)
    }

    private func handleNotificationChannelSubscribe(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelSubscribeMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelSubscribe(event: message.payload.event)
    }

    private func handleChannelPointsCustomRewardRedemptionAdd(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelPointsCustomRewardRedemptionAddMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelPointsCustomRewardRedemptionAdd(event: message.payload.event)
    }

    private func handleChannelRaid(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelRaidMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelRaid(event: message.payload.event)
    }

    private func handleChannelCheer(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelCheerMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelCheer(event: message.payload.event)
    }

    private func handleChannelHypeTrainBegin(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelHypeTrainBeginMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelHypeTrainBegin(event: message.payload.event)
    }

    private func handleChannelHypeTrainProgress(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelHypeTrainProgressMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelHypeTrainProgress(event: message.payload.event)
    }

    private func handleChannelHypeTrainEnd(messageData: Data) throws {
        let message = try JSONDecoder().decode(
            NotificationChannelHypeTrainEndMessage.self,
            from: messageData
        )
        delegate.twitchEventSubChannelHypeTrainEnd(event: message.payload.event)
    }
}

extension TwitchEventSub: WebSocketClientDelegate {
    func webSocketClientConnected() {}

    func webSocketClientDisconnected() {
        connected = false
    }

    func webSocketClientReceiveMessage(string: String) {
        handleMessage(messageText: string)
    }
}

extension TwitchEventSub: TwitchApiDelegate {
    func twitchApiUnauthorized() {
        delegate.twitchEventSubUnauthorized()
    }
}
