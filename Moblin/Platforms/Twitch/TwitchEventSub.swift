import Foundation

private struct BasicMetadata: Decodable {
    // periphery:ignore
    var message_id: String
    var message_type: String
    // periphery:ignore
    var message_timestamp: String
    var subscription_type: String?
    // periphery:ignore
    var subscription_version: String?
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

private var url = URL(string: "wss://eventsub.wss.twitch.tv/ws")!

protocol TwitchEventSubDelegate: AnyObject {
    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent)
    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent)
}

final class TwitchEventSub: NSObject {
    private var webSocket: WebSocketClient
    private let userId: String
    private var sessionId: String = ""
    private var twitchApi: TwitchApi
    private let delegate: any TwitchEventSubDelegate

    init(userId: String, accessToken: String, delegate: TwitchEventSubDelegate) {
        self.userId = userId
        self.delegate = delegate
        twitchApi = TwitchApi(accessToken: accessToken)
        webSocket = .init(url: url)
        super.init()
    }

    func start() {
        logger.info("twitch: event-sub: Start")
        stopInternal()
        connect()
    }

    private func connect() {
        webSocket = .init(url: url)
        webSocket.delegate = self
        webSocket.start()
    }

    func stop() {
        logger.info("twitch: event-sub: Stop")
        stopInternal()
    }

    func stopInternal() {
        webSocket.stop()
    }

    // periphery:ignore
    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    private func handleMessage(message: String) {
        let messageData = message.utf8Data
        guard let message = try? JSONDecoder().decode(BasicMessage.self, from: messageData) else {
            return
        }
        switch message.metadata.message_type {
        case "session_welcome":
            handleSessionWelcome(messageData: messageData)
        case "session_keepalive":
            break
        case "notification":
            handleNotification(message: message, messageData: messageData)
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
        twitchApi.createEventSubSubscription(body: createChannelFollowBody()) { ok, unauthorized in
            logger.info("twitch: event-sub: Follow result \(ok) \(unauthorized)")
            self.twitchApi
                .createEventSubSubscription(body: self.createChannelSubscribeBody()) { ok, unauthorized in
                    logger.info("twitch: event-sub: Subscribe result \(ok) \(unauthorized)")
                }
        }
    }

    private func createChannelFollowBody() -> String {
        return createBody(
            type: "channel.follow",
            version: 2,
            condition: "{\"broadcaster_user_id\":\"\(userId)\",\"moderator_user_id\":\"\(userId)\"}"
        )
    }

    private func createChannelSubscribeBody() -> String {
        return createBody(type: "channel.subscribe",
                          version: 1,
                          condition: "{\"broadcaster_user_id\":\"\(userId)\"}")
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

    private func handleNotification(message: BasicMessage, messageData: Data) {
        switch message.metadata.subscription_type {
        case "channel.follow":
            handleNotificationChannelFollow(messageData: messageData)
        case "channel.subscribe":
            handleNotificationChannelSubscribe(messageData: messageData)
        default:
            if let type = message.metadata.subscription_type {
                logger.info("twitch: event-sub: Unknown notification type \(type)")
            } else {
                logger.info("twitch: event-sub: Missing notification type")
            }
        }
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
}

extension TwitchEventSub: WebSocketClientDelegate {
    func webSocketClientConnected() {}

    func webSocketClientDisconnected() {}

    func webSocketClientReceiveMessage(string: String) {
        handleMessage(message: string)
    }
}
