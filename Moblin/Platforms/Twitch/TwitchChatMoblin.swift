import Network
import NWWebSocket
import SwiftUI
import TwitchChat

private func getEmotes(from message: ChatMessage) -> [ChatMessageEmote] {
    var emotes: [ChatMessageEmote] = []
    for emote in message.emotes {
        do {
            try emotes.append(ChatMessageEmote(url: emote.imageURL, range: emote.range))
        } catch {
            logger.warning("twitch: chat: Failed to get emote URL")
        }
    }
    return emotes
}

final class TwitchChatMoblin {
    private var model: Model
    private var connected: Bool = false
    private var webSocket: NWWebSocket
    private var emotes: Emotes
    private var reconnectTimer: DispatchSourceTimer?
    private var networkInterfaceTypeSelector = NetworkInterfaceTypeSelector(queue: .main)
    private var pingTimer: DispatchSourceTimer?
    private var pongReceived: Bool = true
    private var channelName: String
    private var channelId: String
    private var settings: SettingsStreamChat

    init(model: Model) {
        self.model = model
        channelName = ""
        channelId = ""
        settings = SettingsStreamChat()
        emotes = Emotes()
        webSocket = NWWebSocket(url: URL(string: "wss://a.c")!, requiredInterfaceType: .cellular)
    }

    func start(channelName: String, channelId: String, settings: SettingsStreamChat) {
        self.channelName = channelName
        self.channelId = channelId
        self.settings = settings
        logger.debug("twitch: chat: Start")
        startInternal()
    }

    func stop() {
        logger.debug("twitch: chat: Stop")
        stopInternal()
    }

    private func startInternal() {
        stopInternal()
        emotes.start(
            platform: .twitch,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        let networkInterfaceType = networkInterfaceTypeSelector.getNextType()
        webSocket = NWWebSocket(
            url: URL(string: "wss://irc-ws.chat.twitch.tv")!,
            requiredInterfaceType: networkInterfaceType
        )
        logger
            .info("twitch: chat: Connecting using network interface type \(networkInterfaceType)")
        webSocket.delegate = self
        webSocket.connect()
        startReconnectTimer()
    }

    func stopInternal() {
        emotes.stop()
        connected = false
        webSocket.disconnect(closeCode: .protocolCode(.goingAway))
        stopReconnectTimer()
        stopPingTimer()
    }

    private func startReconnectTimer() {
        reconnectTimer = DispatchSource.makeTimerSource(queue: .main)
        reconnectTimer!.schedule(deadline: .now() + 5)
        reconnectTimer!.setEventHandler { [weak self] in
            self?.startInternal()
        }
        reconnectTimer!.activate()
    }

    private func stopReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func startPingTimer() {
        pongReceived = true
        pingTimer = DispatchSource.makeTimerSource(queue: .main)
        pingTimer!.schedule(deadline: .now(), repeating: 5)
        pingTimer!.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            if self.pongReceived {
                self.pongReceived = false
                self.webSocket.ping()
            } else {
                logger.debug("twitch: chat: Pong timeout")
                self.startInternal()
            }
        }
        pingTimer!.activate()
    }

