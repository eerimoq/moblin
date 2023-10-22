import Foundation

private struct BttvEmote: Codable {
    var id: String
    var code: String
}

private struct BttvChannel: Codable {
    var channelEmotes: [BttvEmote]?
    var sharedEmotes: [BttvEmote]?
}

func fetchBttvEmotes(channelId: String) async -> [String: Emote] {
    return await fetchGlobalEmotes()
        .merging(await fetchChannelEmotes(channelId: channelId)) { $1 }
}

private func makeUrl(emote: BttvEmote) -> URL? {
    guard let url = URL(string: "https://cdn.betterttv.net/emote/\(emote.id)/3x") else {
        logger.error("Faield to create URL for BTTV emote \(emote.code)")
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async -> [String: Emote] {
    var emotes: [String: Emote] = [:]
    do {
        let data =
            try await httpGet(
                from: URL(string: "https://api.betterttv.net/3/cached/emotes/global")!
            )
        for emote in try JSONDecoder().decode([BttvEmote].self, from: data) {
            guard let url = makeUrl(emote: emote) else {
                continue
            }
            emotes[emote.code] = Emote(name: emote.code, url: url)
        }
    } catch {
        logger.error("Failed to fetch global BTTV emotes with error: \(error)")
    }
    return emotes
}

private func fetchChannelEmotes(channelId: String) async -> [String: Emote] {
    if channelId.isEmpty {
        return [:]
    }
    var emotes: [String: Emote] = [:]
    do {
        let url =
            URL(string: "https://api.betterttv.net/3/cached/users/twitch/\(channelId)")!
        let data = try await httpGet(from: url)
        let channel = try JSONDecoder().decode(BttvChannel.self, from: data)
        for emote in channel.sharedEmotes ?? [] {
            guard let url = makeUrl(emote: emote) else {
                continue
            }
            emotes[emote.code] = Emote(name: emote.code, url: url)
        }
        for emote in channel.channelEmotes ?? [] {
            guard let url = makeUrl(emote: emote) else {
                continue
            }
            emotes[emote.code] = Emote(name: emote.code, url: url)
        }
    } catch {
        logger.error("Failed to fetch channel BTTV emotes with error: \(error)")
    }
    return emotes
}
