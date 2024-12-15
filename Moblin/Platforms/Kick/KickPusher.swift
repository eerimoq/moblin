import Foundation

private struct Badge: Decodable {
    var type: String
}

private struct Identity: Decodable {
    var color: String
    var badges: [Badge]
}

private struct Sender: Decodable {
    var username: String
    var identity: Identity
}

private struct ChatMessage: Decodable {
    var content: String
    var sender: Sender

    func isModerator() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == "moderator" })
    }

    func isSubscriber() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == "subscriber" })
    }
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

private func decodeChatMessage(data: String) throws -> ChatMessage {
    return try JSONDecoder().decode(
        ChatMessage.self,
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
        user: String,
        userColor: RgbColor?,
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool
    )
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
            if type == "App\\Events\\ChatMessageEvent" {
                try handleChatMessageEvent(data: data)
            } else {
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
        let message = try decodeChatMessage(data: data)
        var segments: [ChatPostSegment] = []
        var id = 0
        for var segment in createKickSegments(message: message.content, id: &id) {
            if let text = segment.text {
                segments += emotes.createSegments(text: text, id: &id)
                segment.text = nil
            }
            if segment.text != nil || segment.url != nil {
                segments.append(segment)
            }
        }
        delegate?.kickPusherAppendMessage(
            user: message.sender.username,
            userColor: RgbColor.fromHex(string: message.sender.identity.color),
            segments: segments,
            isSubscriber: message.isSubscriber(),
            isModerator: message.isModerator()
        )
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
}

extension KickPusher: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.debug("kick: Connected")
        sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"chatrooms.\(channelId).v2\"}}
            """
        )
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("kick: Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        handleMessage(message: string)
    }
}
