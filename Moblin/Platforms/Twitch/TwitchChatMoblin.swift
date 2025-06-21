import Network
import SwiftUI

private enum MessageError: Error {
    case invalidCommand(String)
    case missingCommand(String)
}

private enum Command: String {
    // connection messages
    case capabilities = "CAP"
    case authenticate = "AUTHENTICATE"
    case password = "PASS"
    case nickname = "NICK"
    case user = "USER"
    case ping = "PING"
    case pong = "PONG"
    case becomeOperator = "OPER"
    case quit = "QUIT"
    case fatalError = "ERROR"

    // channel commands
    case join = "JOIN"
    case part = "PART"
    case topic = "TOPIC"
    case names = "NAMES"
    case list = "LIST"
    case invite = "INVITE"
    case kick = "KICK"

    // server commands
    case messageOfTheDay = "MOTD"
    case version = "VERSION"
    case admin = "ADMIN"
    case connect = "CONNECT"
    case localUsers = "LUSERS"
    case time = "TIME"
    case statistics = "STATS"
    case help = "HELP"
    case information = "INFO"
    case mode = "MODE"

    // messages
    case privateMessage = "PRIVMSG"
    case notice = "NOTICE"
    case roomState = "ROOMSTATE"
    case userNotice = "USERNOTICE"
    case clearChat = "CLEARCHAT"
    case clearMsg = "CLEARMSG"

    // user queries
    case who = "WHO"
    case whois = "WHOIS"

    // operator commands
    case kill = "KILL"
    case rehash = "REHASH"
    case restart = "RESTART"
    case serverQuit = "SQUIT"

    // optional
    case away = "AWAY"
    case userHost = "USERHOST"
    case wallops = "WALLOPS"

    // numerics
    case replyWelcome = "001"
    case replyYourHost = "002"
    case replyCreated = "003"
    case replyMyInfo = "004"
    case replySupportedTokens = "005"
    case replyBounce = "010"
    case replyUserModes = "221"
    case replyLuserClient = "251"
    case replyLuserOperators = "252"
    case replyLuserUnknown = "253"
    case replyLuserChannels = "254"
    case replyLuserMe = "255"
    case replyAdminMe = "256"
    case replyAdminLocationLineOne = "257"
    case replyAdminLocationLineTwo = "258"
    case replyAdminEmail = "259"
    case replyTryAgain = "263"
    case replyLocalUsers = "265"
    case replyGlobalUsers = "266"
    case replyWhoIsCertificateFingerprint = "276"
    case replyNone = "300"
    case replyAway = "301"
    case replyUserHost = "302"
    case replyUnaway = "305"
    case replyNowAway = "306"
    case replyWhoIsRegisteredNickname = "307"
    case replyWhoIsUser = "311"
    case replyWhoIsServer = "312"
    case replyWhoWasUser = "314"
    case replyEndOfWho = "315"
    case replyWhoIsIdle = "317"
    case replyEndOfWhoIs = "318"
    case replyWhoIsChannels = "319"
    case replyWhoIsSpecial = "320"
    case replyListStart = "321"
    case replyList = "322"
    case replyListEnd = "323"
    case replyChannelModeIs = "324"
    case replyCreationTime = "329"
    case replyWhoIsAccount = "330"
    case replyNoTopic = "331"
    case replyTopic = "332"
    case replyTopicWhoTime = "333"
    case replyWhoIsActually = "338"
    case replyInviting = "341"
    case replyInviteList = "346"
    case replyEndOfInviteList = "347"
    case replyExceptList = "348"
    case replyEndOfExceptList = "349"
    case replyVersion = "351"
    case replyWhoReply = "352"
    case replyNames = "353"
    case replyEndOfNames = "366"
    case replyBanList = "367"
    case replyEndOfBanList = "368"
    case replyEndOfWhoWas = "369"
    case replyInfo = "371"
    case replyMessageOfTheDay = "372"
    case replyEndOfInfo = "374"
    case replyMessageOfTheDayStart = "375"
    case replyMessageOfTheDayEnd = "376"
    case replyWhoIsHost = "378"
    case replyWhoIsModes = "379"
    case replyYouAreOperator = "381"
    case replyRehashing = "382"
    case replyTime = "391"
    case errorUnknown = "400"
    case errorNoSuchNickname = "401"
    case errorNoSuchServer = "402"
    case errorNoSuchChannel = "403"
    case errorCannotSendToChannel = "404"
    case errorTooManyChannels = "405"
    case errorNoOrigin = "409"
    case errorInputTooLong = "417"
    case errorUnknownCommand = "421"
    case errorNoMessageOfTheDay = "422"
    case errorDisallowedNickname = "432"
    case errorNicknameInUse = "433"
    case errorUserNotInChannel = "441"
    case errorNotOnChannel = "442"
    case errorUserOnChannel = "443"
    case errorNotRegistered = "451"
    case errorNeedMoreParameters = "461"
    case errorAlreadyRegistered = "462"
    case errorPasswordMismatch = "464"
    case errorYouAreBanned = "465"
    case errorChannelIsFull = "471"
    case errorUnknownMode = "472"
    case errorInviteOnlyChannel = "473"
    case errorBannedFromChannel = "474"
    case errorBadChannelKey = "475"
    case errorBadChannelMask = "476"
    case errorNoPrivileges = "481"
    case errorChannelPrivilegesNeeded = "482"
    case errorCannotKillServer = "483"
    case errorCannotBecomeOperatorFromHost = "491"
    case errorUnknownModeFlag = "501"
    case errorUsersDoNotMatch = "502"
    case errorHelpNotFound = "524"
    case errorInvalidKey = "525"
    case replyStartTLS = "670"
    case replyWhoIsSecure = "671"
    case errorStartTLS = "691"
    case errorInvalidModeParameter = "696"
    case replyHelpStart = "704"
    case replyHelpText = "705"
    case replyHelpEnd = "706"
    case errorInsufficientPrivileges = "723"
    case replyLoggedIn = "900"
    case replyLoggedOut = "901"
    case errorNicknameLocked = "902"
    case replySASLSuccess = "903"
    case errorSASLFailure = "904"
    case errorSASLTooLong = "905"
    case errorSASLAborted = "906"
    case errorSASLAlready = "907"
    case replySASLMechanics = "908"
}

