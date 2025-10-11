import Foundation
import SwiftUI

enum EmotesPlatform {
    case twitch
    case kick
    case youtube
    case dlive
}

class Emote {
    let url: URL

    init(url: URL) {
        self.url = url
    }
}

class Emotes {
    private var emotes: [String: Emote] = [:]
    private var task: Task<Void, Error>?
    private var ready: Bool = false

    func isReady() -> Bool {
        return ready
    }

    func start(
        platform: EmotesPlatform,
        channelId: String,
        onError: @escaping (String, String) -> Void,
        onOk: @escaping (String) -> Void,
        settings: SettingsStreamChat
    ) {
        let settings = settings.clone()
        ready = false
        emotes.removeAll()
        task = Task {
            var firstRetry = true
            var retryTime = 30
            while !self.ready {
                let (bttvEmotes, bttvError) = await fetchBttvEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.bttvEmotes
                )
                self.emotes = self.emotes.merging(bttvEmotes) { $1 }
                let (ffzEmotes, ffzError) = await fetchFfzEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.ffzEmotes
                )
                self.emotes = self.emotes.merging(ffzEmotes) { $1 }
                let (seventvEmotes, seventvError) = await fetchSeventvEmotes(
                    platform: platform,
                    channelId: channelId,
                    enabled: settings.seventvEmotes
                )
                self.emotes = self.emotes.merging(seventvEmotes) { $1 }
                if Task.isCancelled {
                    return
                }
                if let error = bttvError ?? ffzError ?? seventvError {
                    logger.warning("emotes: \(error)")
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

    func stop() {
        ready = false
        task?.cancel()
        task = nil
    }

    func createSegments(text: String, id: inout Int) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var parts: [String] = []
        for word in text.components(separatedBy: .whitespaces) {
            guard let emote = emotes[word] else {
                parts.append(word)
                continue
            }
            segments.append(ChatPostSegment(
                id: id,
                text: parts.joined(separator: " "),
                url: emote.url
            ))
            id += 1
            parts.removeAll()
        }
        if !parts.isEmpty {
            segments.append(ChatPostSegment(id: id, text: parts.joined(separator: " ")))
            id += 1
        }
        return segments
    }
}
