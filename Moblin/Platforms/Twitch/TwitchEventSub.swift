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
    // periphery:ignore
    var keepalive_timeout_seconds: Int
}

private struct WelcomePayload: Decodable {
    var session: WelcomePayloadSession
}

private struct WelcomeMessage: Decodable {
    // periphery:ignore
    var metadata: BasicMetadata
    var payload: WelcomePayload
}

struct TwitchEventSubNotificationChannelSubscribeEvent: Decodable {
    // periphery:ignore
    var user_id: String
    // periphery:ignore
    var user_login: String
    var user_name: String
    // periphery:ignore
    var broadcaster_user_id: String
    // periphery:ignore
    var broadcaster_user_login: String
    // periphery:ignore
    var broadcaster_user_name: String
    // periphery:ignore
    var tier: String
    // periphery:ignore
    var is_gift: Bool
}

private struct NotificationChannelSubscribePayload: Decodable {
    var event: TwitchEventSubNotificationChannelSubscribeEvent
}

private struct NotificationChannelSubscribeMessage: Decodable {
    var payload: NotificationChannelSubscribePayload
}

struct TwitchEventSubNotificationChannelFollowEvent: Decodable {
    // periphery:ignore
    var user_id: String
    // periphery:ignore
    var user_login: String
    var user_name: String
    // periphery:ignore
    var broadcaster_user_id: String
    // periphery:ignore
    var broadcaster_user_login: String
    // periphery:ignore
    var broadcaster_user_name: String
    // periphery:ignore
    var followed_at: String
}

private struct NotificationChannelFollowPayload: Decodable {
    var event: TwitchEventSubNotificationChannelFollowEvent
}

private struct NotificationChannelFollowMessage: Decodable {
    var payload: NotificationChannelFollowPayload
}

struct TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEventReward: Decodable {
    // periphery:ignore
    var id: String
    // periphery:ignore
    var title: String
    // periphery:ignore
    var cost: Int
    // periphery:ignore
    var prompt: String
}

struct TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent: Decodable {
    // periphery:ignore
    var id: String
    // periphery:ignore
    var user_id: String
    // periphery:ignore
    var user_login: String
    // periphery:ignore
    var user_name: String
    // periphery:ignore
    var broadcaster_user_id: String
    // periphery:ignore
    var broadcaster_user_login: String
    // periphery:ignore
    var broadcaster_user_name: String
    // periphery:ignore
    var status: String
    // periphery:ignore
    var reward: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEventReward
    // periphery:ignore
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
    // periphery:ignore
    var from_broadcaster_user_name: String
    // periphery:ignore
    var viewers: Int
}

private struct NotificationChannelRaidPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubChannelRaidEvent
}

private struct NotificationChannelRaidMessage: Decodable {
    // periphery:ignore
    var payload: NotificationChannelRaidPayload
}

struct TwitchEventSubChannelCheerEvent: Decodable {
    // periphery:ignore
    var user_name: String?
    // periphery:ignore
    var message: String
    // periphery:ignore
    var bits: Int
}

private struct NotificationChannelCheerPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubChannelCheerEvent
}

private struct NotificationChannelCheerMessage: Decodable {
    // periphery:ignore
    var payload: NotificationChannelCheerPayload
}

struct TwitchEventSubChannelHypeTrainBeginEvent: Decodable {
    // periphery:ignore
    var total: Int
    // periphery:ignore
    var progress: Int
    // periphery:ignore
    var goal: Int
    // periphery:ignore
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var expires_at: String
}

private struct NotificationChannelHypeTrainBeginPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubChannelHypeTrainBeginEvent
}

private struct NotificationChannelHypeTrainBeginMessage: Decodable {
    // periphery:ignore
    var payload: NotificationChannelHypeTrainBeginPayload
}

struct TwitchEventSubChannelHypeTrainProgressEvent: Decodable {
    // periphery:ignore
    var total: Int
    // periphery:ignore
    var progress: Int
    // periphery:ignore
    var goal: Int
    // periphery:ignore
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var expires_at: String
}

private struct NotificationChannelHypeTrainProgressPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubChannelHypeTrainProgressEvent
}

private struct NotificationChannelHypeTrainProgressMessage: Decodable {
    // periphery:ignore
    var payload: NotificationChannelHypeTrainProgressPayload
}

struct TwitchEventSubChannelHypeTrainEndEvent: Decodable {
    // periphery:ignore
    var total: Int
    // periphery:ignore
    var level: Int
    // periphery:ignore
    var started_at: String
    // periphery:ignore
    var ended_at: String
}

private struct NotificationChannelHypeTrainEndPayload: Decodable {
    // periphery:ignore
    var event: TwitchEventSubChannelHypeTrainEndEvent
}

private struct NotificationChannelHypeTrainEndMessage: Decodable {
    // periphery:ignore
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

