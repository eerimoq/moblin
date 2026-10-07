import Foundation

private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:124.0) Gecko/20100101 Firefox/124.0"

func fetchYouTubeVideoId(handle: String) async throws -> String {
    guard let url = URL(string: "https://www.youtube.com/\(handle)/live") else {
        throw "Cannot create URL"
    }
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("CONSENT=YES+1", forHTTPHeaderField: "Cookie")
    let (data, response) = try await httpGet(request: request)
    if !response.isSuccessful {
        throw "Not successful"
    }
    guard let html = String(data: data, encoding: .utf8) else {
        throw "Not html"
    }
    guard let videoId = parseYouTubeVideoId(html: html) else {
        throw "Video id not found"
    }
    return videoId
}

private let minimumPollDelayMs = 200
private let maximumPollDelayMs = 3000

func parseYouTubeVideoId(html: String) -> String? {
    let patterns = [
        /<link rel="shortlinkUrl" href="https:\/\/youtu\.be\/([^"]+)"/,
        /<link rel='shortlinkUrl' href='https:\/\/youtu\.be\/([^']+)'/,
        /shortlinkUrl[^>]*href=[\"\']https:\/\/youtu\.be\/([^\"\']+)/,
    ]
    for pattern in patterns {
        if let match = try? pattern.firstMatch(in: html) {
            return String(match.1)
        }
    }
    return nil
}

func parseYouTubeInitialContinuation(body: String) -> String? {
    let continuationRegex = /"continuation":"([^"]+)"/
    guard let match = try? continuationRegex.firstMatch(in: body) else {
        return nil
    }
    return String(match.1)
}

func youTubePollDelayMs(delay: Int, numberOfMessages: Int) -> Int {
    let delay = numberOfMessages > 0 ? delay * 5 / numberOfMessages : maximumPollDelayMs
    return min(max(delay, minimumPollDelayMs), maximumPollDelayMs)
}

private func createPaidMessageText(chatDescription: ChatDescription) -> String {
    if let amount = chatDescription.purchaseAmountText?.simpleText {
        String(localized: "sent a \(amount) Super Chat!")
    } else {
        String(localized: "sent a Super Chat!")
    }
}

private func createPaidStickerText(chatDescription: ChatDescription) -> String {
    if let amount = chatDescription.purchaseAmountText?.simpleText {
        String(localized: "sent a \(amount) Super Sticker!")
    } else {
        String(localized: "sent a Super Sticker!")
    }
}

private struct InvalidationContinuationData: Codable {
    let continuation: String
}

private struct Continuations: Codable {
    let invalidationContinuationData: InvalidationContinuationData
}

private struct Thumbnail: Codable {
    let url: String
}

private struct Image: Codable {
    let thumbnails: [Thumbnail]
}

private struct Emoji: Codable {
    let image: Image
}

private struct Run: Codable {
    let text: String?
    let emoji: Emoji?
}

private struct Message: Codable {
    let runs: [Run]
}

private struct Author: Codable {
    let simpleText: String
}

private struct Amount: Codable {
    let simpleText: String
}

private struct BadgeIcon: Codable {
    let iconType: String?
}

private struct AuthorBadgeRenderer: Codable {
    let icon: BadgeIcon?
}

private struct AuthorBadge: Codable {
    let liveChatAuthorBadgeRenderer: AuthorBadgeRenderer?
}

private struct ChatDescription: Codable {
    let authorName: Author
    let authorExternalChannelId: String?
    let message: Message?
    let purchaseAmountText: Amount?
    let headerSubtext: Message?
    let authorBadges: [AuthorBadge]?
}

private struct SponsorshipsHeaderRenderer: Codable {
    let authorName: Author
    let authorExternalChannelId: String?
    let primaryText: Message?
    let authorBadges: [AuthorBadge]?
}

