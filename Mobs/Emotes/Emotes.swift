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

    func start(platform: EmotesPlatform, channelId: String) {
        emotes.removeAll()
        task = Task.init {
            self.emotes = await fetchBttvEmotes(platform: platform, channelId: channelId)
                .merging(await fetchFfzEmotes(platform: platform, channelId: channelId)) {
                    $1
                }
                .merging(await fetchSeventvEmotes(
                    platform: platform,
                    channelId: channelId
                )) { $1 }
        }
    }

    func stop() {
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