    private func subscribeToChannelFollow() {
        let body = createBody(
            type: "channel.follow",
            version: 2,
            condition: "{\"broadcaster_user_id\":\"\(userId)\",\"moderator_user_id\":\"\(userId)\"}"
        )
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch follow events")
                    )
            }
            self.subscribeToChannelSubscribe()
        }
    }

    private func subscribeToChannelSubscribe() {
        let body = createBody(type: "channel.subscribe",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch subscription events")
                    )
            }
            self.subscribeToChannelPointsCustomRewardRedemptionAdd()
        }
    }

    private func subscribeToChannelPointsCustomRewardRedemptionAdd() {
        let body = createBody(type: "channel.channel_points_custom_reward_redemption.add",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch reward redemption events")
                    )
            }
            self.subscribeToChannelRaid()
        }
    }

    private func subscribeToChannelRaid() {
        let body = createBody(type: "channel.raid",
                              version: 1,
                              condition: "{\"to_broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch raid events")
                    )
            }
            self.subscribeToChannelCheer()
        }
    }

    private func subscribeToChannelCheer() {
        let body = createBody(type: "channel.cheer",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch cheer events")
                    )
            }
            self.subscribeToChannelHypeTrainBegin()
        }
    }

    private func subscribeToChannelHypeTrainBegin() {
        let body = createBody(type: "channel.hype_train.begin",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch hype train begin events")
                    )
            }
            self.subscribeToChannelHypeTrainProgress()
        }
    }

    private func subscribeToChannelHypeTrainProgress() {
        let body = createBody(type: "channel.hype_train.progress",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch hype train progress events")
                    )
            }
            self.subscribeToChannelHypeTrainEnd()
        }
    }

    private func subscribeToChannelHypeTrainEnd() {
        let body = createBody(type: "channel.hype_train.end",
                              version: 1,
                              condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
        twitchApi.createEventSubSubscription(body: body) { ok in
            if !ok {
                self.delegate
                    .twitchEventSubMakeErrorToast(
                        title: String(localized: "Failed to subscribe to Twitch hype train end events")
                    )
            }
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
        switch message.metadata.subscription_type {
        case "channel.follow":
            handleNotificationChannelFollow(messageData: messageData)
        case "channel.subscribe":
            handleNotificationChannelSubscribe(messageData: messageData)
        case "channel.channel_points_custom_reward_redemption.add":
            handleChannelPointsCustomRewardRedemptionAdd(messageData: messageData)
        case "channel.raid":
            handleChannelRaid(messageData: messageData)
        case "channel.cheer":
            handleChannelCheer(messageData: messageData)
        case "channel.hype_train.begin":
            handleChannelHypeTrainBegin(messageData: messageData)
        case "channel.hype_train.progress":
            handleChannelHypeTrainProgress(messageData: messageData)
        case "channel.hype_train.end":
            handleChannelHypeTrainEnd(messageData: messageData)
        default:
            if let type = message.metadata.subscription_type {
                logger.info("twitch: event-sub: Unknown notification type \(type)")
            } else {
                logger.info("twitch: event-sub: Missing notification type")
            }
        }
        delegate.twitchEventSubNotification(message: messageText)
    }

    private func handleNotificationChannelFollow(messageData: Data) {
        guard let message = try? JSONDecoder().decode(NotificationChannelFollowMessage.self,
                                                      from: messageData)
        else {
            logger.info("twitch: event-sub: Failed to decode channel.follow.")
            return
        }
        delegate.twitchEventSubChannelFollow(event: message.payload.event)
    }

    private func handleNotificationChannelSubscribe(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelSubscribeMessage.self,
            from: messageData
        ) else {
            logger.info("twitch: event-sub: Failed to decode channel.subscribe.")
            return
        }
        delegate.twitchEventSubChannelSubscribe(event: message.payload.event)
    }

    private func handleChannelPointsCustomRewardRedemptionAdd(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelPointsCustomRewardRedemptionAddMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("""
            twitch: event-sub: Failed to decode channel.channel_points_custom_reward_redemption.add \
            (\(data ?? "")).
            """)
            return
        }
        delegate.twitchEventSubChannelPointsCustomRewardRedemptionAdd(event: message.payload.event)
    }

    private func handleChannelRaid(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelRaidMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("twitch: event-sub: Failed to decode channel.raid (\(data ?? "")).")
            return
        }
        delegate.twitchEventSubChannelRaid(event: message.payload.event)
    }

    private func handleChannelCheer(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelCheerMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("twitch: event-sub: Failed to decode channel.cheer (\(data ?? "")).")
            return
        }
        delegate.twitchEventSubChannelCheer(event: message.payload.event)
    }

    private func handleChannelHypeTrainBegin(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelHypeTrainBeginMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("twitch: event-sub: Failed to decode channel.hype_train.begin (\(data ?? "")).")
            return
        }
        delegate.twitchEventSubChannelHypeTrainBegin(event: message.payload.event)
    }

    private func handleChannelHypeTrainProgress(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelHypeTrainProgressMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("twitch: event-sub: Failed to decode channel.hype_train.progress (\(data ?? "")).")
            return
        }
        delegate.twitchEventSubChannelHypeTrainProgress(event: message.payload.event)
    }

    private func handleChannelHypeTrainEnd(messageData: Data) {
        guard let message = try? JSONDecoder().decode(
            NotificationChannelHypeTrainEndMessage.self,
            from: messageData
        ) else {
            let data = String(data: messageData, encoding: .utf8)
            logger.info("twitch: event-sub: Failed to decode channel.hype_train.end (\(data ?? "")).")
            return
        }
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
