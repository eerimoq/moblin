import Foundation

private struct ChatTextMessage: Decodable {
    let __typename: String
    let type: String
    let id: String
    let content: String
    let createdAt: String
    let sender: Sender
    let role: String?
    let roomRole: String?
    let subscribing: Bool?

    struct Sender: Decodable {
        let id: String?
        let username: String
        let displayname: String
        let avatar: String?
        let partnerStatus: String?
        let badges: [String]?
    }

    private enum CodingKeys: String, CodingKey {
        case __typename, type, id, content, createdAt, sender, role, roomRole, subscribing
    }
}

private struct StreamMessageData: Decodable {
    let __typename: String?

    private enum CodingKeys: String, CodingKey {
        case __typename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        __typename = try? container.decode(String.self, forKey: .__typename)
    }
}

private struct SubscriptionPayload: Decodable {
    let data: SubscriptionData

    struct SubscriptionData: Decodable {
        let streamMessageReceived: StreamMessageData
    }
}

protocol DLiveChatDelegate: AnyObject {
    func dliveChatMakeErrorToast(title: String, subTitle: String?)
    func dliveChatAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool
    )
    func dliveChatDeleteMessage(messageId: String)
    func dliveChatDeleteUser(userId: String)
}

final class DLiveChat {
    private static let customEmoteRegex = try? NSRegularExpression(pattern: ":emote/global/lino/([^:]+):")
    private static let webSocketURL = URL(string: "wss://graphigostream.prd.dlive.tv/")!
    private static let userIDPrefix = "user:"
    private static let nativeEmoteBaseURL = "https://images.prd.dlivecdn.com/emoji/"
    private static let customEmoteBaseURL = "https://images.prd.dlivecdn.com/emote/"

    private var webSocket: DLiveWebSocketClient
    private var streamerUsername: String
    private var streamerRoomId: String
    private weak var delegate: (any DLiveChatDelegate)?
    private var connectionAcknowledged = false

    init(delegate: DLiveChatDelegate) {
        self.delegate = delegate
        streamerUsername = ""
        streamerRoomId = ""
        webSocket = DLiveWebSocketClient(url: Self.webSocketURL)
        webSocket.delegate = self
    }

