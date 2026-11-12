import Foundation
import SwiftUI

enum EmotesPlatform {
    case twitch
    case kick
    case youtube
}

class Emote {
    let url: URL
    let stillUrl: URL?

    init(url: URL, stillUrl: URL? = nil) {
        self.url = url
        self.stillUrl = stillUrl
    }
}

class Emotes: @unchecked Sendable {
    private var emotes: [String: Emote] = [:]
    private var task: Task<Void, any Error>?
    private var ready: Bool = false
    private var started: Bool = false
    private var platform: EmotesPlatform = .twitch
    private var channelId: String = ""
    private var onError: (@MainActor (String, String) -> Void)?
    private var onOk: (@MainActor (String) -> Void)?
    private var settings = SettingsStreamChat()

    func isReady() -> Bool {
        ready
    }

    func start(
        platform: EmotesPlatform,
        channelId: String,
        onError: @escaping @MainActor (String, String) -> Void,
        onOk: @escaping @MainActor (String) -> Void,
        settings: SettingsStreamChat
    ) {
        started = true
        self.platform = platform
        self.channelId = channelId
        self.onError = onError
        self.onOk = onOk
        self.settings = settings.clone()
        startInternal()
    }

    private func startInternal() {
        ready = false
        emotes.removeAll()
        task = Task { @MainActor in
            var firstRetry = true
            var retryTime = 30
            while !self.ready {
                let (bttvEmotes, bttvError) = await fetchBttvEmotes(
                    platform: self.platform,
                    channelId: self.channelId,
                    enabled: self.settings.bttvEmotes
                )
                let (ffzEmotes, ffzError) = await fetchFfzEmotes(
                    platform: self.platform,
                    channelId: self.channelId,
                    enabled: self.settings.ffzEmotes
                )
                let (seventvEmotes, seventvError) = await fetchSeventvEmotes(
                    platform: self.platform,
                    channelId: self.channelId,
                    enabled: self.settings.seventvEmotes
                )
                if Task.isCancelled {
                    return
                }
                self.addEmotes(bttvEmotes)
                self.addEmotes(ffzEmotes)
                self.addEmotes(seventvEmotes)
                if let error = bttvError ?? ffzError ?? seventvError {
                    logger.info("emotes: \(error)")
                    if firstRetry {
                        self.onError?(error, String(localized: "Retrying later"))
                    }
                    firstRetry = false
                    self.ready = false
                    do {
                        try await sleep(seconds: retryTime)
                        retryTime *= 2
                        retryTime = min(retryTime, 3600)
                    } catch {
                        return
                    }
                } else {
                    self.ready = true
                    if !firstRetry {
                        self.onOk?("Emotes fetched")
                    }
                }
            }
            logger.debug("emotes: Emotes lists fetched")
        }
    }

    func addEmotes(_ emotes: [String: Emote]) {
        self.emotes = self.emotes.merging(emotes) { $1 }
    }

    func stop() {
        started = false
        onError = nil
        onOk = nil
        stopInternal()
    }

    private func stopInternal() {
        ready = false
        task?.cancel()
        task = nil
    }

    func reload() {
        guard started else {
            return
        }
        stopInternal()
        startInternal()
    }

    func createSegments(text: String, id: inout Int) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            guard let emote = emotes[String(word)] else {
                segments.append(ChatPostSegment(id: id, text: "\(word) "))
                id += 1
                continue
            }
            segments.append(ChatPostSegment(
                id: id,
                text: "",
                url: ChatPostEmote(moving: emote.url, still: emote.stillUrl ?? emote.url, name: String(word))
            ))
            id += 1
            segments.append(ChatPostSegment(id: id, text: ""))
            id += 1
        }
        return segments
    }
}
