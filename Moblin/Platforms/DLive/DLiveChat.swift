import Foundation

private struct Sender: Decodable {
    let id: String?
    let username: String
    let displayname: String
    let avatar: String?
    let partnerStatus: String?
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

private let customEmoteRegex = try! NSRegularExpression(pattern: ":emote/global/lino/([^:]+):")
private let webSocketUrl = URL(string: "wss://graphigostream.prd.dlive.tv/")!
private let userIdPrefix = "user:"
private let nativeEmoteBaseUrl = "https://images.prd.dlivecdn.com/emoji/"
private let customEmoteBaseUrl = "https://images.prd.dlivecdn.com/emote/"

final class DLiveChat {
    private var webSocket: WebSocketClient
    private var streamerUsername: String
    private var streamerRoomId: String
    private weak var delegate: (any DLiveChatDelegate)?

    init(delegate: DLiveChatDelegate) {
        self.delegate = delegate
        streamerUsername = ""
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
                    self.streamerUsername = userInfo.username
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
            guard let data = message.data(using: .utf8) else {
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let type = json?["type"] as? String else {
                return
            }
            switch type {
            case "ka":
                break
            case "connection_ack":
                handleConnectionAck()
            case "data":
                try handleDataMessage(json: json)
            default:
                break
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
            return
        }
        for messageData in streamMessageReceived {
            guard let typename = messageData["__typename"] as? String else {
                continue
            }
            switch typename {
            case "ChatText":
                try handleChatTextMessage(messageData)
            case "ChatDelete":
                handleChatDelete(messageData)
            case "ChatBan":
                handleChatBan(messageData)
            default:
                logger.debug("dlive: chat: Unhandled message type: \(typename)")
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
                if let url = URL(string: nativeEmoteBaseUrl + emoteName) {
                    dliveEmotes[emoteName] = url
                }
            }
        }
        let matches = customEmoteRegex.matches(
            in: chatMessage.content,
            range: NSRange(chatMessage.content.startIndex..., in: chatMessage.content)
        )
        for match in matches {
            if let range = Range(match.range(at: 0), in: chatMessage.content),
               let idRange = Range(match.range(at: 1), in: chatMessage.content)
            {
                let fullEmote = String(chatMessage.content[range])
                let emoteId = String(chatMessage.content[idRange])
                if let url = URL(string: customEmoteBaseUrl + emoteId) {
                    dliveEmotes[fullEmote] = url
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
