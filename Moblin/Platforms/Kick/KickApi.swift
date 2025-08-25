import Foundation

struct KickLivestream: Codable {
    // periphery:ignore
    let id: Int
    let viewers: Int
    let session_title: String?
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

class KickApi {
    private let channelName: String
    private let accessToken: String

    init(channelName: String, accessToken: String) {
        self.channelName = channelName
        self.accessToken = accessToken
    }

    func sendMessage(message: String) {
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard let channelInfo else {
                return
            }
            self.doRequest(method: "POST",
                           subPath: "messages/send/\(channelInfo.chatroom.id)",
                           body: ["type": "message", "content": message])
            { _, _ in
            }
        }
    }

    func deleteMessage(messageId: String) {
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard let channelInfo else {
                return
            }
            self.doRequest(method: "DELETE",
                           subPath: "chatrooms/\(channelInfo.chatroom.id)/messages/\(messageId)")
            { _, _ in
            }
        }
    }

    func banUser(user: String, duration: Int? = nil) {
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard let channelInfo else {
                return
            }
            var body: [String: Any] = [
                "banned_username": user,
                "permanent": duration == nil,
            ]
            if let duration {
                body["duration"] = duration / 60
            }
            self.doRequest(method: "POST",
                           subPath: "channels/\(channelInfo.slug)/bans",
                           body: body)
            { _, _ in
            }
        }
    }

    func getStreamTitle(onComplete: @escaping (String) -> Void) {
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard let channelInfo else {
                return
            }
            self.doRequest(method: "GET",
                           subPath: "channels/\(channelInfo.slug)/stream-info")
            { ok, data in
                guard ok,
                      let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let title = json["stream_title"] as? String
                else {
                    return
                }
                onComplete(title)
            }
        }
    }

    func setStreamTitle(title: String, onComplete: @escaping (String) -> Void) {
        getKickChannelInfo(channelName: channelName) { channelInfo in
            guard let channelInfo else {
                return
            }
            self.doRequest(method: "PATCH",
                           subPath: "channels/\(channelInfo.slug)/stream-info",
                           body: ["stream_title": title])
            { ok, _ in
                if ok {
                    onComplete(title)
                }
            }
        }
    }

    private func doRequest(method: String,
                           subPath: String,
                           body: [String: Any]? = nil,
                           onComplete: @escaping (Bool, Data?) -> Void)
    {
        guard let url = URL(string: "https://kick.com/api/v2/\(subPath)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                let ok = error == nil && response?.http?.isSuccessful == true
                onComplete(ok, data)
            }
        }
        .resume()
    }
}
