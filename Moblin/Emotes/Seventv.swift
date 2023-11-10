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
        message = "Failed to get 7TV global emotes"
    }
    do {
        emotes = try emotes.merging(await fetchChannelEmotes(
            platform: platform,
            channelId: channelId
        )) { $1 }
    } catch {
        message = "Failed to get 7TV channel emotes"
    }
    return (emotes, message)
}

private func fetchGlobalEmotes() async throws -> [String: Emote] {
    let url = "https://7tv.io/v3/emote-sets/global"
    guard let url = URL(string: url) else {
        return [:]
    }
    let (data, response) = try await httpGet(from: url)
    if !response.isSuccessful {
        throw "Not successful"
    }
    let emoteSet = try JSONDecoder().decode(SeventvEmoteSet.self, from: data)
    guard let emotes = emoteSet.emotes else {
        logger.warning("7TV global emotes missing")
        throw "Emotes missing"
    }
    if emotes.isEmpty {
        logger.warning("7TV global emotes list empty")
        throw "Emotes list empty"
    }
    var fetchedEmotes: [String: Emote] = [:]
    for emote in emotes {
        guard let url = makeUrl(data: emote.data) else {
            logger.error("Failed to create URL for 7TV emote \(emote.name)")
            continue
        }
        fetchedEmotes[emote.name] = Emote(url: url)
    }
    return fetchedEmotes
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

private func fetchChannelEmotes(platform: EmotesPlatform,
                                channelId: String) async throws
    -> [String: Emote]
{
    if channelId.isEmpty {
        return [:]
    }
    let url = "https://7tv.io/v3/users/\(platform)/\(channelId)"
    guard let url = URL(string: url) else {
        return [:]
    }
    let (data, response) = try await httpGet(from: url)
    if response.isNotFound {
        logger.warning("\(channelId): 7TV channel emotes not found (HTTP 404)")
        return [:]
    }
    if !response.isSuccessful {
        logger
            .warning(
                "\(channelId): Failed to fetch 7TV channel emotes (HTTP \(response.statusCode))"
            )
        throw "Not successful"
    }
    let user = try JSONDecoder().decode(SeventvUser.self, from: data)
    guard let emotes = user.emote_set.emotes else {
        logger.warning("\(channelId): 7TV channel emotes missing")
        throw "Emotes missing"
    }
    if emotes.isEmpty {
        logger.warning("\(channelId): 7TV channel emotes list empty")
        throw "Emotes list empty"
    }
    var fetchedEmotes: [String: Emote] = [:]
    for emote in emotes {
        guard let url = makeUrl(data: emote.data) else {
            logger.error("\(channelId): Failed to create URL for 7TV emote \(emote.name)")
            continue
        }
        fetchedEmotes[emote.name] = Emote(url: url)
    }
    return fetchedEmotes
}
