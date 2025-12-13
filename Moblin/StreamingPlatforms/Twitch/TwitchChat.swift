import Network
import SwiftUI

private enum MessageError: Error {
    case invalidCommand(String)
    case missingCommand(String)
}

enum TwitchChatCommand: String {
    case ping = "PING"
    case privateMessage = "PRIVMSG"
    case userNotice = "USERNOTICE"
    case clearChat = "CLEARCHAT"
    case clearMsg = "CLEARMSG"
}

extension StringProtocol where Self: RangeReplaceableCollection {
    func removingPrefix(_ prefix: String) -> Self {
        guard hasPrefix(prefix) else {
            return self
        }
        var copy = self
        copy.removeFirst(prefix.count)
        return copy
    }

    mutating func append(_ value: Self?) {
        guard let value else {
            return
        }
        append(contentsOf: value)
    }
}

private enum TwitchEmote {
    static func emotes(from string: String) -> [ChatMessageEmote] {
        let emoteDefinitions = string.split(separator: "/")
        return emoteDefinitions.flatMap { emotes(fromDefinition: $0) }
    }

    private static func emotes(fromDefinition definition: Substring) -> [ChatMessageEmote] {
        let parts = definition.split(separator: ":")
        guard parts.count == 2,
              let emoteId = parts.first,
              let emoteRangesString = parts.last,
              let url = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(emoteId)/default/dark/3.0")
        else {
            return []
        }
        var emotes: [ChatMessageEmote] = []
        for emoteRangeString in emoteRangesString.split(separator: ",") {
            let rangeIndexStrings = emoteRangeString.split(separator: "-")
            guard rangeIndexStrings.count == 2,
                  let rangeStartIndexString = rangeIndexStrings.first,
                  let rangeEndIndexString = rangeIndexStrings.last,
                  let rangeStartIndex = Int(rangeStartIndexString),
                  let rangeEndIndex = Int(rangeEndIndexString),
                  rangeStartIndex <= rangeEndIndex
            else {
                continue
            }
            emotes.append(ChatMessageEmote(url: url, range: rangeStartIndex ... rangeEndIndex))
        }
        return emotes
    }
}

private enum EmoteError: Error {
    case invalidImageURL
}

private struct ChatMessage {
    let id: String?
    let emotes: [ChatMessageEmote]
    let badges: [String]
    let displayName: String
    let user: String
    let userId: String?
    let senderColor: String?
    let text: String
    let announcement: Bool
    let firstMessage: Bool
    let subscriber: Bool
    let moderator: Bool
    let turbo: Bool
    let bits: String?
    let replySender: String?
    let replyText: String?

    init?(_ message: TwitchChatMessage) {
        guard message.parameters.count == 2,
              let text = message.parameters.last,
              let displayName = message.displayName,
              let user = message.user
        else {
            return nil
        }
        var announcement = false
        var firstMessage = false
        var subscriber = false
        var moderator = false
        var turbo = false
        switch message.command {
        case .privateMessage:
            firstMessage = message.first_message == "1"
            subscriber = message.subscriber == "1"
            moderator = message.moderator == "1"
            turbo = message.turbo == "1"
        case .userNotice:
            announcement = message.messageId == "announcement"
        default:
            return nil
        }
        id = message.id
        emotes = message.emotes
        badges = message.badges
        self.text = text
        self.displayName = displayName
        self.user = user
        userId = message.userId
        senderColor = message.color
        self.announcement = announcement
        self.firstMessage = firstMessage
        self.subscriber = subscriber
        self.moderator = moderator
        self.turbo = turbo
        bits = message.bits
        replySender = message.replySender
        replyText = message.replyText
    }

    func isAction() -> Bool {
        return text.starts(with: "\u{01}ACTION")
    }
}

private func parseTags(from string: String) -> [String: String] {
    let tagsString = string[string.index(after: string.startIndex)...]
    var tags: [String: String] = [:]
    for tag in tagsString.split(separator: ";") {
        if let (name, value) = tagNameAndValue(from: tag) {
            tags[name] = value
        }
    }
    return tags
}

private func tagNameAndValue(from specifier: Substring) -> (String, String)? {
    let parts = specifier.split(separator: "=")
    guard parts.count == 2, let name = parts.first, let value = parts.last else {
        return nil
    }
    guard !value.isEmpty else {
        return nil
    }
    var unescapedValue = ""
    let scanner = Scanner(string: String(value))
    while scanner.isAtEnd == false {
        unescapedValue.append(scanner.scanUpToString("\\"))
        _ = scanner.scanString("\\")
        if let escapedCharacter = scanner.scanCharacter() {
            switch escapedCharacter {
            case ":":
                unescapedValue.append(";")
            case "s":
                unescapedValue.append(" ")
            case "r":
                unescapedValue.append("\r")
            case "n":
                unescapedValue.append("\n")
            default:
                unescapedValue.append(escapedCharacter)
            }
        }
    }
    return (String(name), unescapedValue)
}

