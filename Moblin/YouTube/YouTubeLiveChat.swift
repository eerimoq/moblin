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

private struct VideosLiveStreamingDetails: Codable {
    var activeLiveChatId: String?
}

private struct VideosItem: Codable {
    var liveStreamingDetails: VideosLiveStreamingDetails
}

private struct Videos: Codable {
    var items: [VideosItem]
}

private let unknownUser = "Unknown"
private let minimumPollingIntervalMillis: UInt64 = 500

final class YouTubeLiveChat: NSObject {
    private var model: Model
    private var apiKey: String
    private var videoId: String
    private var liveChatId: String?
    private var nextToken: String?
    private var task: Task<Void, Error>?
    private var emotes: Emotes
    private var settings: SettingsStreamChat
    private var channelToTitle: [String: String] = [:]
    private var pollingIntervalMillis: UInt64 = minimumPollingIntervalMillis
    private var connected: Bool = false

    init(model: Model, apiKey: String, videoId: String, settings: SettingsStreamChat) {
        self.model = model
        self.apiKey = apiKey
        self.videoId = videoId
        self.settings = settings.clone()
        emotes = Emotes()
    }

    func start() {
        nextToken = nil
        pollingIntervalMillis = minimumPollingIntervalMillis
        emotes.start(
            platform: .youtube,
            channelId: videoId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        task = Task.init {
            while true {
                if liveChatId == nil {
                    liveChatId = await getLiveChatId()
                    if liveChatId == nil {
                        pollingIntervalMillis = 5000
                    }
                } else {
                    do {
                        try await getMessages()
                        connected = true
                    } catch {
                        logger.info("youtube: chat: \(error)")
                        connected = false
                    }
                }
                if Task.isCancelled {
                    break
                }
                do {
                    try await Task.sleep(nanoseconds: pollingIntervalMillis * 1_000_000)
                } catch {
                    break
                }
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

    private func makeMessagesUrl() -> URL? {
        var url = """
        https://www.googleapis.com/youtube/v3/liveChat/messages\
        ?part=id,snippet&key=\(apiKey)&liveChatId=\(liveChatId!)
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

    private func makeVideosUrl(videoId: String) -> URL? {
        return URL(string: """
        https://www.googleapis.com/youtube/v3/videos\
        ?part=liveStreamingDetails&key=\(apiKey)&id=\(videoId)
        """)
    }

    private func getChannelTitle(channelId: String) async -> String {
        if let title = channelToTitle[channelId] {
            return title
        }
        guard let url = makeChannelsUrl(channelId: channelId) else {
            return unknownUser
        }
        do {
            let (data, response) = try await httpGet(from: url)
            if response.isSuccessful {
                let channel = try JSONDecoder().decode(Channel.self, from: data)
                if channel.items.count != 1 {
                    return unknownUser
                }
                let title = channel.items[0].snippet.title
                channelToTitle[channelId] = title
                return title
            }
        } catch {}
        return unknownUser
    }

    private func getMessages() async throws {
        guard let url = makeMessagesUrl() else {
            return
        }
        let (data, response) = try await httpGet(from: url)
        if !response.isSuccessful {
            return
        }
        let messages = try JSONDecoder().decode(
            Messages.self,
            from: data
        )
        pollingIntervalMillis = max(
            messages.pollingIntervalMillis,
            minimumPollingIntervalMillis
        )
        nextToken = messages.nextPageToken
        for item in messages.items {
            let segments = createSegments(message: item.snippet.displayMessage)
            let user = await getChannelTitle(channelId: item.snippet.authorChannelId)
            await MainActor.run {
                self.model.appendChatMessage(
                    user: user,
                    userColor: nil,
                    segments: segments,
                    timestamp: model.digitalClock,
                    timestampDate: Date(),
                    isAction: false,
                    isAnnouncement: false,
                    isFirstMessage: false
                )
            }
        }
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

    private func getLiveChatId() async -> String? {
        guard let url = makeVideosUrl(videoId: videoId) else {
            return nil
        }
        do {
            let (data, response) = try await httpGet(from: url)
            if response.isSuccessful {
                let videos = try JSONDecoder().decode(Videos.self, from: data)
                if videos.items.count != 1 {
                    return nil
                }
                return videos.items[0].liveStreamingDetails.activeLiveChatId
            }
        } catch {}
        return nil
    }
}
