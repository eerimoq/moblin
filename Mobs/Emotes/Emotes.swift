import Foundation
import SwiftUI

class Emote {
    let name: String
    let url: URL
    var image: UIImage?

    init(name: String, url: URL, image: UIImage? = nil) {
        self.name = name
        self.url = url
        self.image = image
    }
}

class Emotes {
    private let emotes: [String: Emote]

    init(channelId: String) async {
        emotes = await fetchBttvEmotes(channelId: channelId)
            .merging(await fetchFfzEmotes(channelId: channelId)) { $1 }
            .merging(await fetchSeventvEmotes(channelId: channelId)) { $1 }
    }

    func createSegments(text: String) async -> [ChatPostSegment] {
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