private func parseParameters(from parts: [String]) -> [String] {
    var parameters: [String] = []
    for index in parts.startIndex ..< parts.endIndex {
        let part = parts[index]
        guard part.hasPrefix(":") else {
            parameters.append(String(part))
            continue
        }
        let finalPart = parts.suffix(from: index).joined(separator: " ").removingPrefix(":")
        return parameters + [String(finalPart)]
    }
    return parameters
}

struct TwitchChatMessage {
    let tags: [String: String]
    let sourceString: String?
    let command: TwitchChatCommand
    let parameters: [String]

    init(string: String) throws {
        var parts = string.components(separatedBy: .whitespaces)
        if let tagsPart = parts.first, tagsPart.hasPrefix("@") {
            tags = parseTags(from: tagsPart)
            parts.removeFirst()
        } else {
            tags = [:]
        }
        if let sourcePart = parts.first, sourcePart.hasPrefix(":") {
            sourceString = String(sourcePart.removingPrefix(":"))
            parts.removeFirst()
        } else {
            sourceString = nil
        }
        guard let commandPart = parts.first else {
            throw MessageError.missingCommand(string)
        }
        let commandString = String(commandPart)
        guard let command = TwitchChatCommand(rawValue: commandString) else {
            throw MessageError.invalidCommand(commandString)
        }
        self.command = command
        parts.removeFirst()
        parameters = parseParameters(from: parts)
    }

    var displayName: String? {
        return tags["display-name"]
    }

    var user: String? {
        if let source = sourceString, let senderEndIndex = source.firstIndex(of: "!") {
            return String(source.prefix(upTo: senderEndIndex))
        } else {
            return nil
        }
    }

    var userId: String? {
        tags["user-id"]
    }

    var color: String? {
        tags["color"]
    }

    var emotes: [ChatMessageEmote] {
        guard let emoteString = tags["emotes"] else {
            return []
        }
        return TwitchEmote.emotes(from: emoteString)
    }

    var badges: [String] {
        guard let badges = tags["badges"] else {
            return []
        }
        return badges.split(separator: ",").map { String($0) }
    }

    var messageId: String? {
        tags["msg-id"]
    }

    var id: String? {
        tags["id"]
    }

    var first_message: String? {
        tags["first-msg"]
    }

    var subscriber: String? {
        tags["subscriber"]
    }

    var moderator: String? {
        tags["mod"]
    }

    var turbo: String? {
        tags["turbo"]
    }

    var bits: String? {
        tags["bits"]
    }

    var replySender: String? {
        tags["reply-parent-display-name"]
    }

    var replyText: String? {
        tags["reply-parent-msg-body"]
    }
}

private class Badges {
    private var channelId: String = ""
    private var accessToken: String = ""
    private var badges: [String: URL] = [:]
    private var tryFetchAgainTimer = SimpleTimer(queue: .main)

    func start(channelId: String, accessToken: String) {
        self.channelId = channelId
        self.accessToken = accessToken
        guard !accessToken.isEmpty else {
            return
        }
        tryFetch()
    }

    func stop() {
        stopTryFetchAgainTimer()
    }

    func getUrl(badgeId: String) -> URL? {
        return badges[badgeId]
    }

    func tryFetch() {
        startTryFetchAgainTimer()
        TwitchApi(accessToken).getGlobalChatBadges { data in
            guard let data else {
                return
            }
            DispatchQueue.main.async {
                self.addBadges(badges: data)
                TwitchApi(self.accessToken)
                    .getChannelChatBadges(broadcasterId: self.channelId) { data in
                        guard let data else {
                            return
                        }
                        DispatchQueue.main.async {
                            self.addBadges(badges: data)
                            self.stopTryFetchAgainTimer()
                        }
                    }
            }
        }
    }

    private func startTryFetchAgainTimer() {
        tryFetchAgainTimer.startSingleShot(timeout: 30) { [weak self] in
            self?.tryFetch()
        }
    }

    private func stopTryFetchAgainTimer() {
        tryFetchAgainTimer.stop()
    }

    private func addBadges(badges: [TwitchApiChatBadgesData]) {
        for badge in badges {
            for version in badge.versions {
                if let url = URL(string: version.image_url_2x) {
                    self.badges["\(badge.set_id)/\(version.id)"] = url
                }
            }
        }
    }
}

