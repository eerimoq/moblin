import Foundation

struct KickLivestream: Codable {
    let id: Int
    let viewers: Int
}

struct KickChatroom: Codable {
    let id: Int
}

struct KickChannel: Codable {
    let slug: String
    let chatroom: KickChatroom
    let livestream: KickLivestream?
}

func getKickChannelInfo(channelName: String) async throws -> KickChannel {
    guard let url = URL(string: "https://kick.com/api/v1/channels/\(channelName)") else {
        throw "Invalid URL"
    }
    let (data, response) = try await httpGet(from: url)
    if !response.isSuccessful {
        throw "Not successful"
    }
    return try JSONDecoder().decode(KickChannel.self, from: data)
}