private func getUserRoles(authorBadges: [AuthorBadge]?) -> (Bool, Bool) {
    var isOwner = false
    var isModerator = false
    if let authorBadges {
        for authorBadge in authorBadges {
            let iconType = authorBadge.liveChatAuthorBadgeRenderer?.icon?.iconType
            switch iconType {
            case "OWNER":
                isOwner = true
            case "MODERATOR":
                isModerator = true
            default:
                break
            }
        }
    }
    return (isOwner, isModerator)
}

private struct SponsorshipsHeader: Codable {
    let liveChatSponsorshipsHeaderRenderer: SponsorshipsHeaderRenderer?
}

private struct GiftPurchaseAnnouncementDescription: Codable {
    let header: SponsorshipsHeader?
}

private struct Content: Codable {
    let content: String
}

private struct GiftMessageVieModel: Codable {
    let authorName: Content
    let text: Content
}

private struct AddChatItemActionItem: Codable {
    let liveChatTextMessageRenderer: ChatDescription?
    let liveChatPaidMessageRenderer: ChatDescription?
    let liveChatPaidStickerRenderer: ChatDescription?
    let liveChatMembershipItemRenderer: ChatDescription?
    let liveChatSponsorshipsGiftPurchaseAnnouncementRenderer: GiftPurchaseAnnouncementDescription?
    let liveChatSponsorshipsGiftRedemptionAnnouncementRenderer: ChatDescription?
    let giftMessageViewModel: GiftMessageVieModel?
}

private struct AddChatItemAction: Codable {
    let item: AddChatItemActionItem
}

private struct Action: Codable {
    let addChatItemAction: AddChatItemAction?
}

private struct LiveChatContinuation: Codable {
    let continuations: [Continuations]
    let actions: [Action]?
}

private struct ContinuationContents: Codable {
    let liveChatContinuation: LiveChatContinuation
}

private struct GetLiveChat: Codable {
    let continuationContents: ContinuationContents
}

struct YouTubeChatMessage {
    let user: String
    let userId: String?
    let segments: [ChatPostSegment]
    let isOwner: Bool
    let isModerator: Bool
    let highlight: ChatHighlight?
}

struct YouTubeGetLiveChatResponse {
    let messages: [YouTubeChatMessage]
    let continuation: String?
}

func parseYouTubeGetLiveChat(data: Data, emotes: Emotes) throws -> YouTubeGetLiveChatResponse {
    let getLiveChat = try JSONDecoder().decode(GetLiveChat.self, from: data)
    let liveChatContinuation = getLiveChat.continuationContents.liveChatContinuation
    var messages: [YouTubeChatMessage] = []
    for action in liveChatContinuation.actions ?? [] {
        guard let item = action.addChatItemAction?.item else {
            continue
        }
        messages += parseChatItem(item: item, emotes: emotes)
    }
    return YouTubeGetLiveChatResponse(
        messages: messages,
        continuation: liveChatContinuation.continuations.first?.invalidationContinuationData.continuation
    )
}