private class Cheermotes {
    private var channelId: String = ""
    private var accessToken: String = ""
    private var emotes: [String: [TwitchApiGetCheermotesDataTier]] = [:]
    private var tryFetchAgainTimer = SimpleTimer(queue: .main)

    func start(channelId: String, accessToken: String) {
        self.channelId = channelId
        self.accessToken = accessToken
        guard !accessToken.isEmpty else {
            return
        }
        tryFetch()
    }

    func stop() {
        stopTryFetchAgainTimer()
    }

    func tryFetch() {
        startTryFetchAgainTimer()
        TwitchApi(accessToken).getCheermotes(broadcasterId: channelId) { datas in
            guard let datas else {
                return
            }
            DispatchQueue.main.async {
                for data in datas {
                    self.emotes[data.prefix.lowercased()] = data.tiers
                }
                self.stopTryFetchAgainTimer()
            }
        }
    }

    private func startTryFetchAgainTimer() {
        tryFetchAgainTimer.startSingleShot(timeout: 30) { [weak self] in
            self?.tryFetch()
        }
    }

    private func stopTryFetchAgainTimer() {
        tryFetchAgainTimer.stop()
    }

    func getUrlAndBits(word: String) -> (URL, Int)? {
        let word = word.lowercased().trim()
        for (prefix, tiers) in emotes {
            guard let regex = try? Regex("\(prefix)(\\d+)", as: (Substring, Substring).self) else {
                continue
            }
            guard let match = try? regex.wholeMatch(in: word) else {
                continue
            }
            guard let bits = Int(match.output.1) else {
                continue
            }
            guard let tier = tiers.reversed().first(where: { bits >= $0.min_bits }) else {
                continue
            }
            guard let url = URL(string: tier.images.dark.static_.two) else {
                continue
            }
            return (url, bits)
        }
        return nil
    }
}

protocol TwitchChatDelegate: AnyObject {
    func twitchChatMakeErrorToast(title: String, subTitle: String?)
    func twitchChatAppendMessage(
        messageId: String?,
        displayName: String,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isAction: Bool,
        isSubscriber: Bool,
        isModerator: Bool,
        bits: String?,
        highlight: ChatHighlight?
    )
    func twitchChatDeleteMessage(messageId: String)
    func twitchChatDeleteUser(userId: String)
}

final class TwitchChat {
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var badges: Badges
    private var cheermotes: Cheermotes
    private var channelName: String
    private weak var delegate: (any TwitchChatDelegate)?