extension StringProtocol where Self: RangeReplaceableCollection {
    func removingPrefix(_ prefix: String) -> Self {
        guard hasPrefix(prefix) else { return self }
        var copy = self
        copy.removeFirst(prefix.count)
        return copy
    }

    mutating func append(_ value: Self?) {
        guard let value = value else { return }
        append(contentsOf: value)
    }
}

private struct Emote2 {
    private let identifier: String
    let range: ClosedRange<Int>

    var imageURL: URL {
        get throws {
            guard let url = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(identifier)/default/dark/3.0")
            else {
                throw EmoteError.invalidImageURL
            }
            return url
        }
    }

    static func emotes(from string: String) -> [Emote2] {
        let emoteDefinitions = string.split(separator: "/")
        return emoteDefinitions.flatMap { emotes(fromDefinition: $0) }
    }

    private static func emotes(fromDefinition definition: Substring) -> [Emote2] {
        let parts = definition.split(separator: ":")
        guard parts.count == 2, let emoteID = parts.first, let emoteRangesString = parts.last else { return [] }
        let emoteRanges = emoteRangesString.split(separator: ",").compactMap { emoteRangeString -> ClosedRange<Int>? in
            let rangeIndexStrings = emoteRangeString.split(separator: "-")
            guard rangeIndexStrings.count == 2,
                  let rangeStartIndexString = rangeIndexStrings.first,
                  let rangeEndIndexString = rangeIndexStrings.last,
                  let rangeStartIndex = Int(rangeStartIndexString),
                  let rangeEndIndex = Int(rangeEndIndexString)
            else { return nil }
            return rangeStartIndex ... rangeEndIndex
        }
        return emoteRanges.map { Emote2(identifier: String(emoteID), range: $0) }
    }
}

private enum EmoteError: Error {
    case invalidImageURL
}

private struct ChatMessage {
    let id: String?
    let channel: String
    let emotes: [Emote2]
    let badges: [String]
    let sender: String
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

