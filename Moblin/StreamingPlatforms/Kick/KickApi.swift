import Foundation
import UIKit

struct BadgeImage: Codable {
    let src: String
    let srcset: String
}

struct SubscriberBadge: Codable {
    let id: Int
    let channel_id: Int
    let months: Int
    let badge_image: BadgeImage
}

struct KickLivestream: Codable {
    let id: Int
    let viewers: Int
    let session_title: String?
}

struct KickChatroom: Codable {
    let id: Int
    let channel_id: Int
}

struct KickChannelUser: Codable {
    let profile_pic: String?
}

struct KickChannel: Codable {
    let slug: String
    let chatroom: KickChatroom
    let livestream: KickLivestream?
    let subscriber_badges: [SubscriberBadge]?
    let user: KickChannelUser?
}

struct KickUser: Codable {
    let username: String
}

struct KickCategory: Codable, Identifiable {
    let id: String
    let category_id: Int
    let name: String
    let slug: String
    let src: String?
    let srcset: String?
}

struct KickCategorySearchHit: Codable {
    let document: KickCategory
}

struct KickCategorySearchResponse: Codable {
    let found: Int
    let hits: [KickCategorySearchHit]
}

struct KickStreamInfo {
    let title: String
    let categoryName: String?
}

private let userUrl = URL(string: "https://kick.com/api/v1/user")!

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

func getKickUser(accessToken: String, onComplete: @escaping (KickUser?) -> Void) {
    var request = URLRequest(url: userUrl)
    request.setAuthorization("Bearer \(accessToken)")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil, let data, response?.http?.isSuccessful == true else {
            onComplete(nil)
            return
        }
        onComplete(try? JSONDecoder().decode(KickUser.self, from: data))
    }
    .resume()
}

func fetchKickProfilePicture(username: String) async -> UIImage? {
    if let image = await fetchKickProfilePictureWithUsername(username) {
        return image
    }
    if username.contains("_") {
        let kebabUsername = username.replacingOccurrences(of: "_", with: "-")
        return await fetchKickProfilePictureWithUsername(kebabUsername)
    }
    return nil
}

private func fetchKickProfilePictureWithUsername(_ username: String) async -> UIImage? {
    guard let channelInfo = try? await getKickChannelInfo(channelName: username),
          let profilePic = channelInfo.user?.profile_pic,
          let imageUrl = URL(string: profilePic)
    else {
        return nil
    }
    guard let (data, response) = try? await httpGet(from: imageUrl) else {
        return nil
    }
    if !response.isSuccessful {
        return nil
    }
    return UIImage(data: data)
}

class KickApi {
    private let channelId: String
    private let slug: String
    private let accessToken: String

    init(channelId: String, slug: String, accessToken: String) {
        self.channelId = channelId
        self.slug = slug
        self.accessToken = accessToken
    }

    func sendMessage(message: String) {
        doRequest(method: "POST",
                  subPath: "messages/send/\(channelId)",
                  body: ["type": "message", "content": message])
        { _, _ in
        }
    }

    func deleteMessage(messageId: String) {
        doRequest(method: "DELETE",
                  subPath: "chatrooms/\(channelId)/messages/\(messageId)")
        { _, _ in
        }
    }

