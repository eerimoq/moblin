import Foundation

private struct SeventvEmote: Codable {
    var name: String
    var urls: [[String]]
}

func fetchSeventvEmotes(channelId: String) async -> [String: Emote] {
    return await fetchGlobalEmotes()
        .merging(await fetchChannelEmotes(channelId: channelId)) { $1 }
}

private func makeUrl(emote: SeventvEmote) -> URL? {
    guard let url = emote.urls.last?.last else {
        return nil
    }
    guard let url = URL(string: url) else {
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async -> [String: Emote] {
    return await fetchEmotes(
        url: "https://api.7tv.app/v2/emotes/global",
        message: "global"
    )
}

private func fetchChannelEmotes(channelId: String) async -> [String: Emote] {
    if channelId.isEmpty {
        return [:]
    }
    return await fetchEmotes(
        url: "https://api.7tv.app/v2/users/\(channelId)/emotes",
        message: "channel"
    )
}

private func fetchEmotes(url: String, message: String) async -> [String: Emote] {
    var emotes: [String: Emote] = [:]
    do {
        let data = try await httpGet(from: URL(string: url)!)
        for emote in try JSONDecoder().decode([SeventvEmote].self, from: data) {
            guard let url = makeUrl(emote: emote) else {
                logger.error("Failed to create URL for 7TV emote \(emote.name)")
                continue
            }
            emotes[emote.name] = Emote(name: emote.name, url: url)
        }
    } catch {
        logger.error("Failed to fetch \(message) 7TV emotes with error: \(error)")
    }
    return emotes
}