    init?(_ message: Message) {
        guard message.parameters.count == 2,
              let channel = message.parameters.first,
              let text = message.parameters.last,
              let sender = message.sender
        else { return nil }

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
        self.channel = channel
        emotes = message.emotes
        badges = message.badges
        self.text = text
        self.sender = sender
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
}

private enum MessageTagStringParser {
    static func tags(from string: String) -> [String: String] {
        let tagsString = string.removingPrefix("@")
        let tagSpecifiers = tagsString.split(separator: ";")
        let tagPairs = tagSpecifiers.compactMap { Self.tagKeyAndValue(from: $0) }
        return [String: String](tagPairs, uniquingKeysWith: { key, _ in key })
    }

    private static func tagKeyAndValue(from specifier: Substring) -> (String, String)? {
        let parts = specifier.split(separator: "=")
        guard parts.count == 2, let keyPart = parts.first, let valuePart = parts.last else { return nil }

        // values must not be empty
        guard valuePart.isEmpty == false else { return nil }

        // unescaping value
        var unescapedValue = ""
        let scanner = Scanner(string: String(valuePart))
        while scanner.isAtEnd == false {
            unescapedValue.append(scanner.scanUpToString("\\"))
            _ = scanner.scanString("\\")

            if let escapedCharacter = scanner.scanCharacter() {
                switch escapedCharacter {
                case ":": unescapedValue.append(";")
                case "s": unescapedValue.append(" ")
                case "r": unescapedValue.append("\r")
                case "n": unescapedValue.append("\n")
                default: unescapedValue.append(escapedCharacter)
                }
            }
        }

        return (String(keyPart), unescapedValue)
    }
}

private struct Message {
    let tags: [String: String]
    let sourceString: String?
    let command: Command
    let parameters: [String]

    init(string: String) throws {
        var parts = string.components(separatedBy: .whitespaces)

        if let tagsPart = parts.first, tagsPart.hasPrefix("@") {
            tags = MessageTagStringParser.tags(from: tagsPart)
            parts.removeFirst()
        } else { tags = [:] }

        if let sourcePart = parts.first, sourcePart.hasPrefix(":") {
            sourceString = String(sourcePart.removingPrefix(":"))
            parts.removeFirst()
        } else { sourceString = nil }

        guard let commandPart = parts.first else { throw MessageError.missingCommand(string) }
        let commandString = String(commandPart)
        guard let command = Command(rawValue: commandString) else {
            throw MessageError.invalidCommand(commandString)
        }
        self.command = command
        parts.removeFirst()

        parameters = Self.parameters(from: parts)
    }