private func parseChatItem(item: AddChatItemActionItem, emotes: Emotes) -> [YouTubeChatMessage] {
    var messages: [YouTubeChatMessage?] = []
    if let chatDescription = item.liveChatTextMessageRenderer {
        messages.append(parseChatDescription(chatDescription: chatDescription,
                                             highlight: nil,
                                             emotes: emotes))
    }
    if let chatDescription = item.liveChatPaidMessageRenderer {
        messages.append(parseChatDescription(
            chatDescription: chatDescription,
            text: createPaidMessageText(chatDescription: chatDescription),
            highlight: ChatHighlight.makePaidMessage(),
            emotes: emotes
        ))
    }
    if let chatDescription = item.liveChatPaidStickerRenderer {
        messages.append(parseChatDescription(
            chatDescription: chatDescription,
            text: createPaidStickerText(chatDescription: chatDescription),
            highlight: ChatHighlight.makePaidSticker(),
            emotes: emotes
        ))
    }
    if let chatDescription = item.liveChatMembershipItemRenderer {
        messages.append(parseChatDescription(chatDescription: chatDescription,
                                             highlight: ChatHighlight.makeMember(),
                                             emotes: emotes))
    }
    if let giftPurchase = item.liveChatSponsorshipsGiftPurchaseAnnouncementRenderer,
       let headerRenderer = giftPurchase.header?.liveChatSponsorshipsHeaderRenderer
    {
        messages.append(parseGiftPurchase(headerRenderer: headerRenderer, emotes: emotes))
    }
    if let chatDescription = item.liveChatSponsorshipsGiftRedemptionAnnouncementRenderer {
        messages.append(parseChatDescription(chatDescription: chatDescription,
                                             highlight: ChatHighlight.makeGiftedMemberships(),
                                             emotes: emotes))
    }
    if let giftMessageViewModel = item.giftMessageViewModel {
        var id = 0
        messages.append(YouTubeChatMessage(
            user: giftMessageViewModel.authorName.content,
            userId: nil,
            segments: emotes.createSegments(text: giftMessageViewModel.text.content, id: &id),
            isOwner: false,
            isModerator: false,
            highlight: ChatHighlight.makeJewels()
        ))
    }
    return messages.compactMap { $0 }
}

private func createRunsSegments(runs: [Run], emotes: Emotes, id: inout Int) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for run in runs {
        if let text = run.text {
            segments += emotes.createSegments(text: text, id: &id)
        }
        if let emojiUrl = run.emoji?.image.thumbnails.first?.url, let url = URL(string: emojiUrl) {
            segments.append(.init(id: id, url: ChatPostUrl(moving: url, still: url)))
            id += 1
        }
    }
    return segments
}

private func parseChatDescription(chatDescription: ChatDescription,
                                  text: String? = nil,
                                  highlight: ChatHighlight?,
                                  emotes: Emotes) -> YouTubeChatMessage?
{
    var id = 0
    var segments: [ChatPostSegment] = []
    if let text {
        segments += emotes.createSegments(text: text, id: &id)
    }
    if let headerSubtext = chatDescription.headerSubtext {
        segments += createRunsSegments(runs: headerSubtext.runs, emotes: emotes, id: &id)
    }
    if let message = chatDescription.message {
        segments += createRunsSegments(runs: message.runs, emotes: emotes, id: &id)
    }
    guard !segments.isEmpty || highlight != nil else {
        return nil
    }
    let (isOwner, isModerator) = getUserRoles(authorBadges: chatDescription.authorBadges)
    return YouTubeChatMessage(user: chatDescription.authorName.simpleText,
                              userId: chatDescription.authorExternalChannelId,
                              segments: segments,
                              isOwner: isOwner,
                              isModerator: isModerator,
                              highlight: highlight)
}

private func parseGiftPurchase(headerRenderer: SponsorshipsHeaderRenderer,
                               emotes: Emotes) -> YouTubeChatMessage?
{
    var id = 0
    var segments: [ChatPostSegment] = []
    for run in headerRenderer.primaryText?.runs ?? [] {
        if let text = run.text {
            segments += emotes.createSegments(text: text, id: &id)
        }
    }
    guard !segments.isEmpty else {
        return nil
    }
    let (isOwner, isModerator) = getUserRoles(authorBadges: headerRenderer.authorBadges)
    return YouTubeChatMessage(user: headerRenderer.authorName.simpleText,
                              userId: headerRenderer.authorExternalChannelId,
                              segments: segments,
                              isOwner: isOwner,
                              isModerator: isModerator,
                              highlight: ChatHighlight.makeGiftedMemberships())
}

@MainActor
final class YouTubeLiveChat: NSObject {
    private var model: Model
    private var videoId: String
    private var task: Task<Void, any Error>?
    private var emotes: Emotes
    private var settings: SettingsStreamChat
    private var connected: Bool = false
    private var continuation: String = ""
    private var delay = 2000

