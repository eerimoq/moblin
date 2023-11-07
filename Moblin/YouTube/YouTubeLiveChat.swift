import Foundation

private struct MessagesSnippet: Codable {
    var authorChannelId: String
    var displayMessage: String
}

private struct MessagesItem: Codable {
    var snippet: MessagesSnippet
}

private struct Messages: Codable {
    var pollingIntervalMillis: UInt64
    var nextPageToken: String
    var items: [MessagesItem]
}

private struct ChannelSnippet: Codable {
    var title: String
}

private struct ChannelItem: Codable {
    var snippet: ChannelSnippet
}

private struct Channel: Codable {
    var items: [ChannelItem]
}

final class YouTubeLiveChat: NSObject {
    private var model: Model
    private var apiKey: String
    private var liveChatId: String
    private var nextToken: String?
    private var task: Task<Void, Error>?
    private var emotes: Emotes
    private var channelToTitle: [String: String] = [:]

    init(model: Model, apiKey: String, liveChatId: String) {
        self.model = model
        self.apiKey = apiKey
        self.liveChatId = liveChatId
        emotes = Emotes()
    }

    private func makeMessagesUrl() -> URL? {
        var url = """
        https://www.googleapis.com/youtube/v3/liveChat/messages\
        ?part=id,snippet&key=\(apiKey)&liveChatId=\(liveChatId)
        """
        if let nextToken {
            url += "&pageToken=\(nextToken)"
        }
        return URL(string: url)
    }

    private func makeChannelsUrl(channelId: String) -> URL? {
        return URL(string: """
        https://www.googleapis.com/youtube/v3/channels\
        ?part=snippet&key=\(apiKey)&id=\(channelId)
        """)
    }

    private func getChannelTitle(channelId: String) async throws -> String {
        if let title = channelToTitle[channelId] {
            return title
        }
        guard let url = makeChannelsUrl(channelId: channelId) else {
            return "???"
        }
        let (data, response) = try await httpGet(from: url)
        if response.isSuccessful {
            let channel = try JSONDecoder().decode(Channel.self, from: data)
            if channel.items.count != 1 {
                return "???"
            }
            channelToTitle[channelId] = channel.items[0].snippet.title
            return channel.items[0].snippet.title
        }
        return "???"
    }

    func start() {
        task = Task.init {
            var pollingIntervalMillis: UInt64 = 1000
            do {
                while true {
                    guard let url = makeMessagesUrl() else {
                        break
                    }
                    let (data, response) = try await httpGet(from: url)
                    if response.isSuccessful {
                        let messages = try JSONDecoder().decode(Messages.self, from: data)
                        pollingIntervalMillis = messages.pollingIntervalMillis
                        nextToken = messages.nextPageToken
                        for item in messages.items {
                            let segments = createSegments(message: item.snippet
                                .displayMessage)
                            let user = try await getChannelTitle(channelId: item.snippet
                                .authorChannelId)
                            await MainActor.run {
                                self.model.appendChatMessage(
                                    user: user,
                                    userColor: nil,
                                    segments: segments,
                                    timestamp: model.digitalClock
                                )
                            }
                        }
                    }
                    try await Task.sleep(nanoseconds: pollingIntervalMillis * 1_000_000)
                }
            } catch {
                logger.info("YouTube chat ended with error \(error)")
            }
            logger.info("YouTube chat ended")
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func createSegments(message: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        for word in message.components(separatedBy: .whitespaces) {
            segments.append(ChatPostSegment(text: "\(word) "))
        }
        return segments
    }
}