    private static func parameters(from parts: [String]) -> [String] {
        var parameters = [String]()
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

    var sender: String? {
        if let displayName = tags["display-name"] {
            return displayName
        } else if let source = sourceString,
                  let senderEndIndex = source.firstIndex(of: "!")
        {
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

    var emotes: [Emote2] {
        guard let emoteString = tags["emotes"] else { return [] }
        return Emote2.emotes(from: emoteString)
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

private class Badges {
    private var channelId: String = ""
    private var accessToken: String = ""
    private var urlSession = URLSession.shared
    private var badges: [String: TwitchApiChatBadgesVersion] = [:]
    private var tryFetchAgainTimer = SimpleTimer(queue: .main)

    func start(channelId: String, accessToken: String, urlSession: URLSession) {
        self.channelId = channelId
        self.accessToken = accessToken
        self.urlSession = urlSession
        guard !accessToken.isEmpty else {
            return
        }
        tryFetch()
    }

    func stop() {
        stopTryFetchAgainTimer()
    }

    func getUrl(badgeId: String) -> String? {
        return badges[badgeId]?.image_url_2x
    }

    func tryFetch() {
        startTryFetchAgainTimer()
        TwitchApi(accessToken, urlSession).getGlobalChatBadges { data in
            guard let data else {
                return
            }
            DispatchQueue.main.async {
                self.addBadges(badges: data)
                TwitchApi(self.accessToken, self.urlSession)
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
                self.badges["\(badge.set_id)/\(version.id)"] = version
            }
        }
    }
}

private class Cheermotes {
    private var channelId: String = ""
    private var accessToken: String = ""
    private var urlSession: URLSession = .shared
    private var emotes: [String: [TwitchApiGetCheermotesDataTier]] = [:]
    private var tryFetchAgainTimer = SimpleTimer(queue: .main)

    func start(channelId: String, accessToken: String, urlSession: URLSession) {
        self.channelId = channelId
        self.accessToken = accessToken
        self.urlSession = urlSession
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
        TwitchApi(accessToken, urlSession).getCheermotes(broadcasterId: channelId) { datas in
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

protocol TwitchChatMoblinDelegate: AnyObject {
    func twitchChatMoblinMakeErrorToast(title: String, subTitle: String?)
    func twitchChatMoblinAppendMessage(
        messageId: String?,
        user: String?,
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
    func twitchChatMoblinDeleteMessage(messageId: String)
}

final class TwitchChatMoblin {
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var badges: Badges
    private var cheermotes: Cheermotes
    private var channelName: String
    private weak var delegate: (any TwitchChatMoblinDelegate)?

    init(delegate: TwitchChatMoblinDelegate) {
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
        accessToken: String,
        httpProxy: HttpProxy?,
        urlSession: URLSession
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
        badges.start(channelId: channelId, accessToken: accessToken, urlSession: urlSession)
        cheermotes.start(channelId: channelId, accessToken: accessToken, urlSession: urlSession)
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!, httpProxy: httpProxy)
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

    private func handleMessage(message: String) throws {
        let message = try Message(string: message)
        switch message.command {
        case .privateMessage, .userNotice:
            if let chatMessage = ChatMessage(message) {
                try handleChatMessage(message: chatMessage)
            }
        case .clearMsg:
            try handleClearMessage(message: message)
        case .ping:
            webSocket.send(string: "PONG \(message.parameters.joined(separator: " "))")
        default:
            break
        }
    }

    private func handleChatMessage(message: ChatMessage) throws {
        let emotes = getEmotes(from: message)
        var badgeUrls: [URL] = []
        for badge in message.badges {
            if let badgeUrl = badges.getUrl(badgeId: badge), let badgeUrl = URL(string: badgeUrl) {
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
            emotes: emotes,
            emotesManager: self.emotes,
            bits: message.bits
        )
        delegate?.twitchChatMoblinAppendMessage(
            messageId: message.id,
            user: message.sender,
            userId: message.userId,
            userColor: RgbColor.fromHex(string: message.senderColor ?? ""),
            userBadges: badgeUrls,
            segments: segments,
            isAction: isAction,
            isSubscriber: message.subscriber,
            isModerator: message.moderator,
            bits: message.bits,
            highlight: createHighlight(message: message, emotes: emotes)
        )
    }

    private func handleClearMessage(message: Message) throws {
        guard let targetMessageId = message.tags["target-msg-id"] else {
            return
        }
        delegate?.twitchChatMoblinDeleteMessage(messageId: targetMessageId)
    }

    func createSegmentsNoTwitchEmotes(text: String, bits: String?) -> [ChatPostSegment] {
        return createSegments(text: text, emotes: [], emotesManager: emotes, bits: bits)
    }

    private func createHighlight(message: ChatMessage, emotes: [ChatMessageEmote]) -> ChatHighlight? {
        if message.announcement {
            return .init(
                kind: .other,
                color: .green,
                image: "horn.blast",
                title: String(localized: "Announcement")
            )
        } else if message.firstMessage {
            return .init(
                kind: .firstMessage,
                color: .yellow,
                image: "bubble.left",
                title: String(localized: "First time chatter")
            )
        } else if let sender = message.replySender, let text = message.replyText {
            var title = "Replying to \(sender):"
            for segment in createSegments(text: text, emotes: emotes, emotesManager: self.emotes, bits: nil) {
                if let text = segment.text {
                    title += " \(text.trim())"
                }
            }
            return ChatHighlight(kind: .reply, color: .gray, image: "arrowshape.turn.up.left", title: title)
        } else {
            return nil
        }
    }

    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.delegate?.twitchChatMoblinMakeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleOk(title: String) {
        DispatchQueue.main.async {
            self.delegate?.twitchChatMoblinMakeErrorToast(title: title, subTitle: nil)
        }
    }

    private func createTwitchSegments(text: String,
                                      emotes: [ChatMessageEmote],
                                      id: inout Int) -> [ChatPostSegment]
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
            for word in String(unicodeText[startIndex...]).split(separator: " ") {
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

extension ChatMessage {
    func isAction() -> Bool {
        return text.starts(with: "\u{01}ACTION")
    }
}

extension TwitchChatMoblin: WebSocketClientDelegate {
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
