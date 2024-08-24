import Foundation

private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:124.0) Gecko/20100101 Firefox/124.0"
private let minimumPollDelayMs = 200
private let maximumPollDelayMs = 3000

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

// private struct Amount: Codable {
//     let simpleText: String
// }

private struct ChatDescription: Codable {
    let authorName: Author
    let message: Message?
    // let purchaseAmountText: Amount?
}

private struct AddChatItemActionItem: Codable {
    let liveChatTextMessageRenderer: ChatDescription?
    let liveChatPaidMessageRenderer: ChatDescription?
    let liveChatPaidStickerRenderer: ChatDescription?
    let liveChatMembershipItemRenderer: ChatDescription?
    // let liveChatSponsorshipsGiftPurchaseAnnouncementRenderer: ?
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

final class YouTubeLiveChat: NSObject {
    private var model: Model
    private var videoId: String
    private var task: Task<Void, Error>?
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
        task = Task.init {
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

    private func makeLiveChatUrl() -> URL? {
        return URL(string: "https://www.youtube.com/live_chat?is_popout=1&v=\(videoId)")
    }

    private func makeGetLiveChatUrl() -> URL? {
        return URL(string: "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat")
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
        let re_continuation = /"continuation":"([^"]+)"/
        guard let match = try re_continuation.firstMatch(in: body) else {
            throw "No continuation"
        }
        continuation = String(match.1)
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
            var numberOfMessages = 0
            let getLiveChat = try JSONDecoder().decode(GetLiveChat.self, from: data)
            if let actions = getLiveChat.continuationContents.liveChatContinuation.actions {
                for action in actions {
                    guard let item = action.addChatItemAction?.item else {
                        continue
                    }
                    if let chatDescription = item.liveChatTextMessageRenderer {
                        numberOfMessages += await handleChatDescription(chatDescription: chatDescription)
                    }
                    if let chatDescription = item.liveChatPaidMessageRenderer {
                        numberOfMessages += await handleChatDescription(chatDescription: chatDescription)
                    }
                    if let chatDescription = item.liveChatPaidStickerRenderer {
                        numberOfMessages += await handleChatDescription(chatDescription: chatDescription)
                    }
                    if let chatDescription = item.liveChatMembershipItemRenderer {
                        numberOfMessages += await handleChatDescription(chatDescription: chatDescription)
                    }
                }
            }
            try updateContinuation(getLiveChat: getLiveChat)
            updateDelayMs(numberOfMessages: numberOfMessages)
            try await sleep(milliSeconds: delay)
        }
    }

    private func updateDelayMs(numberOfMessages: Int) {
        if numberOfMessages > 0 {
            delay = delay * 5 / numberOfMessages
        } else {
            delay = maximumPollDelayMs
        }

        if delay > maximumPollDelayMs {
            delay = maximumPollDelayMs
        }

        if delay < minimumPollDelayMs {
            delay = minimumPollDelayMs
        }
    }

    private func handleChatDescription(chatDescription: ChatDescription) async -> Int {
        guard let message = chatDescription.message else {
            return 0
        }
        var segments: [ChatPostSegment] = []
        for run in message.runs {
            if let text = run.text {
                segments += createSegments(message: text)
            }
            if let emojiUrl = run.emoji?.image.thumbnails.first?.url {
                segments.append(.init(url: URL(string: emojiUrl)))
            }
        }
        guard !segments.isEmpty else {
            return 0
        }
        let nonMutSegments = segments
        await MainActor.run {
            model.appendChatMessage(platform: .youTube,
                                    user: chatDescription.authorName.simpleText,
                                    userColor: nil,
                                    segments: nonMutSegments,
                                    timestamp: model.digitalClock,
                                    timestampTime: .now,
                                    isAction: false,
                                    isSubscriber: false,
                                    isModerator: false,
                                    highlight: nil)
        }
        return 1
    }

    private func updateContinuation(getLiveChat: GetLiveChat) throws {
        guard let continuation = getLiveChat.continuationContents.liveChatContinuation.continuations.first
        else {
            throw "Continuation missing"
        }
        self.continuation = continuation.invalidationContinuationData.continuation
    }

    private func makeGetLiveChatBody() -> Data {
        return """
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

    private func createSegments(message: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        for var segment in makeChatPostTextSegments(text: message) {
            if let text = segment.text {
                segments += emotes.createSegments(text: text)
                segment.text = nil
            }
            segments.append(segment)
        }
        return segments
    }

    private func fetch(from: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: from)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, from: data)
        if let response = response.http {
            return (data, response)
        } else {
            throw "Not an HTTP response"
        }
    }
}
