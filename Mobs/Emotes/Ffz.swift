import Foundation

private struct FfzImages: Codable {
    var onex: String?
    var twox: String?
    var fourx: String?

    private enum CodingKeys: String, CodingKey {
        case onex = "1x", twox = "2x", fourx = "4x"
    }
}

private struct FfzEmote: Codable {
    var code: String
    var images: FfzImages
}

func fetchFfzEmotes(platform: EmotesPlatform,
                    channelId: String) async -> [String: Emote]
{
    return await fetchGlobalEmotes()
        .merging(await fetchChannelEmotes(platform: platform, channelId: channelId)) { $1
        }
}

private func makeUrl(emote: FfzEmote) -> URL? {
    guard let url = emote.images.fourx ?? emote.images.twox ?? emote.images.onex else {
        return nil
    }
    guard let url = URL(string: url) else {
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async -> [String: Emote] {
    return await fetchEmotes(
        url: "https://api.betterttv.net/3/cached/frankerfacez/emotes/global",
        message: "global"
    )
}

private func fetchChannelEmotes(platform: EmotesPlatform,
                                channelId: String) async -> [String: Emote]
{
    if channelId.isEmpty {
        return [:]
    }
    if platform == .kick {
        return [:]
    }
    return await fetchEmotes(
        url: "https://api.betterttv.net/3/cached/frankerfacez/users/twitch/\(channelId)",
        message: "channel"
    )
}

private func fetchEmotes(url: String, message: String) async -> [String: Emote] {
    var emotes: [String: Emote] = [:]
    do {
        let data = try await httpGet(from: URL(string: url)!)
        for emote in try JSONDecoder().decode([FfzEmote].self, from: data) {
            guard let url = makeUrl(emote: emote) else {
                logger.error("Failed to create URL for FFZ emote \(emote.code)")
                continue
            }
            emotes[emote.code] = Emote(url: url)
        }
    } catch {
        logger.error("Failed to fetch \(message) FFZ emotes with error: \(error)")
    }
    return emotes
}
