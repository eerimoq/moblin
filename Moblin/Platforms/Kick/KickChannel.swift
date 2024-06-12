import Foundation

struct KickLivestream: Codable {
    // periphery:ignore
    let id: Int
    let viewers: Int
}

struct KickChatroom: Codable {
    let id: Int
}

struct KickChannel: Codable {
    // periphery:ignore
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

func getKickChannelInfo(channelName: String, onComplete: @escaping (KickChannel?) -> Void) {
    guard let url = URL(string: "https://kick.com/api/v1/channels/\(channelName)") else {
        onComplete(nil)
        return
    }
    let request = URLRequest(url: url)
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil, let data, response?.http?.isSuccessful == true else {
            onComplete(nil)
            return
        }
        onComplete(try? JSONDecoder().decode(KickChannel.self, from: data))
    }
    .resume()
}