    func start(streamerUsername: String) {
        logger.debug("dlive: chat: Start")
        stopInternal()
        getDLiveUserInfo(displayName: streamerUsername) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(userInfo):
                self.streamerUsername = userInfo.username
                self.streamerRoomId = userInfo.id.replacingOccurrences(of: Self.userIDPrefix, with: "")
                self.connectionAcknowledged = false
                self.webSocket.connect()
            case .failure:
                self.handleError(title: "DLive user not found", subTitle: "Check the username")
            }
        }
    }

    func stop() {
        logger.debug("dlive: chat: Stop")
        stopInternal()
    }

    func stopInternal() {
        webSocket.disconnect()
        connectionAcknowledged = false
    }

    func isConnected() -> Bool {
        return webSocket.isSocketConnected()
    }

    func hasEmotes() -> Bool {
        return isConnected()
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.delegate?.dliveChatMakeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleMessage(message: String) {
        logger.debug("dlive: chat: Received message: \(message)")
        do {
            guard let data = message.data(using: .utf8) else {
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let type = json?["type"] as? String else {
                return
            }

            logger.debug("dlive: chat: Message type: \(type)")

            switch type {
            case "ka":
                logger.debug("dlive: chat: Keep-alive received")
            case "connection_ack":
                logger.debug("dlive: chat: Connection acknowledged, subscribing to chat")
                connectionAcknowledged = true
                subscribeToChat()
            case "data":
                if connectionAcknowledged {
                    try handleDataMessage(json: json)
                } else {
                    logger.debug("dlive: chat: Received data before connection_ack, ignoring")
                }
            default:
                logger.debug("dlive: chat: Unknown message type: \(type)")
            }
        } catch {
            logger.error("dlive: chat: Failed to handle message: \(error)")
        }
    }

    private func handleDataMessage(json: [String: Any]?) throws {
        guard let payload = json?["payload"] as? [String: Any],
              let data = payload["data"] as? [String: Any],
              let streamMessageReceived = data["streamMessageReceived"] as? [[String: Any]]
        else {
            logger.debug("dlive: chat: Failed to parse data message structure")
            if let jsonData = try? JSONSerialization.data(withJSONObject: json ?? [:], options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                logger.debug("dlive: chat: Raw JSON: \(jsonString)")
            }
            return
        }

        logger.debug("dlive: chat: Received \(streamMessageReceived.count) message(s)")

        for messageData in streamMessageReceived {
            guard let typename = messageData["__typename"] as? String else {
                logger.debug("dlive: chat: Message missing __typename field")
                continue
            }

            logger.debug("dlive: chat: Processing message type: \(typename)")

            switch typename {
            case "ChatText":
                try handleChatTextMessage(messageData)
            case "ChatDelete":
                handleChatDelete(messageData)
            case "ChatBan":
                handleChatBan(messageData)
            default:
                logger.debug("dlive: chat: Unhandled message type: \(typename)")
                if let jsonData = try? JSONSerialization.data(withJSONObject: messageData, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8)
                {
                    logger.debug("dlive: chat: Unhandled message data: \(jsonString)")
                }
            }
        }
    }

    private func handleChatDelete(_ messageData: [String: Any]) {
        guard let ids = messageData["ids"] as? [String] else {
            return
        }
        for id in ids {
            delegate?.dliveChatDeleteMessage(messageId: id)
        }
    }

    private func handleChatBan(_ messageData: [String: Any]) {
        guard let sender = messageData["sender"] as? [String: Any],
              let userId = sender["id"] as? String
        else {
            return
        }
        delegate?.dliveChatDeleteUser(userId: userId)
    }

    private func handleChatTextMessage(_ messageData: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: messageData)
        let chatMessage = try JSONDecoder().decode(ChatTextMessage.self, from: jsonData)

        var dliveEmotes: [String: URL] = [:]
        if let emojis = messageData["emojis"] as? [Int], emojis.count % 2 == 0 {
            for i in stride(from: 0, to: emojis.count, by: 2) {
                let startPos = emojis[i]
                let endPos = emojis[i + 1]
                guard startPos >= 0, endPos < chatMessage.content.count, startPos <= endPos else {
                    continue
                }
                let content = chatMessage.content
                let startIndex = content.index(content.startIndex, offsetBy: startPos)
                let endIndex = content.index(content.startIndex, offsetBy: endPos)
                let emoteName = String(content[startIndex ... endIndex])
                if let url = URL(string: Self.nativeEmoteBaseURL + emoteName) {
                    dliveEmotes[emoteName] = url
                }
            }
        }

        if let regex = Self.customEmoteRegex {
            let matches = regex.matches(
                in: chatMessage.content,
                range: NSRange(chatMessage.content.startIndex..., in: chatMessage.content)
            )
            for match in matches {
                if let range = Range(match.range(at: 0), in: chatMessage.content),
                   let idRange = Range(match.range(at: 1), in: chatMessage.content)
                {
                    let fullEmote = String(chatMessage.content[range])
                    let emoteId = String(chatMessage.content[idRange])
                    if let url = URL(string: Self.customEmoteBaseURL + emoteId) {
                        dliveEmotes[fullEmote] = url
                    }
                }
            }
        }

        var id = 0
        let segments = createSegments(text: chatMessage.content, dliveEmotes: dliveEmotes, id: &id)
        let isSubscriber = chatMessage.subscribing == true
        let isModerator = chatMessage.role == "Moderator" || chatMessage.roomRole == "Owner"

        delegate?.dliveChatAppendMessage(
            messageId: chatMessage.id,
            user: chatMessage.sender.username,
            userId: chatMessage.sender.id,
            userColor: nil,
            userBadges: [],
            segments: segments,
            isSubscriber: isSubscriber,
            isModerator: isModerator
        )
    }

    private func createSegments(text: String, dliveEmotes: [String: URL], id: inout Int) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var parts: [String] = []

        for word in text.components(separatedBy: .whitespaces) {
            if let emoteUrl = dliveEmotes[word] {
                if !parts.isEmpty {
                    segments.append(ChatPostSegment(id: id, text: parts.joined(separator: " ")))
                    id += 1
                    parts.removeAll()
                }
                segments.append(ChatPostSegment(id: id, text: nil, url: emoteUrl))
                id += 1
            } else {
                parts.append(word)
            }
        }

        if !parts.isEmpty {
            segments.append(ChatPostSegment(id: id, text: parts.joined(separator: " ")))
            id += 1
        }

        return segments
    }

    private func subscribeToChat() {
        let subscriptionQuery = """
        subscription StreamMessageSubscription($streamer: String!, $viewer: String) {
          streamMessageReceived(streamer: $streamer, viewer: $viewer) {
            type
            ... on ChatText {
              id
              emojis
              content
              createdAt
              subLength
              subscribing
              role
              roomRole
              sender {
                id
                username
                displayname
                avatar
                partnerStatus
                badges
                effect
                __typename
              }
              __typename
            }
            ... on ChatDelete {
              ids
              __typename
            }
            ... on ChatBan {
              id
              sender {
                id
                username
                displayname
                __typename
              }
              bannedBy {
                id
                displayname
                __typename
              }
              bannedByRoomRole
              __typename
            }
            __typename
          }
        }
        """

        let subscribeMessage: [String: Any] = [
            "id": "1",
            "type": "start",
            "payload": [
                "variables": [
                    "streamer": streamerRoomId,
                    "viewer": streamerRoomId,
                ],
                "extensions": [
                    "persistedQuery": [
                        "version": 1,
                        "sha256Hash": "901f60729019f928b5e3a71a1188716a30667765253d1b36bcb08329ac4f398d",
                    ],
                ],
                "operationName": "StreamMessageSubscription",
                "query": subscriptionQuery,
            ],
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: subscribeMessage),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            webSocket.send(text: jsonString)
            logger.debug("dlive: chat: Subscribed to room \(streamerRoomId)")
        }
    }
}

extension DLiveChat: DLiveWebSocketClientDelegate {
    func dliveWebSocketDidConnect() {
        logger.debug("dlive: chat: WebSocket connected, sending connection_init")
        let initMessage: [String: Any] = [
            "type": "connection_init",
            "payload": [:],
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: initMessage),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            webSocket.send(text: jsonString)
            logger.debug("dlive: chat: Sent connection_init")
        }
    }

    func dliveWebSocketDidDisconnect() {
        logger.debug("dlive: chat: WebSocket disconnected")
        connectionAcknowledged = false
    }

    func dliveWebSocketDidReceiveMessage(text: String) {
        handleMessage(message: text)
    }
}
