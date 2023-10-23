import Foundation

private struct SeventvFile: Codable {
    var name: String
    var size: Int64
}

private struct SeventvHost: Codable {
    var url: String
    var files: [SeventvFile]
}

private struct SeventvEmoteData: Codable {
    var host: SeventvHost
}

private struct SeventvEmote: Codable {
    var name: String
    var data: SeventvEmoteData
}

private struct SeventvEmoteSet: Codable {
    var emotes: [SeventvEmote]?
}

private struct SeventvUser: Codable {
    var id: String
    var emote_set: SeventvEmoteSet?
}

func fetchSeventvEmotes(platform: EmotesPlatform,
                        channelId: String) async -> [String: Emote]
{
    return await fetchGlobalEmotes()
        .merging(await fetchChannelEmotes(platform: platform, channelId: channelId)) { $1
        }
}

private func getWebpName(files: [SeventvFile]) -> String? {
    for file in files where file.name.hasSuffix(".webp") {
        return file.name
    }
    return nil
}

private func makeUrl(data: SeventvEmoteData) -> URL? {
    guard let name = getWebpName(files: data.host.files) else {
        return nil
    }
    guard let url = URL(string: "https:\(data.host.url)/\(name)") else {
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async -> [String: Emote] {
    return [:]
    /* return await fetchEmotes(
         url: "https://api.7tv.app/v2/emotes/global",
         message: "global"
     ) */
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
        url: "https://api.7tv.app/v3/users/twitch/\(channelId)",
        message: "channel"
    )
}

private func fetchEmotes(url: String, message: String) async -> [String: Emote] {
    var fetchedEmotes: [String: Emote] = [:]
    do {
        let data = try await httpGet(from: URL(string: url)!)
        let user = try JSONDecoder().decode(SeventvUser.self, from: data)
        guard let emote_set = user.emote_set else {
            logger.info("Emote set missing")
            return fetchedEmotes
        }
        guard let emotes = emote_set.emotes else {
            logger.info("Emotes missing")
            return fetchedEmotes
        }
        if emotes.isEmpty {
            logger.info("Emotes list empty")
            return fetchedEmotes
        }
        for emote in emotes {
            guard let url = makeUrl(data: emote.data) else {
                logger.error("Failed to create URL for 7TV emote \(emote.name)")
                continue
            }
            fetchedEmotes[emote.name] = Emote(url: url)
        }
    } catch {
        logger.error("Failed to fetch \(message) 7TV emotes with error: \(error)")
    }
    return fetchedEmotes
}
