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
}

private func parseRange(_ string: Substring) -> ClosedRange<Int>? {
    let rangeIndexStrings = string.split(separator: "-")
    guard rangeIndexStrings.count == 2,
          let rangeStartIndexString = rangeIndexStrings.first,
          let rangeEndIndexString = rangeIndexStrings.last,
          let rangeStartIndex = Int(rangeStartIndexString),
          let rangeEndIndex = Int(rangeEndIndexString),
          rangeStartIndex <= rangeEndIndex
    else {
        return nil
    }
    return rangeStartIndex ... rangeEndIndex
}

private func parseEmotes(from string: String) -> [ChatMessageEmote] {
    let emoteDefinitions = string.split(separator: "/")
    return emoteDefinitions.flatMap { emotes(fromDefinition: $0) }
}

private func emotes(fromDefinition definition: Substring) -> [ChatMessageEmote] {
    let parts = definition.split(separator: ":")
    guard parts.count == 2,
          let emoteId = parts.first,
          let emoteRangesString = parts.last,
          let url = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(emoteId)/default/dark/3.0"),
          let stillUrl = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(emoteId)/static/dark/3.0")
    else {
        return []
    }
    var emotes: [ChatMessageEmote] = []
    for emoteRangeString in emoteRangesString.split(separator: ",") {
        guard let range = parseRange(emoteRangeString) else {
            continue
        }
        emotes.append(ChatMessageEmote(url: url, stillUrl: stillUrl, range: range))
    }
    return emotes
}

private func parseGif(from string: String) -> ChatMessageEmote? {
    let parts = string.split(separator: "|", maxSplits: 2)
    guard parts.count == 3,
          let range = parseRange(parts[0]),
          let url = URL(string: String(parts[2]))
    else {
        return nil
    }
    return ChatMessageEmote(url: lowResolutionGiphyUrl(url), range: range, isGif: true)
}

private func lowResolutionGiphyUrl(_ url: URL) -> URL {
    guard url.host?.hasSuffix("giphy.com") == true else {
        return url
    }
    return url.deletingLastPathComponent().appendingPathComponent("100.gif")
}

private func tagNameAndValue(from specifier: Substring) -> (String, String)? {
    let parts = specifier.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, let name = parts.first, let value = parts.last else {
        return nil
    }
    guard !value.isEmpty else {
        return nil
    }
    return (String(name), unescapeTagValue(value))
}

