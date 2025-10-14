import Foundation

private struct Sender: Decodable {
    let id: String?
    let username: String
    let displayname: String
    let avatar: String?
    let badges: [String]?
}

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
}

protocol DLiveChatDelegate: AnyObject {
    func dliveChatMakeErrorToast(title: String, subTitle: String?)
    func dliveChatAppendMessage(messageId: String?,
                                user: String,
                                userId: String?,
                                userColor: RgbColor?,
                                userBadges: [URL],
                                segments: [ChatPostSegment],
                                isSubscriber: Bool,
                                isModerator: Bool)
    func dliveChatDeleteMessage(messageId: String)
    func dliveChatDeleteUser(userId: String)
}

private let subscriptionQuery = """
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

private let webSocketUrl = URL(string: "wss://graphigostream.prd.dlive.tv/")!
private let userIdPrefix = "user:"
private let nativeEmoteBaseUrl = "https://images.prd.dlivecdn.com/emoji/"
private let customEmoteBaseUrl = "https://images.prd.dlivecdn.com/emote/"

final class DLiveChat {
    private var webSocket: WebSocketClient
    private var streamerRoomId: String
    private weak var delegate: (any DLiveChatDelegate)?

    init(delegate: DLiveChatDelegate) {
        self.delegate = delegate
        streamerRoomId = ""
        webSocket = WebSocketClient(url: webSocketUrl)
    }

    func start(streamerUsername: String) {
        logger.debug("dlive: chat: Start")
        stopInternal()
        getDLiveUserInfo(displayName: streamerUsername) { [weak self] userInfo in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if let userInfo {
                    self.streamerRoomId = userInfo.id.replacingOccurrences(of: userIdPrefix, with: "")
                    self.webSocket = WebSocketClient(url: webSocketUrl, protocols: ["graphql-ws"])
                    self.webSocket.delegate = self
                    self.webSocket.start()
                } else {
                    self.handleError(title: "DLive user not found", subTitle: "Check the username")
                }
            }
        }
    }

    func stop() {
        logger.debug("dlive: chat: Stop")
        stopInternal()
    }

    func stopInternal() {
        webSocket.delegate = nil
        webSocket.stop()
    }

    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        return true
    }

    private func handleError(title: String, subTitle: String) {
        delegate?.dliveChatMakeErrorToast(title: title, subTitle: subTitle)
    }

    private func handleMessage(message: String) {
        // logger.debug("dlive: chat: Received message: \(message)")
        do {
            guard let message = message.data(using: .utf8) else {
                return
            }
            guard let message = try JSONSerialization.jsonObject(with: message) as? [String: Any] else {
                return
            }
            guard let type = message["type"] as? String else {
                return
            }
            switch type {
            case "ka":
                break
            case "connection_ack":
                handleConnectionAck()
            case "data":
                try handleDataMessage(message: message)
            default:
                break
            }
        } catch {
            logger.error("dlive: chat: Failed to handle message: \(error)")
        }
    }

    private func handleDataMessage(message: [String: Any]) throws {
        guard let payload = message["payload"] as? [String: Any],
              let data = payload["data"] as? [String: Any],
              let streamMessageReceived = data["streamMessageReceived"] as? [[String: Any]]
        else {
            logger.debug("dlive: chat: Failed to parse data message structure")
            return
        }
        for message in streamMessageReceived {
            guard let typename = message["__typename"] as? String else {
                continue
            }
            switch typename {
            case "ChatText":
                try handleChatTextMessage(message)
            case "ChatDelete":
                handleChatDelete(message)
            case "ChatBan":
                handleChatBan(message)
            default:
                logger.debug("dlive: chat: Unhandled message type: \(typename)")
            }
        }
    }

    private func handleChatDelete(_ message: [String: Any]) {
        guard let ids = message["ids"] as? [String] else {
            return
        }
        for id in ids {
            delegate?.dliveChatDeleteMessage(messageId: id)
        }
    }

    private func handleChatBan(_ message: [String: Any]) {
        guard let sender = message["sender"] as? [String: Any],
              let userId = sender["id"] as? String
        else {
            return
        }
        delegate?.dliveChatDeleteUser(userId: userId)
    }

    private func handleChatTextMessage(_ message: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        let chatMessage = try JSONDecoder().decode(ChatTextMessage.self, from: jsonData)
        var dLiveEmotes: [String: URL] = [:]
        if let emojis = message["emojis"] as? [Int], emojis.count % 2 == 0 {
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
                if let url = URL(string: nativeEmoteBaseUrl + emoteName) {
                    dLiveEmotes[emoteName] = url
                }
            }
        }
        for match in chatMessage.content.matches(of: /:emote\/global\/lino\/([^:]+):/) {
            let emoteId = String(match.1)
            if let url = URL(string: customEmoteBaseUrl + emoteId) {
                let fullEmote = String(match.0)
                dLiveEmotes[fullEmote] = url
            }
        }
        delegate?.dliveChatAppendMessage(
            messageId: chatMessage.id,
            user: chatMessage.sender.username,
            userId: chatMessage.sender.id,
            userColor: nil,
            userBadges: [],
            segments: createSegments(text: chatMessage.content, dLiveEmotes: dLiveEmotes),
            isSubscriber: chatMessage.subscribing == true,
            isModerator: chatMessage.role == "Moderator" || chatMessage.roomRole == "Owner"
        )
    }

    private func createSegments(text: String, dLiveEmotes: [String: URL]) -> [ChatPostSegment] {
        var id = 0
        var segments: [ChatPostSegment] = []
        var parts: [String] = []
        for word in text.components(separatedBy: .whitespaces) {
            if let emoteUrl = dLiveEmotes[word] {
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

    private func handleConnectionAck() {
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
            webSocket.send(string: jsonString)
        }
    }
}

extension DLiveChat: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.debug("dlive: chat: WebSocket connected")
        let initMessage: [String: Any] = [
            "type": "connection_init",
            "payload": [:],
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: initMessage),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            webSocket.send(string: jsonString)
        }
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("dlive: chat: WebSocket disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        handleMessage(message: string)
    }
}
