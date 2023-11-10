import Foundation

private struct BttvEmote: Codable {
    var id: String
    var code: String
}

private struct BttvChannel: Codable {
    var channelEmotes: [BttvEmote]?
    var sharedEmotes: [BttvEmote]?
}

func fetchBttvEmotes(platform: EmotesPlatform,
                     channelId: String) async -> ([String: Emote], String?)
{
    var message: String?
    var emotes: [String: Emote] = [:]
    do {
        emotes = try emotes.merging(await fetchGlobalEmotes()) { $1 }
    } catch {
        message = "Failed to get BTTV emotes"
    }
    do {
        emotes = try emotes.merging(await fetchChannelEmotes(
            platform: platform,
            channelId: channelId
        )) { $1 }
    } catch {
        message = "Failed to get BTTV emotes"
    }
    return (emotes, message)
}

private func makeUrl(emote: BttvEmote) -> URL? {
    guard let url = URL(string: "https://cdn.betterttv.net/emote/\(emote.id)/3x") else {
        logger.error("Faield to create URL for BTTV emote \(emote.code)")
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async throws -> [String: Emote] {
    var emotes: [String: Emote] = [:]
    guard let url = URL(string: "https://api.betterttv.net/3/cached/emotes/global") else {
        return [:]
    }
    let (data, response) = try await httpGet(from: url)
    if !response.isSuccessful {
        throw "Not successful"
    }
    for emote in try JSONDecoder().decode([BttvEmote].self, from: data) {
        guard let url = makeUrl(emote: emote) else {
            continue
        }
        emotes[emote.code] = Emote(url: url)
    }
    return emotes
}

private func fetchChannelEmotes(platform: EmotesPlatform,
                                channelId: String) async throws -> [String: Emote]
{
    if channelId.isEmpty {
        return [:]
    }
    var emotes: [String: Emote] = [:]
    guard let url =
        URL(string: "https://api.betterttv.net/3/cached/users/\(platform)/\(channelId)")
    else {
        return [:]
    }
    let (data, response) = try await httpGet(from: url)
    if response.isNotFound {
        logger.warning("\(channelId): BTTV channel emotes not found (HTTP 404)")
        return [:]
    }
    if !response.isSuccessful {
        throw " Not successful"
    }
    let channel = try JSONDecoder().decode(BttvChannel.self, from: data)
    for emote in channel.sharedEmotes ?? [] {
        guard let url = makeUrl(emote: emote) else {
            continue
        }
        emotes[emote.code] = Emote(url: url)
    }
    for emote in channel.channelEmotes ?? [] {
        guard let url = makeUrl(emote: emote) else {
            continue
        }
        emotes[emote.code] = Emote(url: url)
    }
    return emotes
}