    private func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }

    private func handleMessage(message: String) throws {
        guard let message = try ChatMessage(Message(string: message)) else {
            return
        }
        let emotes = getEmotes(from: message)
        let text: String
        let isAction = message.isAction()
        if isAction {
            text = String(message.text.dropFirst(7))
        } else {
            text = message.text
        }
        let segments = createSegments(
            text: text,
            emotes: emotes,
            emotesManager: self.emotes
        )
        model.appendChatMessage(
            user: message.sender,
            userColor: message.senderColor,
            segments: segments,
            timestamp: model.digitalClock,
            timestampTime: .now,
            isAction: isAction,
            isAnnouncement: message.announcement,
            isFirstMessage: message.firstMessage,
            isSubscriber: message.subscriber
        )
    }

    func isConnected() -> Bool {
        return connected
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.model.makeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleOk(title: String) {
        DispatchQueue.main.async {
            self.model.makeToast(title: title)
        }
    }

    private func createTwitchSegments(text: String,
                                      emotes: [ChatMessageEmote]) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        let unicodeText = text.unicodeScalars
        var startIndex = unicodeText.startIndex
        for emote in emotes.sorted(by: { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }) {
            if !(emote.range.lowerBound < unicodeText.count) {
                logger
                    .warning(
                        """
                        twitch: chat: Emote lower bound \(emote.range.lowerBound) after \
                        message end \(unicodeText.count) '\(unicodeText)'
                        """
                    )
                break
            }
            if !(emote.range.upperBound < unicodeText.count) {
                logger
                    .warning(
                        """
                        twitch: chat: Emote upper bound \(emote.range.upperBound) after \
                        message end \(unicodeText.count) '\(unicodeText)'
                        """
                    )
                break
            }
            var text: String?
            if emote.range.lowerBound > 0 {
                let endIndex = unicodeText.index(
                    unicodeText.startIndex,
                    offsetBy: emote.range.lowerBound - 1
                )
                if startIndex < endIndex {
                    text = String(unicodeText[startIndex ... endIndex])
                }
            }
            if let text {
                segments += makeChatPostTextSegments(text: text)
            }
            segments.append(ChatPostSegment(url: emote.url))
            segments.append(ChatPostSegment(text: ""))
            startIndex = unicodeText.index(
                unicodeText.startIndex,
                offsetBy: emote.range.upperBound + 1
            )
        }
        if startIndex < unicodeText.endIndex {
            for word in String(unicodeText[startIndex...]).split(separator: " ") {
                segments.append(ChatPostSegment(text: "\(word) "))
            }
        }
        return segments
    }

    private func createSegments(text: String,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        for var segment in createTwitchSegments(text: text, emotes: emotes) {
            if let text = segment.text {
                segments += emotesManager.createSegments(text: text)
                segment.text = nil
            }
            segments.append(segment)
        }
        return segments
    }
}

extension ChatMessage {
    func isAction() -> Bool {
        return text.starts(with: "\u{01}ACTION")
    }
}

extension TwitchChatMoblin: WebSocketConnectionDelegate {
    func webSocketDidConnect(connection _: WebSocketConnection) {
        logger.debug("twitch: chat: Connected")
        connected = true
        stopReconnectTimer()
        startPingTimer()
        webSocket.send(string: "CAP REQ :twitch.tv/membership")
        webSocket.send(string: "CAP REQ :twitch.tv/tags")
        webSocket.send(string: "CAP REQ :twitch.tv/commands")
        webSocket.send(string: "PASS oauth:SCHMOOPIIE")
        webSocket.send(string: "NICK justinfan67420")
        webSocket.send(string: "JOIN #\(channelName)")
    }

    func webSocketDidDisconnect(connection _: WebSocketConnection,
                                closeCode _: NWProtocolWebSocket.CloseCode, reason _: Data?)
    {
        logger.debug("twitch: chat: Disconnected")
        connected = false
        startReconnectTimer()
    }

    func webSocketViabilityDidChange(connection _: WebSocketConnection, isViable: Bool) {
        logger.debug("twitch: chat: isViable \(isViable)")
    }

    func webSocketDidAttemptBetterPathMigration(result _: Result<WebSocketConnection, NWError>) {
        logger.debug("twitch: chat: Better path")
    }

    func webSocketDidReceiveError(connection _: WebSocketConnection, error: NWError) {
        logger.debug("twitch: chat: Error \(error.localizedDescription)")
        connected = false
        startReconnectTimer()
    }

    func webSocketDidReceivePong(connection _: WebSocketConnection) {
        pongReceived = true
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, string: String) {
        for line in string.split(whereSeparator: { $0.isNewline }) {
            try? handleMessage(message: String(line))
        }
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, data _: Data) {}
}
