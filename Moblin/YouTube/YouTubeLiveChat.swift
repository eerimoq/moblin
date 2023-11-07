import Foundation

private struct Snippet: Codable {
    var authorChannelId: String
    var displayMessage: String
}

private struct Item: Codable {
    var snippet: Snippet
}

private struct Messages: Codable {
    var pollingIntervalMillis: UInt64
    var nextPageToken: String
    var items: [Item]
}

final class YouTubeLiveChat: NSObject {
    private var model: Model
    private var apiKey: String
    private var liveChatId: String
    private var nextToken: String?
    private var task: Task<Void, Error>?
    private var emotes: Emotes

    init(model: Model, apiKey: String, liveChatId: String) {
        self.model = model
        self.apiKey = apiKey
        self.liveChatId = liveChatId
        emotes = Emotes()
    }

    private func makeUrl() -> URL? {
        var url = """
        https://www.googleapis.com/youtube/v3/liveChat/messages\
        ?part=id,snippet&key=\(apiKey)&liveChatId=\(liveChatId)
        """
        if let nextToken {
            url += "&pageToken=\(nextToken)"
        }
        return URL(string: url)
    }

    func start() {
        task = Task.init {
            var pollingIntervalMillis: UInt64 = 1000
            do {
                while true {
                    guard let url = makeUrl() else {
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
                            await MainActor.run {
                                self.model.appendChatMessage(
                                    user: item.snippet.authorChannelId,
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