    init(delegate: TwitchChatDelegate) {
        self.delegate = delegate
        channelName = ""
        emotes = Emotes()
        badges = Badges()
        cheermotes = Cheermotes()
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!)
    }

    func start(
        channelName: String,
        channelId: String,
        settings: SettingsStreamChat,
        accessToken: String
    ) {
        self.channelName = channelName
        logger.debug("twitch: chat: Start")
        stopInternal()
        emotes.start(
            platform: .twitch,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        badges.start(channelId: channelId, accessToken: accessToken)
        cheermotes.start(channelId: channelId, accessToken: accessToken)
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!)
        webSocket.delegate = self
        webSocket.start()
    }

    func stop() {
        logger.debug("twitch: chat: Stop")
        stopInternal()
    }

    func stopInternal() {
        emotes.stop()
        badges.stop()
        cheermotes.stop()
        webSocket.stop()
    }

    func createSegmentsNoTwitchEmotes(text: String, bits: String?) -> [ChatPostSegment] {
        return createSegments(text: text, emotes: [], emotesManager: emotes, bits: bits)
    }

    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func handleMessage(message: String) throws {
        let message = try TwitchChatMessage(string: message)
        switch message.command {
        case .privateMessage, .userNotice:
            handleChatMessage(message: message)
        case .clearMsg:
            handleClearMessage(message: message)
        case .clearChat:
            handleClearChat(message: message)
        case .ping:
            handlePing(message: message)
        }
    }

    private func handleChatMessage(message: TwitchChatMessage) {
        guard let message = ChatMessage(message) else {
            return
        }
        var badgeUrls: [URL] = []
        for badge in message.badges {
            if let badgeUrl = badges.getUrl(badgeId: badge) {
                badgeUrls.append(badgeUrl)
            }
        }
        let text: String
        let isAction = message.isAction()
        if isAction {
            text = String(message.text.dropFirst(7))
        } else {
            text = message.text
        }
        let segments = createSegments(
            text: text,
            emotes: message.emotes,
            emotesManager: emotes,
            bits: message.bits
        )
        delegate?.twitchChatAppendMessage(
            messageId: message.id,
            displayName: message.displayName,
            user: message.user,
            userId: message.userId,
            userColor: RgbColor.fromHex(string: message.senderColor ?? ""),
            userBadges: badgeUrls,
            segments: segments,
            isAction: isAction,
            isSubscriber: message.subscriber,
            isModerator: message.moderator,
            bits: message.bits,
            highlight: createHighlight(message: message)
        )
    }

    private func handleClearMessage(message: TwitchChatMessage) {
        guard let targetMessageId = message.tags["target-msg-id"] else {
            return
        }
        delegate?.twitchChatDeleteMessage(messageId: targetMessageId)
    }

    private func handleClearChat(message: TwitchChatMessage) {
        guard let targetUserId = message.tags["target-user-id"] else {
            return
        }
        delegate?.twitchChatDeleteUser(userId: targetUserId)
    }

    private func handlePing(message: TwitchChatMessage) {
        webSocket.send(string: "PONG \(message.parameters.joined(separator: " "))")
    }

    private func createHighlight(message: ChatMessage) -> ChatHighlight? {
        if message.announcement {
            return ChatHighlight.makeAnnouncement()
        } else if message.firstMessage {
            return ChatHighlight.makeFirstMessage()
        } else if let sender = message.replySender, let text = message.replyText {
            return ChatHighlight.makeReply(
                user: sender,
                segments: createSegmentsNoTwitchEmotes(text: text, bits: nil)
            )
        } else {
            return nil
        }
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.delegate?.twitchChatMakeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleOk(title: String) {
        DispatchQueue.main.async {
            self.delegate?.twitchChatMakeErrorToast(title: title, subTitle: nil)
        }
    }

    private func createTwitchSegments(text: String,
                                      emotes: [ChatMessageEmote],
                                      id: inout Int) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        let unicodeText = text.unicodeScalars
        var startIndex = unicodeText.startIndex
        for emote in emotes.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            guard emote.range.lowerBound < unicodeText.count else {
                break
            }
            guard emote.range.upperBound < unicodeText.count else {
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
                segments += makeChatPostTextSegments(text: text, id: &id)
            }
            segments.append(ChatPostSegment(id: id, url: emote.url))
            id += 1
            segments.append(ChatPostSegment(id: id, text: ""))
            id += 1
            startIndex = unicodeText.index(
                unicodeText.startIndex,
                offsetBy: emote.range.upperBound + 1
            )
        }
        if startIndex < unicodeText.endIndex {
            for word in String(unicodeText[startIndex...]).components(separatedBy: .whitespacesAndNewlines)
                where !word.isEmpty
            {
                segments.append(ChatPostSegment(id: id, text: "\(word) "))
                id += 1
            }
        }
        return segments
    }

    private func createSegments(text: String,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes,
                                bits: String?) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        var id = 0
        for var segment in createTwitchSegments(text: text, emotes: emotes, id: &id) {
            if let text = segment.text {
                segments += emotesManager.createSegments(text: text, id: &id)
                segment.text = nil
            }
            if segment.text != nil || segment.url != nil {
                segments.append(segment)
            }
        }
        if bits != nil {
            segments = replaceCheermotes(segments: segments)
        }
        return segments
    }

    private func replaceCheermotes(segments: [ChatPostSegment]) -> [ChatPostSegment] {
        var newSegments: [ChatPostSegment] = []
        guard var id = segments.last?.id else {
            return newSegments
        }
        for segment in segments {
            guard let text = segment.text else {
                newSegments.append(segment)
                continue
            }
            guard let (url, bits) = cheermotes.getUrlAndBits(word: text) else {
                newSegments.append(segment)
                continue
            }
            id += 1
            newSegments.append(.init(id: id, url: url))
            id += 1
            newSegments.append(.init(id: id, text: "\(bits) "))
        }
        return newSegments
    }
}

extension TwitchChat: WebSocketClientDelegate {
    func webSocketClientConnected(_ webSocket: WebSocketClient) {
        logger.debug("twitch: chat: Connected")
        webSocket.send(string: "CAP REQ :twitch.tv/membership")
        webSocket.send(string: "CAP REQ :twitch.tv/tags")
        webSocket.send(string: "CAP REQ :twitch.tv/commands")
        webSocket.send(string: "PASS oauth:SCHMOOPIIE")
        webSocket.send(string: "NICK justinfan67420")
        webSocket.send(string: "JOIN #\(channelName)")
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("twitch: chat: Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        for line in string.split(whereSeparator: { $0.isNewline }) {
            try? handleMessage(message: String(line))
        }
    }
}
