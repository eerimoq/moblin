import Foundation
import SwiftUI

enum EmotesPlatform {
    case twitch
    case kick
    case youtube
}

class Emote {
    let url: URL

    init(url: URL) {
        self.url = url
    }
}

class Emotes: @unchecked Sendable {
    private var emotes: [String: Emote] = [:]
    private var task: Task<Void, any Error>?
    private var ready: Bool = false

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
        let settings = settings.clone()
        ready = false
        emotes.removeAll()
        task = Task { @MainActor in
            var firstRetry = true
            var retryTime = 30
            while !self.ready {
                let (bttvEmotes, bttvError) = await fetchBttvEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.bttvEmotes
                )
                self.addEmotes(bttvEmotes)
                let (ffzEmotes, ffzError) = await fetchFfzEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.ffzEmotes
                )
                self.addEmotes(ffzEmotes)
                let (seventvEmotes, seventvError) = await fetchSeventvEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.seventvEmotes
                )
                self.addEmotes(seventvEmotes)
                if Task.isCancelled {
                    return
                }
                if let error = bttvError ?? ffzError ?? seventvError {
                    logger.info("emotes: \(error)")
                    if firstRetry {
                        onError(error, String(localized: "Retrying later"))
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
                        onOk("Emotes fetched")
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
        ready = false
        task?.cancel()
        task = nil
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
                url: ChatPostUrl(moving: emote.url, still: emote.url)
            ))
            id += 1
            segments.append(ChatPostSegment(id: id, text: ""))
            id += 1
        }
        return segments
    }
}