    func banUser(user: String, duration: Int? = nil, reason: String? = nil, onComplete: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "banned_username": user,
            "permanent": duration == nil,
        ]
        if let duration {
            body["duration"] = duration / 60
        }
        if let reason {
            body["reason"] = reason
        }
        doRequest(method: "POST",
                  subPath: "channels/\(slug)/bans",
                  body: body)
        { ok, _ in onComplete(ok) }
    }

    func unbanUser(user: String, onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "DELETE",
                  subPath: "channels/\(slug)/bans/\(user)")
        { ok, _ in onComplete(ok) }
    }

    func modUser(user: String, onComplete: @escaping (Bool) -> Void) {
        doInternalRequest(method: "POST",
                          subPath: "channels/\(slug)/community/moderators",
                          body: ["username": user])
        { ok, _ in onComplete(ok) }
    }

    func unmodUser(user: String, onComplete: @escaping (Bool) -> Void) {
        doInternalRequest(method: "DELETE",
                          subPath: "channels/\(slug)/community/moderators/\(user)")
        { ok, _ in onComplete(ok) }
    }

    func vipUser(user: String, onComplete: @escaping (Bool) -> Void) {
        doInternalRequest(method: "POST",
                          subPath: "channels/\(slug)/community/vips",
                          body: ["username": user])
        { ok, _ in onComplete(ok) }
    }

    func unvipUser(user: String, onComplete: @escaping (Bool) -> Void) {
        doInternalRequest(method: "DELETE",
                          subPath: "channels/\(slug)/community/vips/\(user)")
        { ok, _ in onComplete(ok) }
    }

    func hostChannel(channel: String, onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "POST",
                  subPath: "channels/\(slug)/chat-commands",
                  body: ["command": "host", "parameter": channel])
        { ok, _ in onComplete(ok) }
    }

    func setSlowMode(enabled: Bool, messageInterval: Int? = nil, onComplete: @escaping (Bool) -> Void) {
        var body: [String: Any] = ["slow_mode": enabled]
        if let messageInterval, enabled {
            body["message_interval"] = messageInterval
        }
        doRequest(method: "PUT",
                  subPath: "channels/\(slug)/chatroom",
                  body: body)
        { ok, _ in onComplete(ok) }
    }

    func setFollowersMode(enabled: Bool, followingMinDuration: Int? = nil, onComplete: @escaping (Bool) -> Void) {
        var body: [String: Any] = ["followers_mode": enabled]
        if let followingMinDuration, enabled {
            body["following_min_duration"] = followingMinDuration
        }
        doRequest(method: "PUT",
                  subPath: "channels/\(slug)/chatroom",
                  body: body)
        { ok, _ in onComplete(ok) }
    }

    func setEmoteOnlyMode(enabled: Bool, onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "PUT",
                  subPath: "channels/\(slug)/chatroom",
                  body: ["emotes_mode": enabled])
        { ok, _ in onComplete(ok) }
    }

    func setSubscribersOnlyMode(enabled: Bool, onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "PUT",
                  subPath: "channels/\(slug)/chatroom",
                  body: ["subscribers_mode": enabled])
        { ok, _ in onComplete(ok) }
    }

    func createPoll(
        title: String,
        options: [String],
        duration: Int,
        resultDisplayDuration: Int,
        onComplete: @escaping (Bool) -> Void
    ) {
        let body: [String: Any] = [
            "title": title,
            "options": options,
            "duration": duration,
            "result_display_duration": resultDisplayDuration,
        ]
        doRequest(method: "POST",
                  subPath: "channels/\(slug)/polls",
                  body: body)
        { ok, _ in onComplete(ok) }
    }

    func deletePoll(onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "DELETE",
                  subPath: "channels/\(slug)/polls")
        { ok, _ in onComplete(ok) }
    }

    func createPrediction(title: String, outcomes: [String], duration: Int, onComplete: @escaping (Bool) -> Void) {
        let body: [String: Any] = [
            "title": title,
            "outcomes": outcomes,
            "duration": duration,
        ]
        doRequest(method: "POST",
                  subPath: "channels/\(slug)/predictions",
                  body: body)
        { ok, _ in onComplete(ok) }
    }

    func getStreamInfo(onComplete: @escaping (KickStreamInfo?) -> Void) {
        doRequest(method: "GET",
                  subPath: "channels/\(slug)/stream-info")
        { ok, data in
            guard ok,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let title = json["stream_title"] as? String
            else {
                onComplete(nil)
                return
            }
            var categoryName: String?
            if let category = json["category"] as? [String: Any] {
                categoryName = category["name"] as? String
            }
            onComplete(KickStreamInfo(title: title, categoryName: categoryName))
        }
    }

    func setStreamTitle(title: String, onComplete: @escaping (String) -> Void) {
        doRequest(method: "PATCH",
                  subPath: "channels/\(slug)/stream-info",
                  body: ["stream_title": title])
        { ok, _ in
            if ok {
                onComplete(title)
            }
        }
    }

    func setStreamCategory(categoryId: Int, onComplete: @escaping (Bool) -> Void) {
        doRequest(method: "PATCH",
                  subPath: "channels/\(slug)/stream-info",
                  body: ["category_id": categoryId])
        { ok, _ in
            onComplete(ok)
        }
    }

    func searchCategories(query: String, onComplete: @escaping ([KickCategory]?) -> Void) {
        guard var components =
            URLComponents(string: "https://search.kick.com/collections/subcategory_index/documents/search")
        else {
            onComplete(nil)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query_by", value: "name"),
        ]
        guard let url = components.url else {
            onComplete(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("nXIMW0iEN6sMujFYjFuhdrSwVow3pDQu", forHTTPHeaderField: "X-Typesense-Api-Key")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data,
                      response?.http?.isSuccessful == true,
                      let searchResponse = try? JSONDecoder().decode(KickCategorySearchResponse.self, from: data)
                else {
                    onComplete(nil)
                    return
                }
                let categories = searchResponse.hits.map { $0.document }
                onComplete(categories)
            }
        }
        .resume()
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
        request.setContentType("application/json")
        request.setAuthorization("Bearer \(accessToken)")
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

    private func doInternalRequest(method: String,
                                   subPath: String,
                                   body: [String: Any]? = nil,
                                   onComplete: @escaping (Bool, Data?) -> Void)
    {
        guard let url = URL(string: "https://kick.com/api/internal/v1/\(subPath)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setContentType("application/json")
        request.setAuthorization("Bearer \(accessToken)")
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