    init(model: Model, videoId: String, settings: SettingsStreamChat) {
        self.model = model
        self.videoId = videoId
        self.settings = settings.clone()
        emotes = Emotes()
    }

    func start() {
        emotes.start(
            platform: .youtube,
            channelId: videoId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        task = Task {
            while true {
                do {
                    try await getInitialContinuation()
                    connected = true
                    try await readMessages()
                } catch {}
                connected = false
                if Task.isCancelled {
                    break
                }
                try await sleep(seconds: 5)
            }
        }
    }

    func stop() {
        emotes.stop()
        task?.cancel()
        task = nil
        connected = false
    }

    func isConnected() -> Bool {
        connected
    }

    func hasEmotes() -> Bool {
        emotes.isReady()
    }

    private func handleError(title: String, subTitle: String) {
        model.makeErrorToast(title: title, subTitle: subTitle)
    }

    private func handleOk(title: String) {
        model.makeToast(title: title)
    }

    private func makeLiveChatUrl() -> URL? {
        URL(string: "https://www.youtube.com/live_chat?is_popout=1&v=\(videoId)")
    }

    private func makeGetLiveChatUrl() -> URL? {
        URL(string: "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?prettyPrint=false")
    }

    private func getInitialContinuation() async throws {
        guard let url = makeLiveChatUrl() else {
            throw "Failed to create URL"
        }
        let (data, response) = try await fetch(from: url)
        if !response.isSuccessful {
            throw "Unsuccessful HTTP response"
        }
        guard let body = String(bytes: data, encoding: .utf8) else {
            throw "Not UTF-8 body"
        }
        guard let continuation = parseYouTubeInitialContinuation(body: body) else {
            throw "No continuation"
        }
        self.continuation = continuation
    }

    private func readMessages() async throws {
        guard let url = makeGetLiveChatUrl() else {
            throw "Failed to create URL"
        }
        while true {
            let (data, response) = try await upload(from: url, data: makeGetLiveChatBody())
            if !response.isSuccessful {
                throw "Unsuccessful HTTP response"
            }
            let getLiveChat = try parseYouTubeGetLiveChat(data: data, emotes: emotes)
            for message in getLiveChat.messages {
                appendMessage(message: message)
            }
            guard let continuation = getLiveChat.continuation else {
                throw "Continuation missing"
            }
            self.continuation = continuation
            delay = youTubePollDelayMs(delay: delay, numberOfMessages: getLiveChat.messages.count)
            try await sleep(milliSeconds: delay)
        }
    }

    private func appendMessage(message: YouTubeChatMessage) {
        model.appendChatMessage(platform: .youTube,
                                messageId: nil,
                                displayName: message.user,
                                user: message.user,
                                userId: message.userId,
                                userColor: nil,
                                userBadges: [],
                                segments: message.segments,
                                timestamp: model.statusOther.digitalClock,
                                timestampTime: .now,
                                isAction: false,
                                isSubscriber: false,
                                isModerator: message.isModerator,
                                isOwner: message.isOwner,
                                bits: nil,
                                highlight: message.highlight,
                                live: true)
    }

    private func makeGetLiveChatBody() -> Data {
        """
        {
            "context": {
                "client": {
                    "clientName": "WEB",
                    "clientVersion": "2.20210128.02.00"
                }
            },
            "continuation": "\(continuation)"
        }
        """.utf8Data
    }

    private func fetch(from: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: from)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await httpUrlSession().data(for: request)
        if let response = response.http {
            return (data, response)
        } else {
            throw "Not an HTTP response"
        }
    }

    private func upload(from: URL, data: Data) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: from)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setContentType("application/json")
        let (data, response) = try await httpUrlSession().upload(for: request, from: data)
        if let response = response.http {
            return (data, response)
        } else {
            throw "Not an HTTP response"
        }
    }
}
