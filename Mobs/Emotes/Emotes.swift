import Foundation
import SwiftUI

enum EmotesPlatform {
    case twitch
    case kick
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
        onError: @escaping (String) -> Void
    ) {
        ready = false
        emotes.removeAll()
        task = Task.init {
            let (bttvEmotes, bttvError) = await fetchBttvEmotes(
                platform: platform,
                channelId: channelId
            )
            self.emotes = self.emotes.merging(bttvEmotes) { $1 }
            let (ffzEmotes, ffzError) = await fetchFfzEmotes(
                platform: platform,
                channelId: channelId
            )
            self.emotes = self.emotes.merging(ffzEmotes) { $1 }
            let (seventvEmotes, seventvError) = await fetchSeventvEmotes(
                platform: platform,
                channelId: channelId
            )
            self.emotes = self.emotes.merging(seventvEmotes) { $1 }
            if let error = bttvError ?? ffzError ?? seventvError {
                logger.warning(error)
                onError(error)
                self.ready = false
            } else {
                self.ready = true
            }
        }
    }

    func stop() {
        ready = false
        task?.cancel()
        task = nil
    }

    func createSegments(text: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var parts: [String] = []
        for word in text.components(separatedBy: .whitespaces) {
            guard let emote = emotes[word] else {
                parts.append(word)
                continue
            }
            segments.append(ChatPostSegment(
                text: parts.joined(separator: " "),
                url: emote.url
            ))
            parts.removeAll()
        }
        if !parts.isEmpty {
            segments.append(ChatPostSegment(text: parts.joined(separator: " ")))
        }
        return segments
    }
}
