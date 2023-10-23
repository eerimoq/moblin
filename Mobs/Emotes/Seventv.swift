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
    var emote_set: SeventvEmoteSet
}

func fetchSeventvEmotes(platform: EmotesPlatform,
                        channelId: String) async -> ([String: Emote], String?)
{
    var message: String?
    var emotes: [String: Emote] = [:]
    do {
        emotes = try emotes.merging(await fetchGlobalEmotes()) { $1 }
    } catch {
        message = "Failed to get 7TV emotes"
    }
    do {
        emotes = try emotes.merging(await fetchChannelEmotes(
            platform: platform,
            channelId: channelId
        )) { $1 }
    } catch {
        message = "Failed to get 7TV emotes"
    }
    return (emotes, message)
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

private func fetchGlobalEmotes() async throws -> [String: Emote] {
    return [:]
    /* return await fetchEmotes(
         url: "https://api.7tv.app/v2/emotes/global",
         message: "global"
     ) */
}

private func fetchChannelEmotes(platform: EmotesPlatform,
                                channelId: String) async throws
    -> [String: Emote]
{
    if channelId.isEmpty {
        return [:]
    }
    if platform == .kick {
        return [:]
    }
    return try await fetchEmotes(
        url: "https://api.7tv.app/v3/users/twitch/\(channelId)",
        message: "channel"
    )
}

private func fetchEmotes(url: String, message _: String) async throws -> [String: Emote] {
    var fetchedEmotes: [String: Emote] = [:]
    let data = try await httpGet(from: URL(string: url)!)
    let user = try JSONDecoder().decode(SeventvUser.self, from: data)
    guard let emotes = user.emote_set.emotes else {
        logger.info("Emotes missing")
        throw "Emotes missing"
    }
    if emotes.isEmpty {
        logger.info("Emotes list empty")
        throw "Emotes list empty"
    }
    for emote in emotes {
        guard let url = makeUrl(data: emote.data) else {
            logger.error("Failed to create URL for 7TV emote \(emote.name)")
            continue
        }
        fetchedEmotes[emote.name] = Emote(url: url)
    }
    return fetchedEmotes
}