private func unescapeTagValue(_ value: Substring) -> String {
    guard value.utf8.contains(UInt8(ascii: "\\")) else {
        return String(value)
    }
    var unescapedValue = ""
    unescapedValue.reserveCapacity(value.count)
    var index = value.startIndex
    while index < value.endIndex {
        let character = value[index]
        index = value.index(after: index)
        guard character == "\\", index < value.endIndex else {
            if character != "\\" {
                unescapedValue.append(character)
            }
            continue
        }
        let escapedCharacter = value[index]
        index = value.index(after: index)
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
    return unescapedValue
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

func createTwitchSegments(text: String,
                          emotes: [ChatMessageEmote],
                          emotesManager: Emotes,
                          id: inout Int) -> [ChatPostSegment]
{
    var segments: [ChatPostSegment] = []
    let unicodeText = text.unicodeScalars
    let unicodeTextCount = unicodeText.count
    var startIndex = unicodeText.startIndex
    var startOffset = 0
    for emote in emotes.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
        guard emote.range.upperBound < unicodeTextCount else {
            break
        }
        guard emote.range.lowerBound >= startOffset else {
            continue
        }
        if emote.range.lowerBound > startOffset {
            let endIndex = unicodeText.index(startIndex, offsetBy: emote.range.lowerBound - startOffset)
            segments += emotesManager.createSegments(
                text: String(unicodeText[startIndex ..< endIndex]),
                id: &id
            )
        }
        if emote.isGif {
            segments.append(ChatPostSegment(id: id, gifUrl: ChatPostUrl(moving: emote.url, still: nil)))
        } else {
            segments.append(ChatPostSegment(
                id: id,
                url: ChatPostUrl(moving: emote.url, still: emote.stillUrl)
            ))
        }
        id += 1
        segments.append(ChatPostSegment(id: id, text: ""))
        id += 1
        startIndex = unicodeText.index(startIndex, offsetBy: emote.range.upperBound + 1 - startOffset)
        startOffset = emote.range.upperBound + 1
    }
    if startIndex < unicodeText.endIndex {
        segments += emotesManager.createSegments(text: String(unicodeText[startIndex...]), id: &id)
    }
    return segments
}

struct TwitchChatMessage {
    let command: TwitchChatCommand
    let parameters: [String]
    var displayName: String?
    var user: String?
    var userId: String?
    var color: String?
    var emotes: [ChatMessageEmote] = []
    var badges: [String] = []
    var messageId: String?
    var id: String?
    var firstMessage: Bool = false
    var subscriber: Bool = false
    var moderator: Bool = false
    var bits: String?
    var replySender: String?
    var replyText: String?
    var targetMessageId: String?
    var targetUserId: String?
    var sourceRoomId: String?

    init(string: String) throws {
        var parts = string.components(separatedBy: .whitespaces)
        if let tagsPart = parts.first, tagsPart.hasPrefix("@") {
            let tagsString = tagsPart[tagsPart.index(after: tagsPart.startIndex)...]
            for tag in tagsString.split(separator: ";") {
                guard let (name, value) = tagNameAndValue(from: tag) else {
                    continue
                }
                switch name {
                case "display-name":
                    displayName = value
                case "user-id":
                    userId = value
                case "login":
                    user = value
                case "color":
                    color = value
                case "emotes":
                    emotes += parseEmotes(from: value)
                case "gifs":
                    if let gif = parseGif(from: value) {
                        emotes.append(gif)
                    }
                case "badges":
                    badges = value.split(separator: ",").map { String($0) }
                case "msg-id":
                    messageId = value
                case "id":
                    id = value
                case "first-msg":
                    firstMessage = value == "1"
                case "subscriber":
                    subscriber = value == "1"
                case "mod":
                    moderator = value == "1"
                case "bits":
                    bits = value
                case "reply-parent-display-name":
                    replySender = value
                case "reply-parent-msg-body":
                    replyText = value
                case "target-msg-id":
                    targetMessageId = value
                case "target-user-id":
                    targetUserId = value
                case "source-room-id":
                    sourceRoomId = value
                default:
                    break
                }
            }
            parts.removeFirst()
        }
        if let sourcePart = parts.first, sourcePart.hasPrefix(":") {
            let source = String(sourcePart.removingPrefix(":"))
            if let senderEndIndex = source.firstIndex(of: "!") {
                user = String(source.prefix(upTo: senderEndIndex))
            }
            parts.removeFirst()
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

    var isGigantifiedEmote: Bool {
        messageId == "gigantified-emote-message"
    }
}

private class Badges: @unchecked Sendable {
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
        badges[badgeId]
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

class Cheermotes: @unchecked Sendable {
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
                self.addCheermotes(datas: datas)
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

    func addCheermotes(datas: [TwitchApiGetCheermotesData]) {
        for data in datas {
            emotes[data.prefix.lowercased()] = data.tiers
        }
    }

    func getUrlAndBits(word: String) -> (URL, Int)? {
        let word = word.lowercased().trim()
        var prefixEndIndex = word.endIndex
        while prefixEndIndex > word.startIndex {
            let index = word.index(before: prefixEndIndex)
            guard word[index].isNumber else {
                return nil
            }
            prefixEndIndex = index
            guard let bits = Int(word[prefixEndIndex...]),
                  let tiers = emotes[String(word[..<prefixEndIndex])],
                  let tier = tiers.reversed().first(where: { bits >= $0.min_bits }),
                  let url = URL(string: tier.images.dark.static_.two)
            else {
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
        highlight: ChatHighlight?,
        sourceChannelIcon: URL?
    )
    func twitchChatDeleteMessage(messageId: String)
    func twitchChatDeleteUser(userId: String)
}

final class TwitchChat: @unchecked Sendable {
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var badges: Badges
    private var cheermotes: Cheermotes
    private var channelName: String
    private weak var delegate: (any TwitchChatDelegate)?
    private var sourceRoomIcons: [String: URL?] = [:]
    private var accessToken: String = ""

    init(delegate: any TwitchChatDelegate) {
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
        self.accessToken = accessToken
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
        createSegments(text: text, emotes: [], emotesManager: emotes, bits: bits)
    }

    func isConnected() -> Bool {
        webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        emotes.isReady()
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
        if let sourceRoomId = message.sourceRoomId, !accessToken.isEmpty {
            if let sourceRoomIcon = sourceRoomIcons[sourceRoomId] {
                processChatMessage(message: message, sourceChannelIcon: sourceRoomIcon)
            } else {
                TwitchApi(accessToken).getUserById(id: sourceRoomId) { user in
                    let sourceRoomIcon: URL? = if let user {
                        URL(string: user.profile_image_url)
                    } else {
                        nil
                    }
                    self.sourceRoomIcons[sourceRoomId] = sourceRoomIcon
                    self.processChatMessage(message: message, sourceChannelIcon: sourceRoomIcon)
                }
            }
        } else {
            processChatMessage(message: message, sourceChannelIcon: nil)
        }
    }

    private func processChatMessage(message: TwitchChatMessage, sourceChannelIcon: URL?) {
        guard message.parameters.count == 2,
              var text = message.parameters.last,
              let displayName = message.displayName,
              let user = message.user
        else {
            return
        }
        var announcement = false
        var firstMessage = false
        var gigantifiedEmote = false
        var subscriber = false
        var moderator = false
        switch message.command {
        case .privateMessage:
            firstMessage = message.firstMessage
            gigantifiedEmote = message.isGigantifiedEmote
            subscriber = message.subscriber
            moderator = message.moderator
        case .userNotice:
            guard message.messageId == "announcement" else {
                return
            }
            announcement = true
        default:
            return
        }
        var badgeUrls: [URL] = []
        for badge in message.badges {
            if let badgeUrl = badges.getUrl(badgeId: badge) {
                badgeUrls.append(badgeUrl)
            }
        }
        let isAction = text.starts(with: "\u{01}ACTION")
        if isAction {
            text = String(text.dropFirst(7))
        }
        let segments = createSegments(
            text: text,
            emotes: message.emotes,
            emotesManager: emotes,
            bits: message.bits
        )
        let highlight = createHighlight(announcement: announcement,
                                        firstMessage: firstMessage,
                                        gigantifiedEmote: gigantifiedEmote,
                                        replySender: message.replySender,
                                        replyText: message.replyText)
        delegate?.twitchChatAppendMessage(
            messageId: message.id,
            displayName: displayName,
            user: user,
            userId: message.userId,
            userColor: RgbColor.fromHex(string: message.color ?? ""),
            userBadges: badgeUrls,
            segments: segments,
            isAction: isAction,
            isSubscriber: subscriber,
            isModerator: moderator,
            bits: message.bits,
            highlight: highlight,
            sourceChannelIcon: sourceChannelIcon
        )
    }

    private func handleClearMessage(message: TwitchChatMessage) {
        guard let targetMessageId = message.targetMessageId else {
            return
        }
        delegate?.twitchChatDeleteMessage(messageId: targetMessageId)
    }

    private func handleClearChat(message: TwitchChatMessage) {
        guard let targetUserId = message.targetUserId else {
            return
        }
        delegate?.twitchChatDeleteUser(userId: targetUserId)
    }

    private func handlePing(message: TwitchChatMessage) {
        webSocket.send(string: "PONG \(message.parameters.joined(separator: " "))")
    }

    private func createHighlight(announcement: Bool,
                                 firstMessage: Bool,
                                 gigantifiedEmote: Bool,
                                 replySender: String?,
                                 replyText: String?) -> ChatHighlight?
    {
        if announcement {
            ChatHighlight.makeAnnouncement()
        } else if firstMessage {
            ChatHighlight.makeFirstMessage()
        } else if gigantifiedEmote {
            ChatHighlight.makeGigantifiedEmote()
        } else if let sender = replySender, let text = replyText {
            ChatHighlight.makeReply(
                user: sender,
                segments: createSegmentsNoTwitchEmotes(text: text, bits: nil)
            )
        } else {
            nil
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

    private func createSegments(text: String,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes,
                                bits: String?) -> [ChatPostSegment]
    {
        var id = 0
        var segments = createTwitchSegments(
            text: text,
            emotes: emotes,
            emotesManager: emotesManager,
            id: &id
        )
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
            newSegments.append(.init(id: id, url: ChatPostUrl(moving: nil, still: url)))
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
